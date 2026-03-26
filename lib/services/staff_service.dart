import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_permission.dart';

SupabaseClient get _db => Supabase.instance.client;

class StaffService {
  StaffService._();
  static final StaffService _i = StaffService._();
  factory StaffService() => _i;

  // ── List all staff for a property ──────────────────────────────────────────

  Future<List<PropertyStaffMember>> getPropertyStaff(String propertyId) async {
    // 1. Get staff rows (no join — property_staff has no direct FK to profiles)
    final staffRows = await _db
        .from('property_staff')
        .select('user_id, role')
        .eq('property_id', propertyId);

    if (staffRows.isEmpty) return [];

    // 2. Fetch profiles separately for those user IDs (email added via migration 003)
    final userIds =
        staffRows.map((r) => r['user_id'] as String).toList();
    final profileRows = await _db
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', userIds)
        .onError((_, __) => []); // graceful if email col not yet in schema

    final profileByUid = <String, Map<String, dynamic>>{
      for (final p in profileRows) p['id'] as String: p,
    };

    // 3. Fetch all permissions for this property
    final permRows = await _db
        .from('property_staff_permissions')
        .select('user_id, section, privilege')
        .eq('property_id', propertyId);

    final permsByUser = <String, Map<String, PrivilegeLevel>>{};
    for (final row in permRows) {
      final uid = row['user_id'] as String;
      permsByUser.putIfAbsent(uid, () => {});
      permsByUser[uid]![row['section'] as String] =
          parsePrivilege(row['privilege'] as String?);
    }

    // 4. Collect owner IDs from both tables so the owner is always hidden from managers
    final ownerFromHotelUsers = await _db
        .from('hotel_users')
        .select('user_id')
        .eq('hotel_id', propertyId)
        .eq('role', 'owner')
        .onError((_, __) => []);

    final ownerFromPropertyStaff = await _db
        .from('property_staff')
        .select('user_id')
        .eq('property_id', propertyId)
        .eq('role', 'owner')
        .onError((_, __) => []);

    final ownerIds = {
      for (final r in ownerFromHotelUsers)  r['user_id'] as String,
      for (final r in ownerFromPropertyStaff) r['user_id'] as String,
    };

    return staffRows.map((row) {
      final uid     = row['user_id'] as String;
      final profile = profileByUid[uid];
      final role    = row['role'] as String? ?? 'staff';
      return PropertyStaffMember(
        userId:          uid,
        fullName:        profile?['full_name'] as String? ?? '',
        email:           profile?['email']     as String? ?? '',
        role:            role,
        permissions:     permsByUser[uid]      ?? {},
        isPropertyOwner: ownerIds.contains(uid) || role == 'owner',
      );
    }).toList();
  }

  // ── Create an invite link ─────────────────────────────────────────────────
  // Stores invite in DB and returns the shareable token.
  // The actual staff addition happens when the invitee accepts via AcceptInviteScreen.

  Future<String> createInvite({
    required String propertyId,
    required String orgId,
    required String email,
    required Map<String, PrivilegeLevel> permissions,
  }) async {
    final userId = _db.auth.currentUser?.id;

    // Serialise permissions as plain string map for JSONB storage
    final permissionsJson = {
      for (final e in permissions.entries) e.key: e.value.value,
    };

    final row = await _db.from('staff_invites').insert({
      'property_id':   propertyId,
      'org_id':        orgId,
      'invited_email': email.trim().toLowerCase(),
      'permissions':   permissionsJson,
      'invited_by':    userId,
    }).select('token').single();

    return row['token'] as String;
  }

  // ── Preview an invite (no auth required) ─────────────────────────────────

