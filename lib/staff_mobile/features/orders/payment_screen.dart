import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/restaurant_order.dart';
import '../../../domain/table_bill.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/front_desk_repository.dart';
import '../../data/receipt_builder.dart';
import '../../data/receipt_printer.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

/// Everything the settle screen needs for one table.
typedef _PaymentContext = ({
  TableFloorEntry entry,
  ({double taxRate, double serviceChargeRate}) charges,
});

final _paymentContextProvider = FutureProvider.autoDispose
    .family<_PaymentContext, String>((ref, tableId) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  final results =
      await (repo.loadTable(tableId), repo.loadChargeSettings()).wait;
  return (entry: results.$1, charges: results.$2);
});

/// In-house guests, loaded only when charge-to-room is actually chosen.
final _inHouseProvider =
    FutureProvider.autoDispose<List<ArrivalEntry>>((ref) async {
  return ref.watch(restaurantRepositoryProvider).loadInHouseGuests();
});

/// Settle a table: review the bill, apply a discount, take payment.
///
/// Settles every open order on the table in one go via `settleAllTableOrders`,
/// which is what the guest expects — one table, one bill — and what keeps a
/// charge-to-room folio entry from being split into several confusing lines.
class PaymentScreen extends ConsumerStatefulWidget {
  final String tableId;
  const PaymentScreen({super.key, required this.tableId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _discountType;
  double _discountAmount = 0;
  bool _settling = false;

  final _discountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_paymentContextProvider(widget.tableId));
    final session = ref.watch(staffSessionProvider).valueOrNull;

    // Settling is a POS action, re-checked here because this screen is
    // reachable by deep link and privileges can change mid-session.
    if (session != null && !session.canEdit('restaurant_pos')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bill')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'You have view-only access to the POS section, so you cannot '
              'take payment.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Bill')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Could not load the bill.\n\n$e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref
                      .invalidate(_paymentContextProvider(widget.tableId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: _build,
    );
  }

  Widget _build(_PaymentContext ctx) {
    final entry = ctx.entry;
    final orders = entry.openOrders;

    if (orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Table ${entry.table.tableNumber}')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Nothing to settle — this table has no open orders.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final bill = computeTableBill(
      orders: orders,
      taxRate: ctx.charges.taxRate,
      serviceChargeRate: ctx.charges.serviceChargeRate,
      discountType: _discountType,
      discountAmount: _discountAmount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Table ${entry.table.tableNumber}'),
            Text(
              '${orders.length} order${orders.length == 1 ? '' : 's'} · '
              '${entry.openItemCount} item'
              '${entry.openItemCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final order in orders) _OrderLines(order: order),
                const SizedBox(height: 8),
                _DiscountControl(
                  controller: _discountController,
                  type: _discountType,
                  onChanged: (type, amount) => setState(() {
                    _discountType = type;
                    _discountAmount = amount;
                  }),
                ),
                const SizedBox(height: 16),
                _BillSummary(bill: bill, charges: ctx.charges),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PayBar(
        bill: bill,
        settling: _settling,
        onCash: () => _settle(entry, bill, PaymentStatus.paid),
        onRoom: () => _chargeToRoom(entry, bill),
      ),
    );
  }

  Future<void> _settle(
    TableFloorEntry entry,
    TableBill bill,
    PaymentStatus status, {
    String? bookingId,
    String? roomId,
  }) async {
    if (_settling) return;

    // Offline settlement is deliberately refused rather than queued. A bill
    // settled against a stale total, or against a table someone else already
    // closed, is a money error that cannot be reconciled on replay.
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Taking payment needs a connection — the bill must be settled '
              'against live totals. Nothing has been charged.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      return;
    }

    setState(() => _settling = true);

    try {
      // Persist the discount on each order first, so the stored record matches
      // what was charged rather than only the receipt showing it.
      if (_discountType != null && _discountAmount > 0) {
        for (final order in entry.openOrders) {
          await ref.read(restaurantServiceProvider).updateOrderDiscount(
                orderId: order.id,
                discountType: _discountType,
                // A table-level percentage applies to each order as the same
                // percentage; a flat amount cannot be split meaningfully, so
                // it is recorded against the table's combined total below.
                discountAmount: _discountType == DiscountType.percentage
                    ? _discountAmount
                    : 0,
              );
        }
      }

      await ref.read(restaurantServiceProvider).settleAllTableOrders(
            tableId: entry.table.id,
            paymentStatus: status,
            bookingId: bookingId,
            roomId: roomId,
            // Pass the computed total so a room charge lands on the folio with
            // tax and service included, not the bare item sum.
            finalTotal: bill.total,
          );

      if (!mounted) return;
      setState(() => _settling = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              status == PaymentStatus.chargedToRoom
                  ? 'Charged to room — table ${entry.table.tableNumber} is free'
                  : 'Paid — table ${entry.table.tableNumber} is free',
            ),
          ),
        );

      // Printing is offered after the bill is settled, never before: the
      // payment must not depend on a printer being reachable.
      await _offerReceipt(entry, bill, status, roomId != null);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settling = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: true,
        action: 'Settling the bill',
      );
    }
  }

  /// Offers a printed receipt, if this device has a printer configured.
  ///
  /// Silently skipped when no printer is set up — most staff phones will never
  /// have one, and prompting them every time would be noise.
  Future<void> _offerReceipt(
    TableFloorEntry entry,
    TableBill bill,
    PaymentStatus status,
    bool chargedToRoom,
  ) async {
    final printer = ref.read(receiptPrinterProvider);
    if (printer.savedPrinter == null) return;
    if (!mounted) return;

    final wants = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Print the receipt?'),
        content: Text('To ${printer.savedPrinter!.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No receipt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Print'),
          ),
        ],
      ),
    );
    if (wants != true || !mounted) return;

    final session = ref.read(staffSessionProvider).valueOrNull;
    try {
      final builder = await ReceiptBuilder.create(paper: printer.paper);
      await printer.printBytes(builder.build(
        header: ReceiptHeader(
          propertyName: session?.activeProperty?.name ?? 'HotRest',
          addressLine: session?.activeProperty?.address,
          phone: session?.activeProperty?.phone,
        ),
        orders: entry.openOrders,
        bill: bill,
        tableLabel: 'Table ${entry.table.tableNumber}',
        settledAt: DateTime.now(),
        chargedToRoom: chargedToRoom,
      ));
    } catch (e) {
      if (!mounted) return;
      // A failed print must not imply a failed payment — the bill is already
      // settled by this point.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Payment went through, but printing failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ));
    }
  }

  Future<void> _chargeToRoom(TableFloorEntry entry, TableBill bill) async {
    final guest = await showModalBottomSheet<ArrivalEntry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _InHousePicker(),
    );
    if (guest == null || !mounted) return;

    if (guest.room == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'That booking has no room assigned, so there is no folio to '
              'charge. Assign a room first.',
            ),
          ),
        );
      return;
    }

    await _settle(
      entry,
      bill,
      PaymentStatus.chargedToRoom,
      bookingId: guest.booking.id,
      roomId: guest.room!.id,
    );
  }
}

