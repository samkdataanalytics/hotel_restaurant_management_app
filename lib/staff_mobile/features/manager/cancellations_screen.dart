import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/restaurant_order.dart';
import '../../../domain/entities/restaurant_table.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/orders_realtime.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

typedef _VoidableView = ({
  List<RestaurantOrder> orders,
  Map<String, String> tableNumbers,
});

final _voidableProvider = FutureProvider.autoDispose<_VoidableView>((ref) async {
  ref.watch(ordersRealtimeProvider);
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  final repo = ref.watch(restaurantRepositoryProvider);
  final service = ref.watch(restaurantServiceProvider);
  final results = await (repo.loadOrders(), service.getTables()).wait;

  // Today only. A manager approving a void is dealing with something that just
  // happened; last month's orders are a reporting question for the web panel,
  // and listing them all would bury the one that matters.
  final now = DateTime.now();
  final since = DateTime(now.year, now.month, now.day);

  return (
    orders: results.$1
        .where((o) => o.createdAt.isAfter(since))
        .where((o) => o.status != OrderStatus.cancelled)
        .toList(),
    tableNumbers: {
      for (final RestaurantTable t in results.$2) t.id: t.tableNumber,
    },
  );
});

/// Void an item or a whole order.
///
/// Gated on `restaurant_cancellations`, which is the point of the ticket: a
/// waiter should not be able to remove a charge they entered, and a manager
/// should not have to walk to the office to approve it.
class CancellationsScreen extends ConsumerStatefulWidget {
  const CancellationsScreen({super.key});

  @override
  ConsumerState<CancellationsScreen> createState() =>
      _CancellationsScreenState();
}

class _CancellationsScreenState extends ConsumerState<CancellationsScreen> {
  final _busy = <String>{};
  static final _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_voidableProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayVoid = session?.canEdit('restaurant_cancellations') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancellations & refunds')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayVoid)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — approving a void needs the Cancellations '
                'permission.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(_voidableProvider.future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Could not load orders.\n\n$e',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                data: (view) => view.orders.isEmpty
                    ? ListView(children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Nothing to void today.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: view.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _OrderCard(
                          order: view.orders[i],
                          tableNumber:
                              view.tableNumbers[view.orders[i].tableId],
                          time: _time,
                          enabled: mayVoid,
                          busy: _busy.contains(view.orders[i].id),
                          onVoidLine: (item) =>
                              _voidLine(view.orders[i], item),
                          onVoidOrder: () => _voidOrder(view.orders[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _voidLine(RestaurantOrder order, OrderItem item) async {
    final paid = order.paymentStatus == PaymentStatus.paid ||
        order.paymentStatus == PaymentStatus.chargedToRoom;
    final word = paid ? 'Refund' : 'Cancel';

    final quantity = await showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        title: '$word ${item.menuItem.name}',
        max: item.activeQuantity,
        note: paid
            ? 'This has been paid, so it is refunded. Stock is not returned.'
            : 'This is unpaid, so it is cancelled and its ingredients go back '
                'into stock.',
      ),
    );
    if (quantity == null || quantity <= 0 || !mounted) return;

    setState(() => _busy.add(order.id));
    try {
      await ref.read(restaurantRepositoryProvider).voidOrderLine(
            order: order,
            orderItemId: item.id,
            quantity: quantity,
          );
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      ref.invalidate(_voidableProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${word}ed $quantity × ${item.menuItem.name}'),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: '${word}ing ${item.menuItem.name}',
      );
    }
  }

  Future<void> _voidOrder(RestaurantOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel order #${order.orderNumber}?'),
        content: Text(
          'Every line is voided. '
          '${order.status == OrderStatus.pending ? 'Ingredients go back into stock.' : 'Stock is not returned, because the kitchen has already started.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(order.id));
    try {
      await ref
          .read(restaurantRepositoryProvider)
          .cancelWholeOrder(order.id);
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      ref.invalidate(_voidableProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Cancelling order #${order.orderNumber}',
      );
    }
  }
}

class _OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final String? tableNumber;
  final DateFormat time;
  final bool enabled;
  final bool busy;
  final void Function(OrderItem) onVoidLine;
  final VoidCallback onVoidOrder;

  const _OrderCard({
    required this.order,
    required this.tableNumber,
    required this.time,
    required this.enabled,
    required this.busy,
    required this.onVoidLine,
    required this.onVoidOrder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paid = order.paymentStatus == PaymentStatus.paid ||
        order.paymentStatus == PaymentStatus.chargedToRoom;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tableNumber != null
                        ? 'Table $tableNumber'
                        : order.type.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  paid ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: paid ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              '#${order.orderNumber} · ${time.format(order.createdAt)} · '
              '${order.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),

            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${item.activeQuantity}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: item.isFullyRefunded
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                          )),
                    ),
                    Expanded(
                      child: Text(
                        item.menuItem.name,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: item.isFullyRefunded
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isFullyRefunded
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (item.refundedQuantity > 0 && !item.isFullyRefunded)
                      Text('${item.refundedQuantity} voided',
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.error)),
                    if (enabled && !item.isFullyRefunded)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: paid ? 'Refund' : 'Cancel',
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            size: 20, color: scheme.error),
                        onPressed: busy ? null : () => onVoidLine(item),
                      ),
                  ],
                ),
              ),

            if (enabled) ...[
              const Divider(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onVoidOrder,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.block_rounded, size: 18, color: scheme.error),
                  label: Text('Cancel whole order',
                      style: TextStyle(color: scheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How many units to void. Defaults to all of them, which is the common case.
class _QuantityDialog extends StatefulWidget {
  final String title;
  final int max;
  final String note;

  const _QuantityDialog({
    required this.title,
    required this.max,
    required this.note,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late int _quantity = widget.max;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.note,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              )),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 48,
                child: Text('$_quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: _quantity < widget.max
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          Center(
            child: Text('of ${widget.max}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_quantity),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
