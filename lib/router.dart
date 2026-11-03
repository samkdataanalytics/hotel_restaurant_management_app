import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_auth_provider.dart';
import 'web/landing_screen.dart';
import 'web/login_screen.dart';
import 'web/signup_screen.dart';
import 'web/superadmin/superadmin_shell.dart';
import 'web/suspended_screen.dart';
import 'web/onboarding/onboarding_shell.dart';
import 'web/onboarding/onboarding_profile_screen.dart';
import 'web/onboarding/property_setup_screen.dart';
import 'web/shell/app_shell.dart';
import 'web/dashboard_screen.dart';
import 'web/checkins_screen.dart';
import 'web/rooms_screen.dart';
import 'web/reservations_screen.dart';
import 'web/financials_screen.dart';
import 'web/expenses_management_screen.dart';
import 'web/pos_screen.dart';
import 'web/table_floor_screen.dart';
import 'web/kitchen_screen.dart';
import 'web/restaurant_management_screen.dart';
import 'web/orders_screen.dart';
import 'web/restaurant_analytics_screen.dart';
import 'web/upgrade_screen.dart';
import 'web/pay_subscription_screen.dart';
import 'web/cancellations_refunds_screen.dart';
import 'web/users_management_screen.dart';
import 'web/staff_schedule_screen.dart';
import 'web/account_settings_screen.dart';
import 'web/accept_invite_screen.dart';
import 'web/guest/guest_menu_screen.dart';
import 'web/guest/guest_checkin_screen.dart';
import 'web/guest/guest_room_service_screen.dart';
import 'web/legal_screen.dart';
import 'web/help_screen.dart';
import 'web/verify_email_screen.dart';
import 'web/email_verified_screen.dart';

// ─── Route names ─────────────────────────────────────────────────────────────

class AppRoutes {
  static const landing       = '/';
  static const login         = '/login';
  static const signup        = '/signup';
  static const superadmin    = '/superadmin';
  static const onboarding        = '/onboarding';
  static const onboardingProfile = '/onboarding/profile';
  static const propertySetup = '/property-setup';
  static const app           = '/app';
  static const appDashboard  = '/app/dashboard';
  static const verifyEmail   = '/verify-email';
  static const emailVerified = '/email-verified';
  static const acceptInvite  = '/accept-invite';
  static const guestMenu     = '/menu';
  static const roomService   = '/room-service';
  static const suspended     = kSuspendedPath;
}

