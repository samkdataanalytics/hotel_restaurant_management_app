import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../domain/entities/restaurant_order.dart';
import '../../../domain/entities/restaurant_table.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/orders_realtime.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/offline_banner.dart';

typedef _KitchenView = ({
  List<RestaurantOrder> orders,
  Map<String, String> tableNumbers,
});

final _kitchenProvider = FutureProvider.autoDispose<_KitchenView>((ref) async {
  ref.watch(ordersRealtimeProvider);
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  final repo = ref.watch(restaurantRepositoryProvider);
  final service = ref.watch(restaurantServiceProvider);
  final results = await (repo.loadOrders(), service.getTables()).wait;

  return (
    orders: results.$1,
    tableNumbers: {
      for (final RestaurantTable t in results.$2) t.id: t.tableNumber,
    },
  );
});

/// Kitchen display, for a tablet on a shelf.
///
/// Deliberately not the same shape as the Orders tab. That is a list someone
/// scrolls; this is a board nobody touches except to bump a ticket, read from
/// two metres away, by someone whose hands are wet or gloved. Hence the
/// three-column rail, the oversized bump targets, and the screen staying awake.
///
/// Per-item ready toggles, which the roadmap asks for, are NOT here: `OrderItem`
/// carries no ready flag, only the order does. Adding one is a small,
/// backward-compatible change to a shared entity, but it would alter the jsonb
/// every web screen round-trips, so it is left as an explicit decision rather
/// than slipped in.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _ageTicker;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();

    // The app is portrait-locked globally; the kitchen board is the one
    // landscape surface, so it opts in and hands the lock back on the way out.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    // A board that sleeps is useless — nobody is touching the tablet between
    // tickets. Released on dispose so a phone does not burn battery after.
    WakelockPlus.enable();

    _ageTicker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_kitchenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_kitchenProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Could not load the kitchen board.\n\n$e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(_kitchenProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (view) => _board(view),
            ),
          ),
        ],
      ),
    );
  }

  Widget _board(_KitchenView view) {
    List<RestaurantOrder> inStatus(OrderStatus s) => view.orders
        .where((o) => o.status == s)
        .toList()
      // Oldest first: a kitchen works the queue from the front.
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final columns = <({String label, OrderStatus status, Color accent})>[
      (label: 'NEW', status: OrderStatus.pending, accent: StaffTheme.tableInKitchen),
      (
        label: 'COOKING',
        status: OrderStatus.preparing,
        accent: StaffTheme.tableBillRequested
      ),
      (label: 'READY', status: OrderStatus.ready, accent: StaffTheme.tableReady),
    ];

    final isWide = MediaQuery.of(context).size.width >= 700;

    // On a phone in portrait three columns would be 130px each, so it falls
    // back to a single queue rather than pretending to be a board.
    if (!isWide) {
      final queue = [
        ...inStatus(OrderStatus.pending),
        ...inStatus(OrderStatus.preparing),
        ...inStatus(OrderStatus.ready),
      ];
      if (queue.isEmpty) return const _EmptyKitchen();
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: queue.length,
        itemBuilder: (_, i) => _Ticket(
          order: queue[i],
          tableNumber: view.tableNumbers[queue[i].tableId],
          busy: _busy.contains(queue[i].id),
          accent: columns
              .firstWhere((c) => c.status == queue[i].status,
                  orElse: () => columns.first)
              .accent,
          onBump: () => _bump(queue[i]),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final column in columns)
          Expanded(
            child: _Column(
              label: column.label,
              accent: column.accent,
              orders: inStatus(column.status),
              tableNumbers: view.tableNumbers,
              busy: _busy,
              onBump: _bump,
            ),
          ),
      ],
    );
  }

  Future<void> _bump(RestaurantOrder order) async {
    final next = switch (order.status) {
      OrderStatus.pending => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      OrderStatus.ready => OrderStatus.served,
      _ => null,
    };
    if (next == null || _busy.contains(order.id)) return;

    setState(() => _busy.add(order.id));
    final isOnline = ref.read(isOnlineProvider);

    try {
      // Same write the web kitchen screen uses, so table occupancy stays in
      // sync through the service rather than by a direct row update.
      await ref
          .read(restaurantServiceProvider)
          .saveOrder(order.copyWith(status: next));
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Moving order #${order.orderNumber}',
      );
    }
  }
}

