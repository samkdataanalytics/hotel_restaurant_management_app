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
  final String? userId;
  final String? email;
  final Organization? organization;
  final List<OrgProperty> properties;
  final String? error;

  const AppAuthState({
    this.isLoading  = true,
    this.isLoggedIn = false,
    this.isSuperadmin = false,
    this.userId,
    this.email,
    this.organization,
    this.properties = const [],
    this.error,
  });

  bool get hasOrganization => organization != null;
  bool get hasProperties   => properties.isNotEmpty;
  /// True for staff accounts created via the admin panel (username-based).
  bool get isStaffAccount  => email?.endsWith('@staff.internal') ?? false;

  AppAuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    bool? isSuperadmin,
    String? userId,
    String? email,
    Organization? organization,
    List<OrgProperty>? properties,
    String? error,
  }) => AppAuthState(
    isLoading:    isLoading    ?? this.isLoading,
    isLoggedIn:   isLoggedIn   ?? this.isLoggedIn,
    isSuperadmin: isSuperadmin ?? this.isSuperadmin,
    userId:       userId       ?? this.userId,
    email:        email        ?? this.email,
    organization: organization ?? this.organization,
    properties:   properties   ?? this.properties,
    error:        error        ?? this.error,
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
      }

      return AppAuthState(
        isLoading:    false,
        isLoggedIn:   true,
        isSuperadmin: isSuperadmin,
        userId:       user.id,
        email:        user.email,
        organization: org,
        properties:   properties,
      );
    } catch (e) {
      return AppAuthState(
        isLoading: false,
        isLoggedIn: true,
        userId: user.id,
        email:  user.email,
        error:  e.toString(),
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

  Future<void> refreshAfterOnboarding() async => reload();
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
