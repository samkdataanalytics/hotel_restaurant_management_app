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

    return staffRows.map((row) {
      final uid     = row['user_id'] as String;
      final profile = profileByUid[uid];
      return PropertyStaffMember(
        userId:      uid,
        fullName:    profile?['full_name'] as String? ?? '',
        email:       profile?['email']     as String? ?? '',
        role:        row['role']           as String? ?? 'staff',
        permissions: permsByUser[uid]      ?? {},
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

  Future<void> createStaffAccount({
    required String username,
    required String password,
    required String propertyId,
    required String orgId,
    required Map<String, PrivilegeLevel> permissions,
  }) async {
    final permissionsJson = {
      for (final e in permissions.entries) e.key: e.value.value,
    };

    final response = await _db.functions.invoke(
      'create-staff-account',
      body: {
        'username':    username,
        'password':    password,
        'propertyId':  propertyId,
        'orgId':       orgId,
        'permissions': permissionsJson,
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

  /// Returns 'manager', 'staff', or null if not a member.
  Future<String?> getMyRoleForProperty(String propertyId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _db
        .from('property_staff')
        .select('role')
        .eq('property_id', propertyId)
        .eq('user_id', userId)
        .limit(1);

    if (rows.isNotEmpty) return rows.first['role'] as String?;

    // Fallback: check hotel_users (legacy system)
    final hotelRows = await _db
        .from('hotel_users')
        .select('role')
        .eq('hotel_id', propertyId)
        .eq('user_id', userId)
        .limit(1);

    if (hotelRows.isNotEmpty) {
      final role = hotelRows.first['role'] as String?;
      if (role == 'owner' || role == 'manager') return 'manager';
    }

    return null;
  }
}
