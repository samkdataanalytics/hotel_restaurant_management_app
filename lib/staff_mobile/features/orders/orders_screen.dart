import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/restaurant_order.dart';
import '../../../domain/entities/restaurant_table.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/orders_realtime.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/offline_banner.dart';

/// Orders plus the table numbers they belong to, resolved once.
typedef _OrdersView = ({
  List<RestaurantOrder> orders,
  Map<String, String> tableNumbers,
});

final _ordersProvider = FutureProvider.autoDispose<_OrdersView>((ref) async {
  // Re-read on every order change for this property, same as the floor board.
  ref.watch(ordersRealtimeProvider);
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  final repo = ref.watch(restaurantRepositoryProvider);
  final service = ref.watch(restaurantServiceProvider);

  // Orders carry a tableId, not a table number. Fetch both together so a list
  // of 40 orders does not turn into 40 extra lookups.
  final results = await (repo.loadOrders(), service.getTables()).wait;
  final orders = results.$1;
  final tables = results.$2;

  return (
    orders: orders,
    tableNumbers: {
      for (final RestaurantTable t in tables) t.id: t.tableNumber,
    },
  );
});

/// Which slice of the order list is showing.
enum _Filter { active, today, all }

/// Live order list — what the kitchen is working on, and what it has finished.
///
/// The floor board answers "what is happening at table 6". This answers "what
/// is happening in the kitchen", which is a different question and the reason
/// an order fired from a phone needs somewhere to be seen.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _Filter _filter = _Filter.active;
  Timer? _ageTicker;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    // Order age is the one field with no server event behind it.
    _ageTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_ordersProvider);

    return Column(
      children: [
        _FilterBar(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(_ordersProvider.future),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(
                icon: Icons.error_outline_rounded,
                title: 'Could not load orders',
                body: '$e',
                onRetry: () => ref.invalidate(_ordersProvider),
              ),
              data: (view) {
                final visible = _apply(_filter, view.orders);
                if (visible.isEmpty) {
                  return _Message(
                    icon: Icons.receipt_long_outlined,
                    title: switch (_filter) {
                      _Filter.active => 'Nothing in the kitchen',
                      _Filter.today => 'No orders today',
                      _Filter.all => 'No orders yet',
                    },
                    body: _filter == _Filter.active
                        ? 'Orders fired from the floor appear here until they '
                            'are served.'
                        : 'Orders will show here once they are taken.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = visible[i];
                    return _OrderCard(
                      order: order,
                      tableNumber: order.tableId == null
                          ? null
                          : view.tableNumbers[order.tableId],
                      busy: _busy.contains(order.id),
                      onAdvance: _nextStatus(order.status) == null
                          ? null
                          : () => _advance(order),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<RestaurantOrder> _apply(_Filter filter, List<RestaurantOrder> all) {
    // Cancelled orders are never shown here — they belong in the web
    // cancellations screen, which has the refund context this list lacks.
    final live = all.where((o) => o.status != OrderStatus.cancelled);

    switch (filter) {
      case _Filter.active:
        return live
            .where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.preparing ||
                o.status == OrderStatus.ready)
            // Oldest first: the kitchen works the queue from the front.
            .toList()
            .reversed
            .toList();
      case _Filter.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        return live.where((o) => o.createdAt.isAfter(start)).toList();
      case _Filter.all:
        return live.toList();
    }
  }

  static OrderStatus? _nextStatus(OrderStatus current) => switch (current) {
        OrderStatus.pending => OrderStatus.preparing,
        OrderStatus.preparing => OrderStatus.ready,
        OrderStatus.ready => OrderStatus.served,
        OrderStatus.served => null,
        OrderStatus.cancelled => null,
      };

  Future<void> _advance(RestaurantOrder order) async {
    final next = _nextStatus(order.status);
    if (next == null || _busy.contains(order.id)) return;

    setState(() => _busy.add(order.id));
    final isOnline = ref.read(isOnlineProvider);

    try {
      // Same write the web kitchen screen uses, so table occupancy stays in
      // sync through the service rather than by a direct row update here.
      await ref
          .read(restaurantServiceProvider)
          .saveOrder(order.copyWith(status: next));
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      // No manual refresh: the realtime tick re-reads the list.
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Updating the order',
      );
    }
  }
}

class _FilterBar extends StatelessWidget {
  final _Filter filter;
  final ValueChanged<_Filter> onChanged;

  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final (f, label) in const [
            (_Filter.active, 'In the kitchen'),
            (_Filter.today, 'Today'),
            (_Filter.all, 'All'),
          ]) ...[
            ChoiceChip(
              label: Text(label),
              selected: filter == f,
              onSelected: (_) => onChanged(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final String? tableNumber;
  final bool busy;
  final VoidCallback? onAdvance;

  const _OrderCard({
    required this.order,
    required this.tableNumber,
    required this.busy,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _statusColour(order.status);
    final age = DateTime.now().difference(order.createdAt);
    final isLate = age.inMinutes >= 20 &&
        (order.status == OrderStatus.pending ||
            order.status == OrderStatus.preparing);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _where(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(order.status),
                    style: TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isLate ? StaffTheme.tableInKitchen : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  _age(age),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isLate ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isLate ? StaffTheme.tableInKitchen : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // The items are the point of this screen for a cook — show them in
            // full rather than a count, including notes and modifiers.
            for (final item in order.items) _ItemLine(item: item),

            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  order.totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (order.paymentStatus == PaymentStatus.paid) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'PAID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: StaffTheme.tableReady,
                    ),
                  ),
                ],
                const Spacer(),
                if (onAdvance != null)
                  FilledButton.tonal(
                    onPressed: busy ? null : onAdvance,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_advanceLabel(order.status)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _where() {
    if (tableNumber != null) return 'Table $tableNumber';
    return switch (order.type) {
      OrderType.roomService =>
        'Room ${order.roomNumber ?? '?'}',
      OrderType.takeaway => 'Takeaway',
      OrderType.delivery => order.deliveryPlatform ?? 'Delivery',
      OrderType.dineIn => 'Dine in',
    };
  }

  static String _age(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d';
  }

  static String _advanceLabel(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'Start',
        OrderStatus.preparing => 'Ready',
        OrderStatus.ready => 'Served',
        _ => '',
      };

  static String _statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'NEW',
        OrderStatus.preparing => 'COOKING',
        OrderStatus.ready => 'READY',
        OrderStatus.served => 'SERVED',
        OrderStatus.cancelled => 'CANCELLED',
      };

  static Color _statusColour(OrderStatus s) => switch (s) {
        OrderStatus.pending => StaffTheme.tableInKitchen,
        OrderStatus.preparing => StaffTheme.tableBillRequested,
        OrderStatus.ready => StaffTheme.tableReady,
        OrderStatus.served => StaffTheme.tableFree,
        OrderStatus.cancelled => StaffTheme.tableFree,
      };
}

class _ItemLine extends StatelessWidget {
  final OrderItem item;
  const _ItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modifiers = item.selectedModifiers.entries
        .map((e) => e.value.join(', '))
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${item.quantity}x',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    // A fully refunded line stays visible but struck through,
                    // so the kitchen does not remake something that was voided.
                    decoration: item.isFullyRefunded
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.isFullyRefunded
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                if (modifiers.isNotEmpty)
                  Text(
                    modifiers,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (item.notes.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.notes,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Stays scrollable so pull-to-refresh works on an empty list.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Icon(icon, size: 52, color: scheme.outline),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}
