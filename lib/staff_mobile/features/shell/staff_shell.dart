import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_alerts.dart';
import '../../router/staff_router.dart';
import '../manager/my_shift_screen.dart';
import '../../session/app_lock.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/outbox_banner.dart';
import '../property/property_switcher_sheet.dart';
import 'staff_tabs.dart';

/// Bottom-tab shell for the staff app.
///
/// The tab bar is built from the signed-in user's privilege map on every build,
/// so switching property can change which tabs exist.
class StaffShell extends ConsumerStatefulWidget {
  const StaffShell({super.key});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  int _index = 0;

  /// Screens are kept alive across tab switches via IndexedStack, so a
  /// half-scrolled floor or a search term survives a trip to another tab.
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(staffSessionProvider);

    // Bound to the shell, not to a tab: a kitchen tablet sitting on the
    // Orders tab and one sitting on the Floor should both alert.
    ref.watch(orderAlertListenerProvider);

    return sessionAsync.when(
      loading: () => const _ShellScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ShellScaffold(body: _SessionError(error: e)),
      data: (session) {
        final tabs = visibleTabsFor(session);

        if (tabs.isEmpty) {
          return _ShellScaffold(
            title: session.activeProperty?.name,
            body: const _NoAccess(),
            actions: [_PropertyButton(session: session)],
          );
        }

        // Clamp rather than reset: losing a tab after a property switch should
        // land on the nearest remaining one, not always bounce to the first.
        final index = _index.clamp(0, tabs.length - 1);

        return _ShellScaffold(
          title: tabs[index].label,
          subtitle: session.activeProperty?.name,
          actions: [_PropertyButton(session: session)],
          body: IndexedStack(
            index: index,
            children: [for (final tab in tabs) tab.build()],
          ),
          navigationBar: tabs.length < 2
              // A single tab needs no tab bar — it is just the screen.
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final tab in tabs)
                      NavigationDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: tab.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget body;
  final Widget? navigationBar;
  final List<Widget> actions;

  const _ShellScaffold({
    this.title,
    this.subtitle,
    required this.body,
    this.navigationBar,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title ?? 'HotRest'),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: actions,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const OutboxBanner(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: navigationBar,
    );
  }
}

/// App bar overflow: property switching, biometric lock, sign out.
///
/// "Switch property" is omitted for single-property users rather than shown
/// disabled — a control that can never do anything is just noise.
class _PropertyButton extends ConsumerWidget {
  final StaffSessionState session;
  const _PropertyButton({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final alertsOn = ref.watch(orderAlertsProvider);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'switch':
            await showPropertySwitcher(context);
          case 'lock':
            final ok = await ref
                .read(appLockProvider.notifier)
                .setEnabled(!lock.enabled);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not turn on biometric unlock. Check that a '
                      'fingerprint or face is enrolled on this device.',
                    ),
                  ),
                );
            }
          case 'printer':
            context.push(StaffRoutes.printer);
          case 'myshift':
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: const MyShiftScreen(),
              ),
            );
          case 'notifications':
            context.push(StaffRoutes.notifications);
          case 'expense':
            context.push(StaffRoutes.expense);
          case 'cancellations':
            context.push(StaffRoutes.cancellations);
          case 'analytics':
            context.push(StaffRoutes.analytics);
          case 'kitchen':
            context.push(StaffRoutes.kitchen);
          case 'soldout':
            context.push(StaffRoutes.availability);
          case 'alerts':
            final wanted = !alertsOn;
            final ok = await ref
                .read(orderAlertsProvider.notifier)
                .setEnabled(wanted);
            if (wanted && !ok && context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notifications are blocked for this app. Turn them on '
                      'in your device settings first.',
                    ),
                  ),
                );
            }
          case 'signout':
            ref.read(appLockProvider.notifier).reset();
            if (context.mounted) await confirmSignOut(context);
        }
      },
      itemBuilder: (_) => [
        if (session.hasMultipleProperties)
          const PopupMenuItem(
            value: 'switch',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.swap_horiz_rounded),
              title: Text('Switch property'),
            ),
          ),
        const PopupMenuItem(
          value: 'printer',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Receipt printer'),
            subtitle: Text('Bluetooth, per device'),
          ),
        ),
        const PopupMenuItem(
          value: 'myshift',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_outlined),
            title: Text('My shift'),
            subtitle: Text('Clock in and out'),
          ),
        ),
        const PopupMenuItem(
          value: 'notifications',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_none_rounded),
            title: Text('Notifications'),
          ),
        ),
        if (session.canEdit('hotel_expenses'))
          const PopupMenuItem(
            value: 'expense',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.receipt_outlined),
              title: Text('Log an expense'),
            ),
          ),
        if (session.canView('restaurant_cancellations'))
          const PopupMenuItem(
            value: 'cancellations',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.remove_circle_outline_rounded),
              title: Text('Cancellations & refunds'),
            ),
          ),
        if (session.canView('restaurant_analytics'))
          const PopupMenuItem(
            value: 'analytics',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bar_chart_rounded),
              title: Text('Sales'),
            ),
          ),
        if (session.canView('restaurant_kitchen'))
          const PopupMenuItem(
            value: 'kitchen',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_menu_outlined),
              title: Text('Kitchen display'),
              subtitle: Text('Full screen ticket board'),
            ),
          ),
        if (session.canView('restaurant_management'))
          const PopupMenuItem(
            value: 'soldout',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.no_food_outlined),
              title: Text('Sold out items'),
              subtitle: Text('Mark a dish off the menu'),
            ),
          ),
        PopupMenuItem(
          value: 'alerts',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(alertsOn
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined),
            title: Text(alertsOn
                ? 'New order alerts: on'
                : 'New order alerts: off'),
            subtitle: const Text('Sound while the app is open'),
          ),
        ),
        if (lock.available)
          PopupMenuItem(
            value: 'lock',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(lock.enabled
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded),
              title: Text(lock.enabled
                  ? 'Biometric unlock: on'
                  : 'Biometric unlock: off'),
              subtitle: const Text('For shared devices'),
            ),
          ),
        const PopupMenuItem(
          value: 'signout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 20),
            Text('No sections assigned',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Your account does not have access to any area of this property '
              'yet. Ask a manager to grant you permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionError extends ConsumerWidget {
  final Object error;
  const _SessionError({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
            const SizedBox(height: 20),
            Text('Could not load your session',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => ref.invalidate(staffSessionProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