  /// Returns {property_name, invited_email, status, expired} or null if not found.
  Future<Map<String, dynamic>?> getInvitePreview(String token) async {
    final result = await _db.rpc(
      'get_invite_preview',
      params: {'p_token': token},
    );
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  // ── Accept an invite (must be authenticated) ──────────────────────────────

  Future<String> acceptInvite(String token) async {
    final result = await _db.rpc(
      'accept_staff_invite',
      params: {'p_token': token},
    );
    final data = Map<String, dynamic>.from(result as Map);
    return data['property_id'] as String;
  }

  // ── Update permissions for a staff member ─────────────────────────────────

  Future<void> updateStaffPermissions(
    String propertyId,
    String userId,
    Map<String, PrivilegeLevel> permissions,
  ) async {
    await _savePermissions(propertyId, userId, permissions);
  }

  Future<void> _savePermissions(
    String propertyId,
    String userId,
    Map<String, PrivilegeLevel> permissions,
  ) async {
    if (permissions.isEmpty) return;
    final rows = permissions.entries
        .map((e) => {
              'property_id': propertyId,
              'user_id':     userId,
              'section':     e.key,
              'privilege':   e.value.value,
            })
        .toList();
    await _db.from('property_staff_permissions').upsert(
          rows,
          onConflict: 'property_id,user_id,section',
        );
  }

  // ── Create a staff account (username + password, no email needed) ─────────
  // Calls the create-staff-account Edge Function which uses the service role
  // key so the admin session is NOT interrupted.

  /// [propertyAssignments] is a list of
  /// `{ 'propertyId': String, 'permissions': Map<String,String> }`.
  /// The first entry whose propertyId == [primaryPropertyId] becomes the
  /// primary property (passed to create_staff_member); the rest call
  /// add_staff_to_property in the edge function.
  Future<void> createStaffAccount({
    required String username,
    required String password,
    required String primaryPropertyId,
    required String orgId,
    String role = 'staff',
    required List<Map<String, dynamic>> propertyAssignments,
  }) async {
    final response = await _db.functions.invoke(
      'create-staff-account',
      body: {
        'username':            username,
        'password':            password,
        'primaryPropertyId':   primaryPropertyId,
        'orgId':               orgId,
        'role':                role,
        'propertyAssignments': propertyAssignments,
      },
    );

    if (response.status != 200) {
      final error = (response.data as Map<String, dynamic>?)?['error'] as String?
          ?? 'Failed to create account';
      throw Exception(error);
    }
  }

  // ── Reset a staff member's password (admin only) ───────────────────────────

  Future<void> resetStaffPassword(String userId, String newPassword) async {
    final response = await _db.functions.invoke(
      'reset-staff-password',
      body: {
        'userId':      userId,
        'newPassword': newPassword,
      },
    );

    if (response.status != 200) {
      final error = (response.data as Map<String, dynamic>?)?['error'] as String?
          ?? 'Failed to reset password';
      throw Exception(error);
    }
  }

  // ── Resolve a username to its Supabase email (for login screen) ───────────

  Future<String?> getEmailByUsername(String username) async {
    final result = await _db.rpc(
      'get_email_by_username',
      params: {'p_username': username},
    );
    return result as String?;
  }

  // ── Change a staff member's role ──────────────────────────────────────────

  Future<void> setStaffRole(
    String propertyId,
    String userId,
    String role, // 'staff' | 'manager'
  ) async {
    await _db.rpc('set_staff_role', params: {
      'p_property_id': propertyId,
      'p_user_id':     userId,
      'p_role':        role,
    });
  }

  // ── Get all properties a user is assigned to ──────────────────────────────

  Future<List<String>> getStaffProperties(String userId) async {
    final rows = await _db
        .from('property_staff')
        .select('property_id')
        .eq('user_id', userId);
    return rows.map((r) => r['property_id'] as String).toList();
  }

  // ── Assign an existing user to another property ────────────────────────────

  Future<void> assignStaffToProperty({
    required String propertyId,
    required String userId,
    required String role, // 'staff' | 'manager'
    Map<String, PrivilegeLevel> permissions = const {},
  }) async {
    await _db.from('property_staff').upsert({
      'property_id': propertyId,
      'user_id':     userId,
      'role':        role,
    }, onConflict: 'property_id,user_id');

    if (permissions.isNotEmpty) {
      await _savePermissions(propertyId, userId, permissions);
    }
  }

  // ── Revoke all permissions for a user on a property ───────────────────────

  Future<void> revokeAllPermissions(String propertyId, String userId) async {
    await _db
        .from('property_staff_permissions')
        .delete()
        .eq('property_id', propertyId)
        .eq('user_id', userId);
  }

  // ── Remove a staff member from a property ─────────────────────────────────

  Future<void> removeStaffMember(String propertyId, String userId) async {
    await _db
        .from('property_staff_permissions')
        .delete()
        .eq('property_id', propertyId)
        .eq('user_id', userId);

    await _db
        .from('property_staff')
        .delete()
        .eq('property_id', propertyId)
        .eq('user_id', userId);
  }

  // ── Current user's permissions for a property ─────────────────────────────

  Future<Map<String, PrivilegeLevel>> getMyPermissions(
      String propertyId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return {};

    final rows = await _db
        .from('property_staff_permissions')
        .select('section, privilege')
        .eq('property_id', propertyId)
        .eq('user_id', userId);

    return {
      for (final row in rows)
        row['section'] as String: parsePrivilege(row['privilege'] as String?)
    };
  }

  // ── Current user's role for a property ────────────────────────────────────

  /// Returns 'owner', 'manager', 'staff', or null if not a member.
  /// Checks both property_staff and hotel_users and returns the highest role.
  Future<String?> getMyRoleForProperty(String propertyId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;

    final staffFuture = _db
        .from('property_staff')
        .select('role')
        .eq('property_id', propertyId)
        .eq('user_id', userId)
        .limit(1);

    final hotelFuture = _db
        .from('hotel_users')
        .select('role')
        .eq('hotel_id', propertyId)
        .eq('user_id', userId)
        .limit(1);

    final results = await Future.wait([staffFuture, hotelFuture]);
    final staffRows = results[0] as List;
    final hotelRows = results[1] as List;

    final staffRole = staffRows.isNotEmpty ? staffRows.first['role'] as String? : null;
    final hotelRole = hotelRows.isNotEmpty ? hotelRows.first['role'] as String? : null;

    // Return highest privilege: owner > manager > staff
    if (staffRole == 'owner' || hotelRole == 'owner') return 'owner';
    if (staffRole == 'manager' || hotelRole == 'manager') return 'manager';
    if (staffRole == 'staff' || hotelRole == 'staff') return 'staff';
    return null;
  }
}
