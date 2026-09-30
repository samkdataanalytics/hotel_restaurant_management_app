import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/front_desk_realtime.dart';
import '../../data/manager_repository.dart';
import '../../data/orders_realtime.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';

final _todayProvider = FutureProvider.autoDispose<TodayStats>((ref) async {
  // Both halves of the business move these numbers, so both feed the refresh.
  ref.watch(ordersRealtimeProvider);
  ref.watch(frontDeskRealtimeProvider);
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  return ref.watch(managerRepositoryProvider).loadTodayStats();
});

/// Today at a glance.
///
/// The screen an owner opens first and most often, so it answers the four
/// questions they actually have — how full am I, who is arriving, is the
/// kitchen backed up, how many rooms can I still sell — and nothing else.
///
/// No revenue figure yet: the dashboard use case returns counts only, and
/// summing money correctly means pulling orders, expenses and room charges
/// across a date range. Showing an almost-right revenue number is worse than
/// showing none.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_todayProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(_todayProvider.future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text('Could not load today\'s numbers.\n\n$e',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(_todayProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (stats) => _body(context, stats),
      ),
    );
  }

  Widget _body(BuildContext context, TodayStats stats) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _OccupancyCard(stats: stats),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Arriving',
                value: '${stats.pendingArrivals}',
                icon: Icons.login_rounded,
                accent: StaffTheme.tableSeated,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Checked in today',
                value: '${stats.checkInsToday}',
                icon: Icons.how_to_reg_rounded,
                accent: StaffTheme.tableReady,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Rooms free',
                value: '${stats.availableRooms}',
                icon: Icons.meeting_room_outlined,
                accent: StaffTheme.tableFree,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'In the kitchen',
                value: '${stats.activeKitchenOrders}',
                icon: Icons.restaurant_menu_rounded,
                accent: StaffTheme.tableInKitchen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Revenue and trends are on the web panel. These figures are '
                'live — they update as orders and check-ins happen.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  final TodayStats stats;
  const _OccupancyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (stats.occupancy * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Occupancy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$pct',
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.0)),
                const Text('%',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${stats.occupiedRooms} of ${stats.totalRooms} rooms',
                  style: TextStyle(
                      fontSize: 13.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // A bar rather than a chart: one number over time needs a trend,
            // which this screen does not have, and a single-value pie chart is
            // decoration rather than information.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stats.occupancy,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, height: 1.0)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