class _Column extends StatelessWidget {
  final String label;
  final Color accent;
  final List<RestaurantOrder> orders;
  final Map<String, String> tableNumbers;
  final Set<String> busy;
  final void Function(RestaurantOrder) onBump;

  const _Column({
    required this.label,
    required this.accent,
    required this.orders,
    required this.tableNumbers,
    required this.busy,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: accent.withValues(alpha: 0.13),
          child: Text(
            '$label  ${orders.length}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text('—',
                      style: TextStyle(
                          fontSize: 26, color: scheme.outlineVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _Ticket(
                    order: orders[i],
                    tableNumber: tableNumbers[orders[i].tableId],
                    busy: busy.contains(orders[i].id),
                    accent: accent,
                    onBump: () => onBump(orders[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Ticket extends StatelessWidget {
  final RestaurantOrder order;
  final String? tableNumber;
  final bool busy;
  final Color accent;
  final VoidCallback onBump;

  const _Ticket({
    required this.order,
    required this.tableNumber,
    required this.busy,
    required this.accent,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final age = DateTime.now().difference(order.createdAt);

    // Escalates rather than switching once: a ticket that has been up for an
    // hour should not look the same as one at 21 minutes.
    final urgency = order.status == OrderStatus.ready
        ? 0
        : age.inMinutes >= 30
            ? 2
            : age.inMinutes >= 15
                ? 1
                : 0;

    final border = switch (urgency) {
      2 => StaffTheme.tableInKitchen,
      1 => StaffTheme.tableBillRequested,
      _ => scheme.outlineVariant,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StaffTheme.radius),
        side: BorderSide(color: border, width: urgency > 0 ? 2.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _where(),
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _age(age),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: urgency > 0 ? FontWeight.w800 : FontWeight.w600,
                    color: urgency > 0 ? border : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text('#${order.orderNumber}',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            for (final item in order.items)
              if (!item.isFullyRefunded) _TicketLine(item: item),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onBump,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  // Oversized on purpose: this gets hit with a knuckle or the
                  // side of a hand, not a fingertip.
                  minimumSize: const Size(0, 54),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        switch (order.status) {
                          OrderStatus.pending => 'START',
                          OrderStatus.preparing => 'READY',
                          OrderStatus.ready => 'PICKED UP',
                          _ => '',
                        },
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _where() {
    if (tableNumber != null) return 'Table $tableNumber';
    return switch (order.type) {
      OrderType.roomService => 'Room ${order.roomNumber ?? '?'}',
      OrderType.takeaway => 'Takeaway',
      OrderType.delivery => order.deliveryPlatform ?? 'Delivery',
      OrderType.dineIn => 'Dine in',
    };
  }

  static String _age(Duration d) {
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h${d.inMinutes % 60}m';
  }
}

class _TicketLine extends StatelessWidget {
  final OrderItem item;
  const _TicketLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modifiers = item.selectedModifiers.entries
        .map((e) => e.value.join(', '))
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text('${item.activeQuantity}x',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                )),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.menuItem.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (modifiers.isNotEmpty)
                  Text(modifiers,
                      style: TextStyle(
                          fontSize: 13.5, color: scheme.onSurfaceVariant)),
                // The note is the thing a cook must not miss, so it is the
                // loudest part of the line rather than grey small print.
                if (item.notes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.notes,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyKitchen extends StatelessWidget {
  const _EmptyKitchen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 60, color: scheme.outline),
          const SizedBox(height: 18),
          Text('Nothing cooking',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('New tickets appear here as they are fired.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
