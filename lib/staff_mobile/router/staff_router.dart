import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/staff_login_screen.dart';
import '../features/frontdesk/check_in_screen.dart';
import '../features/frontdesk/check_out_screen.dart';
import '../features/frontdesk/guest_history_screen.dart';
import '../features/frontdesk/walk_in_screen.dart';
import '../../staff_mobile/data/front_desk_repository.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/manager/analytics_screen.dart';
import '../features/manager/cancellations_screen.dart';
import '../features/manager/expense_screen.dart';
import '../features/manager/notifications_screen.dart';
import '../features/orders/availability_screen.dart';
import '../features/scan/scan_screen.dart';
import '../../domain/entities/restaurant_order.dart';
import '../features/orders/order_entry_screen.dart';
import '../features/orders/payment_screen.dart';
import '../features/orders/printer_settings_screen.dart';
import '../features/shell/setup_required_screen.dart';
import '../features/shell/staff_shell.dart';
import '../session/staff_session.dart';

abstract final class StaffRoutes {
  static const login = '/login';
  static const setupRequired = '/setup-required';
  static const home = '/home';
  static const availability = '/availability';
  static const kitchen = '/kitchen';
  static const printer = '/printer';
  static const checkIn = '/check-in';
  static const checkOut = '/check-out';
  static const walkIn = '/walk-in';
  static const notifications = '/notifications';
  static const cancellations = '/cancellations';
  static const expense = '/expense';
  static const analytics = '/analytics';
  static const scan = '/scan';
  static const deliveryOrder = '/delivery-order';
  static const guests = '/guests';

  static String orderEntry(String tableId) => '/tables/$tableId/order';
  static String payment(String tableId) => '/tables/$tableId/pay';
}

/// Router for the staff mobile app.
///
/// Separate from `lib/router.dart` — that one owns the marketing site, signup,
/// onboarding, superadmin, billing and the guest QR flows, none of which the
/// staff app surfaces. It also imports the whole `lib/web/` tree, which cannot
/// compile for native at all.
///
/// Deliberately simpler than the web redirect gauntlet: mobile has exactly
/// three states — signed out, blocked pending web setup, or working.
final staffRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: StaffRoutes.home,
    // Created once; the listenable re-evaluates `redirect` on session changes.
    // Rebuilding the router on every auth change would reset the nav stack and
    // dispose screens mid-async — the same reasoning as lib/router.dart:63.
    refreshListenable: _SessionChangeNotifier(ref),
    redirect: (context, state) {
      final session = ref.read(staffSessionProvider);

      // Hold position while the session resolves. Returning a destination here
      // would bounce a signed-in user through /login on every cold start.
      if (session.isLoading) return null;

      // A failed session load is shown by the shell with a retry, rather than
      // redirected away — otherwise a flaky network looks like a logout.
      if (session.hasError) return null;

      final blocker = session.valueOrNull?.blocker;
      final loc = state.matchedLocation;

      if (blocker == StaffBlocker.signedOut) {
        return loc == StaffRoutes.login ? null : StaffRoutes.login;
      }

      if (blocker == StaffBlocker.setupRequired) {
        return loc == StaffRoutes.setupRequired
            ? null
            : StaffRoutes.setupRequired;
      }

      // Signed in and usable — bounce off the gate screens.
      if (loc == StaffRoutes.login || loc == StaffRoutes.setupRequired) {
        return StaffRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: StaffRoutes.login,
        builder: (_, __) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: StaffRoutes.setupRequired,
        builder: (_, __) => const SetupRequiredScreen(),
      ),

      // Order entry sits above the shell: it is a focused, full-screen task and
      // the bottom tab bar would only offer ways to lose a half-built order.
      GoRoute(
        path: '/tables/:tableId/order',
        builder: (_, state) => OrderEntryScreen(
          tableId: state.pathParameters['tableId']!,
        ),
      ),
      // Full screen rather than a tab: a kitchen board runs all day on a
      // propped-up tablet, so it wants the whole display and no tab bar. It
      // also unlocks landscape and holds a wakelock, which must be released
      // when it closes — an IndexedStack tab is never disposed on switch, so
      // those would leak into the rest of the app.
      GoRoute(
        path: StaffRoutes.kitchen,
        builder: (_, __) => const KitchenScreen(),
      ),
      // `extra` carries the already-loaded stay so these screens do not
      // re-fetch what the arrivals board just showed. Both cope with it being
      // absent, which is what a cold deep link would give them.
      GoRoute(
        path: StaffRoutes.checkIn,
        builder: (_, state) =>
            CheckInScreen(stay: state.extra as ArrivalEntry?),
      ),
      GoRoute(
        path: StaffRoutes.checkOut,
        builder: (_, state) {
          final stay = state.extra as ArrivalEntry?;
          if (stay == null) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Open a guest from the arrivals list to check them out.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return CheckOutScreen(stay: stay);
        },
      ),
      GoRoute(
        path: StaffRoutes.deliveryOrder,
        builder: (_, __) =>
            const OrderEntryScreen(type: OrderType.delivery),
      ),
      GoRoute(
        path: StaffRoutes.scan,
        builder: (_, __) => const ScanScreen(),
      ),
      GoRoute(
        path: StaffRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: StaffRoutes.cancellations,
        builder: (_, __) => const CancellationsScreen(),
      ),
      GoRoute(
        path: StaffRoutes.expense,
        builder: (_, __) => const ExpenseScreen(),
      ),
      GoRoute(
        path: StaffRoutes.analytics,
        builder: (_, __) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: StaffRoutes.guests,
        builder: (_, __) => const GuestHistoryScreen(),
      ),
      GoRoute(
        path: StaffRoutes.walkIn,
        builder: (_, __) => const WalkInScreen(),
      ),
      GoRoute(
        path: StaffRoutes.printer,
        builder: (_, __) => const PrinterSettingsScreen(),
      ),
      GoRoute(
        path: StaffRoutes.availability,
        builder: (_, __) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/tables/:tableId/pay',
        builder: (_, state) => PaymentScreen(
          tableId: state.pathParameters['tableId']!,
        ),
      ),

      // The shell owns the tab bar and its body. Tabs are built from the user's
      // privilege map at build time, so there is no static branch list to
      // declare here.
      GoRoute(
        path: StaffRoutes.home,
        builder: (_, __) => const StaffShell(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Screen not found:\n${state.uri}',
              textAlign: TextAlign.center),
        ),
      ),
    ),
  );
});

/// Bridges Riverpod session changes to GoRouter's refresh.
class _SessionChangeNotifier extends ChangeNotifier {
  _SessionChangeNotifier(Ref ref) {
    ref.listen(staffSessionProvider, (_, __) => notifyListeners());
  }
}