class _OrderLines extends StatelessWidget {
  final RestaurantOrder order;
  const _OrderLines({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${order.orderNumber}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                )),
            const SizedBox(height: 6),
            for (final item in order.items)
              if (!item.isFullyRefunded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${item.activeQuantity}x',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                              fontSize: 13.5,
                            )),
                      ),
                      Expanded(
                        child: Text(item.menuItem.name,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      Text(item.subtotal.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DiscountControl extends StatelessWidget {
  final TextEditingController controller;
  final String? type;
  final void Function(String? type, double amount) onChanged;

  const _DiscountControl({
    required this.controller,
    required this.type,
    required this.onChanged,
  });

  void _emit(String? nextType) {
    final amount = double.tryParse(controller.text.trim()) ?? 0;
    onChanged(nextType, nextType == null ? 0 : amount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Discount',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: type == null,
                  onSelected: (_) {
                    controller.clear();
                    _emit(null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('%'),
                  selected: type == DiscountType.percentage,
                  onSelected: (_) => _emit(DiscountType.percentage),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Amount'),
                  selected: type == DiscountType.flat,
                  onSelected: (_) => _emit(DiscountType.flat),
                ),
              ],
            ),
            if (type != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: type == DiscountType.percentage
                      ? 'Percent off'
                      : 'Amount off',
                  prefixIcon: Icon(type == DiscountType.percentage
                      ? Icons.percent_rounded
                      : Icons.remove_circle_outline_rounded),
                ),
                onChanged: (_) => _emit(type),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillSummary extends StatelessWidget {
  final TableBill bill;
  final ({double taxRate, double serviceChargeRate}) charges;

  const _BillSummary({required this.bill, required this.charges});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row(String label, double value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: strong ? 16 : 13.5,
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
                      color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
                    )),
              ),
              Text(value.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: strong ? 18 : 13.5,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  )),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: [
            row('Items', bill.itemsTotal),
            if (bill.discountValue > 0) row('Discount', -bill.discountValue),
            if (charges.taxRate > 0)
              row('Tax (${(charges.taxRate * 100).toStringAsFixed(0)}%)',
                  bill.tax),
            if (charges.serviceChargeRate > 0 && bill.serviceCharge > 0)
              row(
                'Service '
                '(${(charges.serviceChargeRate * 100).toStringAsFixed(0)}%)'
                '${bill.hasMixedOrderTypes ? ' · dine-in only' : ''}',
                bill.serviceCharge,
              ),
            const Divider(height: 18),
            row('Total', bill.total, strong: true),
          ],
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  final TableBill bill;
  final bool settling;
  final VoidCallback onCash;
  final VoidCallback onRoom;

  const _PayBar({
    required this.bill,
    required this.settling,
    required this.onCash,
    required this.onRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: settling ? null : onRoom,
                  icon: const Icon(Icons.hotel_rounded, size: 19),
                  label: const Text('To room'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: settling ? null : onCash,
                  icon: settling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(settling
                      ? 'Settling'
                      : 'Mark paid  ${bill.total.toStringAsFixed(2)}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks which in-house guest to charge.
class _InHousePicker extends ConsumerWidget {
  const _InHousePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_inHouseProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Charge to which room?',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load in-house guests.\n\n$e',
                      textAlign: TextAlign.center),
                ),
                data: (guests) => guests.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Nobody is checked in right now, so there is no room '
                          'to charge.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: guests.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final g = guests[i];
                          return ListTile(
                            title: Text(g.guestName),
                            subtitle: Text(
                                'Room ${g.roomLabel} · ${g.booking.bookingRef}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(g),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