// ─── Router provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  // Do NOT watch authProvider here — that would recreate the GoRouter (and
  // reset the nav stack) on every auth state change, disposing screens that
  // are mid-async-operation and swallowing their error handling.
  // Instead, the GoRouter is created once; refreshListenable fires on auth
  // changes, triggering a re-evaluation of the redirect below.
  return GoRouter(
    initialLocation: AppRoutes.landing,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider).valueOrNull;
      if (auth == null || auth.isLoading) return null;

      final loc = state.matchedLocation;

      // Landing page: send logged-in users straight to the app.
      if (loc == AppRoutes.landing) {
        if (auth.isLoggedIn) return AppRoutes.appDashboard;
        return null;
      }

      // /app (no subpath) → dashboard
      if (loc == AppRoutes.app) return AppRoutes.appDashboard;
      if (loc.startsWith(AppRoutes.guestMenu)) return null;
      if (loc.startsWith(AppRoutes.roomService)) return null;
      if (loc.startsWith('/guest-registration')) return null;
      if (loc == '/terms' || loc == '/returns' || loc == '/privacy') return null;
      if (loc == '/help') return null;

      if (!auth.isLoggedIn) {
        if (loc == AppRoutes.login || loc == AppRoutes.signup) return null;
        if (loc == AppRoutes.verifyEmail) return null;
        if (loc == AppRoutes.emailVerified) return null;
        return AppRoutes.landing;
      }

      // Logged in but email not yet verified (safety net for edge cases)
      if (!auth.emailVerified && !auth.isStaffAccount) {
        if (loc == AppRoutes.verifyEmail) return null;
        if (loc == AppRoutes.emailVerified) return null;
        return AppRoutes.verifyEmail;
      }

      // Logged in
      if (auth.isSuperadmin) {
        if (loc.startsWith(AppRoutes.superadmin)) return null;
        return AppRoutes.superadmin;
      }

      // A suspended company's members can sign in but see only the suspended notice
      // (and can sign out). Checked before every other in-app route.
      if (auth.isSuspended) {
        return suspensionRedirect(suspended: true, location: loc);
      }
      if (loc == AppRoutes.suspended) return AppRoutes.appDashboard;

      // Allow any /app/* sub-route through once we've passed auth checks
      if (loc.startsWith('${AppRoutes.app}/')) return null;

      // Accept-invite page is allowed regardless of org / property state
      if (loc.startsWith(AppRoutes.acceptInvite)) return null;

      if (!auth.hasOrganization) {
        if (loc == AppRoutes.onboarding || loc == AppRoutes.onboardingProfile) return null;
        return AppRoutes.onboarding;
      }

      // Staff accounts cannot create properties — never send them to property-setup
      // even if their property list appears empty (e.g. RLS or timing issue).
      // The AppShell will display a "no access" state instead.
      if (!auth.hasProperties && !auth.isStaffAccount) {
        if (loc == AppRoutes.propertySetup) return null;
        return AppRoutes.propertySetup;
      }

      // Enterprise payment wall: custom price set by superadmin but not yet paid.
      if (auth.needsSubscriptionPayment) {
        if (loc == '/app/pay-subscription') return null;
        return '/app/pay-subscription';
      }

      // /superadmin is for superadmins only. Without this, a signed-in user with
      // an org and a property fell through every branch to `return null` and the
      // superadmin shell rendered; only RLS stopped them reading anything. It is
      // placed after the onboarding and payment checks so users who still need
      // those keep their existing redirects.
      if (loc.startsWith(AppRoutes.superadmin)) return AppRoutes.appDashboard;

      // Has org + properties → main app
      // propertySetup is intentionally NOT listed here — users can navigate
      // there from the app shell to add more properties.
      if (auth.isStaffAccount && loc == AppRoutes.propertySetup) {
        return AppRoutes.appDashboard;
      }
      if (loc == AppRoutes.landing || loc == AppRoutes.login || loc == AppRoutes.onboarding) {
        return AppRoutes.appDashboard;
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
        builder: (_, state) => SignupScreen(
          plan: state.uri.queryParameters['plan'],
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: AppRoutes.emailVerified,
        builder: (_, __) => const EmailVerifiedScreen(),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        builder: (_, __) => const SuspendedScreen(),
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
        path: AppRoutes.onboardingProfile,
        builder: (_, __) => const OnboardingProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.propertySetup,
        builder: (_, __) => const PropertySetupScreen(isFirstProperty: true),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/app/dashboard',     builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/app/check-ins',     builder: (_, __) => const CheckinsScreen()),
          GoRoute(path: '/app/rooms',         builder: (_, __) => const RoomsScreen()),
          GoRoute(path: '/app/reservations',  builder: (_, __) => const ReservationsScreen()),
          GoRoute(path: '/app/financials',    builder: (_, __) => const FinancialsScreen()),
          GoRoute(path: '/app/expenses',      builder: (_, __) => const ExpensesManagementScreen()),
          GoRoute(path: '/app/pos',           builder: (_, __) => const PosScreen()),
          GoRoute(path: '/app/tables',        builder: (_, __) => const TableFloorScreen()),
          GoRoute(path: '/app/kitchen',       builder: (_, __) => const KitchenScreen()),
          GoRoute(path: '/app/restaurant',    builder: (_, __) => const RestaurantManagementScreen()),
          GoRoute(path: '/app/orders',        builder: (_, __) => const OrdersScreen()),
          GoRoute(path: '/app/analytics',     builder: (_, __) => const RestaurantAnalyticsScreen()),
          GoRoute(path: '/app/cancellations', builder: (_, __) => const CancellationsRefundsScreen()),
          GoRoute(path: '/app/team',          builder: (_, __) => const UsersManagementScreen()),
          GoRoute(path: '/app/shifts',        builder: (_, __) => const StaffScheduleScreen()),
          GoRoute(path: '/app/account',       builder: (_, __) => const AccountSettingsScreen()),
          GoRoute(path: '/app/help',          builder: (_, __) => const HelpScreen()),
          GoRoute(path: '/app/upgrade',       builder: (_, state) => UpgradeScreen(
            plan: state.uri.queryParameters['plan'],
          )),
          GoRoute(path: '/app/pay-subscription', builder: (_, __) => const PaySubscriptionScreen()),
        ],
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
      // Legal pages — public, no auth required
      // Public docs page — no auth required
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen(standalone: true)),

      GoRoute(path: '/terms',   builder: (_, __) => const LegalScreen(page: LegalPage.terms)),
      GoRoute(path: '/returns', builder: (_, __) => const LegalScreen(page: LegalPage.returns)),
      GoRoute(path: '/privacy', builder: (_, __) => const LegalScreen(page: LegalPage.privacy)),

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
