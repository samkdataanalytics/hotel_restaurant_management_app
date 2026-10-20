import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/lock_screen.dart';
import 'router/staff_router.dart';
import 'session/app_lock.dart';
import 'session/staff_session.dart';
import 'theme/staff_theme.dart';

/// Root of the staff mobile app.
class StaffMobileApp extends ConsumerWidget {
  const StaffMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start resolving the session immediately rather than on first screen
    // build, so the router's first redirect has something to act on.
    ref.watch(staffSessionProvider);

    return MaterialApp.router(
      title: 'HotRest Staff',
      debugShowCheckedModeBanner: false,
      theme: StaffTheme.light,
      darkTheme: StaffTheme.dark,
      routerConfig: ref.watch(staffRouterProvider),
      builder: (context, child) {
        // Staff often run the OS at a large text size. Allow it, but cap the
        // scale so the floor grid and cart totals cannot overflow their rows.
        final media = MediaQuery.of(context);

        // The lock is layered over the navigator rather than pushed as a route,
        // so locking cannot disturb the nav stack — a half-built order is still
        // there after unlocking.
        final locked = ref.watch(appLockProvider).locked;

        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (locked) const LockScreen(),
            ],
          ),
        );
      },
    );
  }
}
