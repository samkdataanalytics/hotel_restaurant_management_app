import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_auth_provider.dart';
import 'web/landing_screen.dart';
import 'web/login_screen.dart';
import 'web/signup_screen.dart';
import 'web/superadmin/superadmin_shell.dart';
import 'web/onboarding/onboarding_shell.dart';
import 'web/onboarding/property_setup_screen.dart';
import 'web/shell/app_shell.dart';
import 'web/accept_invite_screen.dart';
import 'web/guest/guest_menu_screen.dart';
import 'web/guest/guest_checkin_screen.dart';
import 'web/guest/guest_room_service_screen.dart';

// ─── Route names ─────────────────────────────────────────────────────────────

class AppRoutes {
  static const landing       = '/';
  static const login         = '/login';
  static const signup        = '/signup';
  static const superadmin    = '/superadmin';
  static const onboarding    = '/onboarding';
  static const propertySetup = '/property-setup';
  static const app           = '/app';
  static const acceptInvite  = '/accept-invite';
  static const guestMenu     = '/menu';
  static const roomService   = '/room-service';
}

// ─── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.landing,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final auth = authAsync.valueOrNull;
      if (auth == null || auth.isLoading) return null;

      final loc = state.matchedLocation;

      // Public pages — no auth required
      if (loc == AppRoutes.landing) {
        // If already logged in, skip the landing page
        if (auth.isLoggedIn) return AppRoutes.app;
        return null;
      }
      if (loc.startsWith(AppRoutes.guestMenu)) return null;
      if (loc.startsWith(AppRoutes.roomService)) return null;
      if (loc.startsWith('/guest-registration')) return null;

      if (!auth.isLoggedIn) {
        if (loc == AppRoutes.login || loc == AppRoutes.signup) return null;
        return AppRoutes.landing;
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

      // Staff accounts cannot create properties — never send them to property-setup
      // even if their property list appears empty (e.g. RLS or timing issue).
      // The AppShell will display a "no access" state instead.
      if (!auth.hasProperties && !auth.isStaffAccount) {
        if (loc == AppRoutes.propertySetup) return null;
        return AppRoutes.propertySetup;
      }

      // Has org + properties → main app
      // propertySetup is intentionally NOT listed here — users can navigate
      // there from the app shell to add more properties.
      if (auth.isStaffAccount && loc == AppRoutes.propertySetup) {
        return AppRoutes.app;
      }
      if (loc == AppRoutes.landing || loc == AppRoutes.login || loc == AppRoutes.onboarding) {
        return AppRoutes.app;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (_, __) => const LandingScreen(),
      ),
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
      // Public guest menu — /menu/:propertyId/:tableId (no auth required)
      GoRoute(
        path: '${AppRoutes.guestMenu}/:propertyId/:tableId',
        builder: (context, state) => GuestMenuScreen(
          propertyId: state.pathParameters['propertyId']!,
          tableId: state.pathParameters['tableId']!,
        ),
      ),
      // Room service portal — /room-service/:propertyId/:roomNumber (no auth)
      GoRoute(
        path: '${AppRoutes.roomService}/:propertyId/:roomNumber',
        builder: (context, state) => GuestRoomServiceScreen(
          propertyId: state.pathParameters['propertyId']!,
          roomNumber: state.pathParameters['roomNumber']!,
        ),
      ),
      // Guest self check-in portal — /guest-registration?ref=BK-0001
      GoRoute(
        path: '/guest-registration',
        builder: (context, state) {
          final ref = state.uri.queryParameters['ref'] ?? '';
          return GuestCheckinScreen(bookingRef: ref);
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
