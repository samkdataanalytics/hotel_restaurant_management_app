import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/orders_realtime.dart';
import '../../data/restaurant_repository.dart';
import '../../data/sales_summary.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../../data/money.dart';

/// How far back to summarise.
enum _Window { today, week, month }

final _salesProvider =
    FutureProvider.autoDispose.family<SalesSummary, _Window>((ref, window) async {
  ref.watch(ordersRealtimeProvider);
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  final orders = await ref.watch(restaurantRepositoryProvider).loadOrders();
  final now = DateTime.now();
  final from = switch (window) {
    _Window.today => DateTime(now.year, now.month, now.day),
    _Window.week => now.subtract(const Duration(days: 7)),
    _Window.month => now.subtract(const Duration(days: 30)),
  };

  return summariseSales(orders, from: from, to: now);
});

/// Sales, cut for a phone.
///
/// Four figures and two short lists, not a port of the desktop analytics
/// screen. A revenue line chart at 380px wide is a smear; the questions that
/// actually survive the trip to a phone are "how are we doing", "what is
/// selling", and "when are we busy".
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Window _window = _Window.today;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_salesProvider(_window));

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (w, label) in const [
                  (_Window.today, 'Today'),
                  (_Window.week, '7 days'),
                  (_Window.month, '30 days'),
                ]) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: _window == w,
                    onSelected: (_) => setState(() => _window = w),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(_salesProvider(_window).future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Could not load sales.\n\n$e',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                data: (summary) => _body(summary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(SalesSummary summary) {
    final scheme = Theme.of(context).colorScheme;
    final money = ref.watch(moneyProvider);

    if (summary.orderCount == 0) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 52, color: scheme.outline),
              const SizedBox(height: 16),
              Text('No settled orders yet',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Only paid orders count towards sales, so an open table does '
                  'not appear here until its bill is settled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    final busiest = summary.ordersByDaypart.entries.isEmpty
        ? null
        : summary.ordersByDaypart.entries
            .reduce((a, b) => a.value >= b.value ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revenue',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 6),
                Text(money.format(summary.revenue),
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Mini(
                        label: 'Orders',
                        value: '${summary.orderCount}',
                      ),
                    ),
                    Expanded(
                      child: _Mini(
                        label: 'Items',
                        value: '${summary.itemCount}',
                      ),
                    ),
                    Expanded(
                      child: _Mini(
                        label: 'Average',
                        value: summary.averageOrder.toStringAsFixed(0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Text('Best sellers', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in summary.topItems)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text('${item.quantity}×',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                          fontSize: 15,
                        )),
                  ),
                  Expanded(
                    child: Text(item.name,
                        style: const TextStyle(fontSize: 15)),
                  ),
                  Text(money.format(item.revenue),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),
        Text('When you are busy',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                for (final part in Daypart.values)
                  _DaypartBar(
                    label: part.label,
                    count: summary.ordersByDaypart[part] ?? 0,
                    peak: busiest?.value ?? 1,
                    highlight: busiest?.key == part,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Mini extends ConsumerWidget {
  final String label;
  final String value;
  const _Mini({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// A horizontal bar per service period.
///
/// Bars rather than a pie: comparing lengths is far easier than comparing
/// angles, and four categories is exactly where a pie chart stops being
/// readable.
class _DaypartBar extends StatelessWidget {
  final String label;
  final int count;
  final int peak;
  final bool highlight;

  const _DaypartBar({
    required this.label,
    required this.count,
    required this.peak,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = peak == 0 ? 0.0 : count / peak;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 9,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  highlight ? StaffTheme.tableReady : scheme.primary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}
