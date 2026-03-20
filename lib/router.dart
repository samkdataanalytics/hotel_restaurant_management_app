import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_auth_provider.dart';
import 'web/login_screen.dart';
import 'web/signup_screen.dart';
import 'web/superadmin/superadmin_shell.dart';
import 'web/onboarding/onboarding_shell.dart';
import 'web/onboarding/property_setup_screen.dart';
import 'web/shell/app_shell.dart';
import 'web/accept_invite_screen.dart';

// ─── Route names ─────────────────────────────────────────────────────────────

class AppRoutes {
  static const login         = '/login';
  static const signup        = '/signup';
  static const superadmin    = '/superadmin';
  static const onboarding    = '/onboarding';
  static const propertySetup = '/property-setup';
  static const app           = '/app';
  static const acceptInvite  = '/accept-invite';
}

// ─── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final auth = authAsync.valueOrNull;
      if (auth == null || auth.isLoading) return null;

      final loc = state.matchedLocation;

      if (!auth.isLoggedIn) {
        if (loc == AppRoutes.login || loc == AppRoutes.signup) return null;
        return AppRoutes.login;
      }

      // Logged in
      if (auth.isSuperadmin) {
        if (loc.startsWith(AppRoutes.superadmin)) return null;
        return AppRoutes.superadmin;
      }

      // Accept-invite page is allowed regardless of org / property state
      if (loc.startsWith(AppRoutes.acceptInvite)) return null;

      if (!auth.hasOrganization) {
        if (loc == AppRoutes.onboarding) return null;
        return AppRoutes.onboarding;
      }

      if (!auth.hasProperties) {
        if (loc == AppRoutes.propertySetup) return null;
        return AppRoutes.propertySetup;
      }

      // Has org + properties → main app
      // propertySetup is intentionally NOT listed here — users can navigate
      // there from the app shell to add more properties.
      // Staff accounts (username-based) cannot create new properties.
      if (auth.isStaffAccount && loc == AppRoutes.propertySetup) {
        return AppRoutes.app;
      }
      if (loc == AppRoutes.login || loc == AppRoutes.onboarding) {
        return AppRoutes.app;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.superadmin,
        builder: (_, __) => const SuperadminShell(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingShell(),
      ),
      GoRoute(
        path: AppRoutes.propertySetup,
        builder: (_, __) => const PropertySetupScreen(isFirstProperty: true),
      ),
      GoRoute(
        path: AppRoutes.app,
        builder: (_, __) => const AppShell(),
      ),
      // Staff invite deep link
      GoRoute(
        path: AppRoutes.acceptInvite,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return AcceptInviteScreen(token: token);
        },
      ),
      // Guest registration deep link (keep existing behaviour)
      GoRoute(
        path: '/guest-registration',
        builder: (context, state) {
          final ref = state.uri.queryParameters['ref'] ?? '';
          return _GuestRegPlaceholder(ref: ref);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

// Bridges Riverpod auth state changes → GoRouter refresh
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

// Placeholder while we keep the old guest-registration route
class _GuestRegPlaceholder extends StatelessWidget {
  final String ref;
  const _GuestRegPlaceholder({required this.ref});

  @override
  Widget build(BuildContext context) {
    // Dynamically import the existing screen
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
