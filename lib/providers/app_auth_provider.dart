import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/organization_service.dart';

/// Holds the Step 1 (Company Details) data while the user is mid-onboarding.
/// Cleared once onboarding completes.
final onboardingStep1DataProvider =
    StateProvider<Map<String, String>>((ref) => {});

SupabaseClient get _db => Supabase.instance.client;

// ─── App auth state ───────────────────────────────────────────────────────────

class AppAuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final bool isSuperadmin;
  final bool emailVerified;
  final String? userId;
  final String? email;
  final Organization? organization;
  /// Role in the org ('owner' | 'admin' | 'member'). Null when not in an org.
  final String? orgRole;
  /// Whether this user has been granted billing management access by an owner.
  final bool canManageBilling;
  final List<OrgProperty> properties;
  final String? error;

  const AppAuthState({
    this.isLoading  = true,
    this.isLoggedIn = false,
    this.isSuperadmin = false,
    this.emailVerified = true,
    this.userId,
    this.email,
    this.organization,
    this.orgRole,
    this.canManageBilling = false,
    this.properties = const [],
    this.error,
  });

  bool get hasOrganization => organization != null;
  bool get hasProperties   => properties.isNotEmpty;
  bool get isOrgOwner      => orgRole == 'owner';
  /// True if the user can initiate plan upgrades (owner or explicitly granted).
  bool get canUpgradePlan  => isOrgOwner || canManageBilling;
  /// True for staff accounts created via the admin panel (username-based).
  bool get isStaffAccount  => email?.endsWith('@staff.internal') ?? false;

  AppAuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    bool? isSuperadmin,
    bool? emailVerified,
    String? userId,
    String? email,
    Organization? organization,
    String? orgRole,
    bool? canManageBilling,
    List<OrgProperty>? properties,
    String? error,
  }) => AppAuthState(
    isLoading:          isLoading          ?? this.isLoading,
    isLoggedIn:         isLoggedIn         ?? this.isLoggedIn,
    isSuperadmin:       isSuperadmin       ?? this.isSuperadmin,
    emailVerified:      emailVerified      ?? this.emailVerified,
    userId:             userId             ?? this.userId,
    email:              email              ?? this.email,
    organization:       organization       ?? this.organization,
    orgRole:            orgRole            ?? this.orgRole,
    canManageBilling:   canManageBilling   ?? this.canManageBilling,
    properties:         properties         ?? this.properties,
    error:              error              ?? this.error,
  );
}

// ─── Auth notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AppAuthState> {
  @override
  Future<AppAuthState> build() async {
    return _loadFromCurrentSession();
  }

  Future<AppAuthState> _loadFromCurrentSession() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      return const AppAuthState(isLoading: false, isLoggedIn: false);
    }
    return _loadUserContext(user);
  }

  Future<AppAuthState> _loadUserContext(User user) async {
    try {
      // Check superadmin
      bool isSuperadmin = false;
      try {
        final profileRows = await _db
            .from('profiles')
            .select('is_superadmin')
            .eq('id', user.id)
            .limit(1);
        if (profileRows.isNotEmpty) {
          isSuperadmin = profileRows.first['is_superadmin'] as bool? ?? false;
        }
      } catch (_) {}

      // Load org + properties (skip for superadmin — they see everything)
      Organization? org;
      String? orgRole;
      bool canManageBilling = false;
      List<OrgProperty> properties = [];

      if (!isSuperadmin) {
        // Run independently so a properties error never hides the org (and
        // vice-versa), which would wrongly redirect the user to /onboarding.
        try {
          org = await OrganizationService().getMyOrganization();
        } catch (_) {}
        try {
          properties = await OrganizationService().getMyProperties();
        } catch (_) {}
        if (org != null) {
          try {
            final rows = await _db
                .from('organization_members')
                .select('role, can_manage_billing')
                .eq('org_id', org.id)
                .eq('user_id', user.id)
                .eq('is_deleted', false)
                .limit(1);
            if (rows.isNotEmpty) {
              orgRole           = rows.first['role'] as String?;
              canManageBilling  = rows.first['can_manage_billing'] as bool? ?? false;
            }
          } catch (_) {}
        }
      }

      return AppAuthState(
        isLoading:        false,
        isLoggedIn:       true,
        isSuperadmin:     isSuperadmin,
        emailVerified:    user.emailConfirmedAt != null,
        userId:           user.id,
        email:            user.email,
        organization:     org,
        orgRole:          orgRole,
        canManageBilling: canManageBilling,
        properties:       properties,
      );
    } catch (e) {
      return AppAuthState(
        isLoading:     false,
        isLoggedIn:    true,
        emailVerified: user.emailConfirmedAt != null,
        userId:        user.id,
        email:         user.email,
        error:         e.toString(),
      );
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _loadFromCurrentSession());
  }

  Future<String?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _db.auth.signInWithPassword(
        email: email, password: password,
      );
      if (res.user == null) {
        state = const AsyncValue.data(AppAuthState(isLoading: false));
        return 'Authentication failed.';
      }
      final s = await _loadUserContext(res.user!);
      state = AsyncValue.data(s);
      return null;
    } on AuthException catch (e) {
      state = const AsyncValue.data(AppAuthState(isLoading: false));
      if (e.message.toLowerCase().contains('email_not_confirmed') ||
          e.message.toLowerCase().contains('email not confirmed')) {
        return 'EMAIL_NOT_CONFIRMED';
      }
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(AppAuthState(isLoading: false));
      return 'Unexpected error: $e';
    }
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
    state = const AsyncValue.data(AppAuthState(isLoading: false, isLoggedIn: false));
  }

  Future<void> refreshAfterOnboarding() async {
    // Check if a superadmin pre-provisioned enterprise access for this user.
    // The pending_provisions row is keyed by email and was created when the
    // superadmin invited a customer who hadn't signed up yet.
    final user = _db.auth.currentUser;
    if (user?.email != null) {
      try {
        // apply_pending_provision is a SECURITY DEFINER RPC that looks up the
        // caller's email in pending_provisions and applies the enterprise limits
        // server-side. It's a no-op when no provision exists.
        await _db.rpc('apply_pending_provision');
      } catch (e) {
        // Non-fatal — continue with normal reload even if auto-apply fails
        debugPrint('refreshAfterOnboarding: pending provision apply failed: $e');
      }
    }
    await reload();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);

// ─── Active property provider ─────────────────────────────────────────────────

class ActivePropertyNotifier extends Notifier<OrgProperty?> {
  @override
  OrgProperty? build() => null;

  void setProperty(OrgProperty property) => state = property;
}

final activePropertyProvider =
    NotifierProvider<ActivePropertyNotifier, OrgProperty?>(
  ActivePropertyNotifier.new,
);
