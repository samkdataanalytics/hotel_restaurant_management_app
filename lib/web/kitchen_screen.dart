import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import '../providers/hotel_session.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/expense.dart';
import '../models/restaurant_table.dart';
import '../services/restaurant_service.dart';
import '../models/staff_permission.dart';
import '../services/booking_service.dart';
import 'restaurant_invoice_dialog.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  final _restaurantService = RestaurantService();
  final _bookingService = BookingService();
  final _timeFormat = DateFormat('hh:mm a');
  NumberFormat get _currency => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);

  List<RestaurantOrder> _allOrders = [];
  List<RestaurantTable> _tables = [];
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _loadData(silent: true));
    // Real-time: reload instantly whenever any order row changes
    _realtimeChannel = Supabase.instance.client
        .channel('kitchen_orders_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurant_orders',
          callback: (_) => _loadData(silent: true),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final ordersFuture = _restaurantService.getOrders();
    final tablesFuture = _restaurantService.getTables();
    final orders = await ordersFuture;
    final tables = await tablesFuture;
    final now = DateTime.now();
    final todayOrders = orders.where((o) =>
        o.createdAt.year == now.year &&
        o.createdAt.month == now.month &&
        o.createdAt.day == now.day &&
        o.status != OrderStatus.cancelled).toList();
    todayOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (!mounted) return;
    setState(() {
      _allOrders = todayOrders;
      _tables = tables;
      _isLoading = false;
    });
  }

  /// Returns the display name for a table ID, e.g. "Table 3".
  String _tableName(String? tableId) {
    if (tableId == null) return '';
    try {
      return 'Table ${_tables.firstWhere((t) => t.id == tableId).tableNumber}';
    } catch (_) {
      return 'Table ?';
    }
  }

  /// Returns how many open (non-cancelled, unpaid) orders exist for a table today.
  int _openOrderCountForTable(String? tableId) {
    if (tableId == null) return 0;
    return _allOrders.where((o) =>
        o.tableId == tableId &&
        o.status != OrderStatus.cancelled &&
        o.paymentStatus != PaymentStatus.paid &&
        o.paymentStatus != PaymentStatus.chargedToRoom).length;
  }

  Future<void> _updateStatus(RestaurantOrder order, OrderStatus next) async {
    await _restaurantService.saveOrder(order.copyWith(status: next));
    _loadData(silent: true);
  }

  // ── Column filters ──────────────────────────────────────────────────────────
  List<RestaurantOrder> get _pendingOrders =>
      _allOrders.where((o) => o.status == OrderStatus.pending).toList();

  List<RestaurantOrder> get _preparingOrders =>
      _allOrders.where((o) => o.status == OrderStatus.preparing).toList();

  List<RestaurantOrder> get _readyOrders =>
      _allOrders.where((o) => o.status == OrderStatus.ready).toList();

  /// Served orders that still need payment (dine-in tabs or POS unpaid).
  List<RestaurantOrder> get _paymentDueOrders => _allOrders
      .where((o) =>
          o.status == OrderStatus.served &&
          o.paymentStatus == PaymentStatus.unpaid)
      .toList();

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadData),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumn('Pending', _pendingOrders,
              nextStatus: OrderStatus.preparing, color: Colors.orange),
          _buildColumn('Preparing', _preparingOrders,
              nextStatus: OrderStatus.ready, color: Colors.blue),
          _buildColumn('Ready to Serve', _readyOrders,
              nextStatus: OrderStatus.served, color: Colors.green),
          _buildPaymentColumn(),
        ],
      ),
    );
  }

  // ── Standard KDS column ─────────────────────────────────────────────────────
  Widget _buildColumn(
    String title,
    List<RestaurantOrder> orders, {
    required OrderStatus nextStatus,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _columnHeader(title, orders.length, color),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (_, i) =>
                    _buildOrderCard(orders[i], nextStatus, color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment-due column ──────────────────────────────────────────────────────

  /// Groups payment-due orders by parent-child relationship.
  /// Returns a list of groups; each group is [parent, ...children] or [orphan].
  List<List<RestaurantOrder>> _groupedPaymentDueOrders() {
    final flat = _paymentDueOrders;
    final childIds = <String>{};
    for (final o in flat) {
      if (o.parentOrderId != null) childIds.add(o.id);
    }

    final groups = <List<RestaurantOrder>>[];
    for (final o in flat) {
      if (childIds.contains(o.id)) continue; // will be added under its parent
      final children = flat
          .where((c) => c.parentOrderId == o.id)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      groups.add([o, ...children]);
    }
    return groups;
  }

  Widget _buildPaymentColumn() {
    final groups = _groupedPaymentDueOrders();
    const color = Colors.purple;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded,
                          color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Text('Payment Due',
                          style: TextStyle(
                              color: Colors.purple.shade200,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.purple.shade900,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${groups.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.purple.shade700, size: 40),
                          const SizedBox(height: 10),
                          Text('All paid',
                              style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: groups.length,
                      itemBuilder: (_, i) => _buildPaymentCard(groups[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Column header helper ────────────────────────────────────────────────────
  Widget _columnHeader(
      String title, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: color.shade200,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color.shade900,
                borderRadius: BorderRadius.circular(12)),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Order card (Pending / Preparing / Ready) ─────────────────────────────────
  Widget _buildOrderCard(
      RestaurantOrder order, OrderStatus nextStatus, MaterialColor color) {
    final age = DateTime.now().difference(order.createdAt);
    final minutes = age.inMinutes;
    final isUrgent =
        order.status == OrderStatus.pending && minutes > 15;
    final isNew = order.status == OrderStatus.pending && age.inSeconds < 30;
    final isAddon = order.parentOrderId != null;

    return Card(
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isNew
            ? BorderSide(color: Colors.orange.shade300, width: 2)
            : isUrgent
                ? BorderSide(color: Colors.red.shade400, width: 2)
                : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${order.orderNumber}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(_timeFormat.format(order.createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(order.type.name.toUpperCase(), Colors.black38,
                          Colors.white70),
                      if (order.tableId != null)
                        _badge(_tableName(order.tableId),
                            Colors.blue.withOpacity(0.3), Colors.blue),
                      if (isAddon)
                        _badge('ADD-ON', Colors.amber.withOpacity(0.25), Colors.amber.shade300),
                      if (isNew)
                        _badge('NEW', Colors.orange.shade700, Colors.white),
                    ],
                  ),
                ),
                if (minutes > 0)
                  Text('${minutes}m',
                      style: TextStyle(
                          color: isUrgent
                              ? Colors.red.shade300
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.quantity}x',
                          style: TextStyle(
                              color: color.shade300,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(item.menuItem.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canEditSection(ref, 'restaurant_kitchen') ? () => _updateStatus(order, nextStatus) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                  'Mark as ${nextStatus.name[0].toUpperCase()}${nextStatus.name.substring(1)}'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment-due card (accepts 1 or more orders as a group) ──────────────────
  Widget _buildPaymentCard(List<RestaurantOrder> orderGroup) {
    final parent = orderGroup.first;
    final isMulti = orderGroup.length > 1;
    final combinedTotal =
        orderGroup.fold(0.0, (s, o) => s + o.totalAmount);

    return Card(
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.purple.shade700, width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─ Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMulti
                          ? orderGroup.map((o) => '#${o.orderNumber}').join(' + ')
                          : '#${parent.orderNumber}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    if (isMulti)
                      Text(
                        '${orderGroup.length} tickets combined',
                        style: TextStyle(
                            color: Colors.purple.shade300, fontSize: 12),
                      ),
                  ],
                ),
                Text(_timeFormat.format(parent.createdAt),
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            // ─ Badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _badge(parent.type.name.toUpperCase(), Colors.black38,
                    Colors.white70),
                if (parent.tableId != null)
                  _badge(
                      _tableName(parent.tableId),
                      Colors.purple.withOpacity(0.3),
                      Colors.purple.shade200),
                if (isMulti)
                  _badge('COMBINED', Colors.amber.withOpacity(0.2),
                      Colors.amber.shade300),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),

            // ─ Items — per-ticket sub-headers when multi
            ...orderGroup.expand((o) {
              final visibleItems =
                  o.items.where((i) => !i.isFullyRefunded).toList();
              return [
                if (isMulti)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      o.parentOrderId != null
                          ? '— Add-On #${o.orderNumber}'
                          : '— Ticket #${o.orderNumber}',
                      style: TextStyle(
                          color: o.parentOrderId != null
                              ? Colors.teal.shade300
                              : Colors.blue.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ...visibleItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text('${item.activeQuantity}x',
                              style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(item.menuItem.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15))),
                        ],
                      ),
                    )),
              ];
            }),

            const Divider(color: Colors.white24, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isMulti ? 'Combined Total' : 'Total',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
                Text(_currency.format(combinedTotal),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final table = parent.tableId != null
                          ? _tables.firstWhereOrNull((t) => t.id == parent.tableId)
                          : null;
                      showDialog(
                        context: context,
                        builder: (_) => RestaurantInvoiceDialog(
                          order: parent,
                          table: table,
                          allOrders: isMulti ? orderGroup : null,
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_outlined, size: 16),
                    label: const Text('Invoice'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple.shade300,
                      side: BorderSide(color: Colors.purple.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: canEditSection(ref, 'restaurant_kitchen') ? () => _showPaymentDialog(orderGroup) : null,
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: const Text('Collect Payment',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // ── Payment dialog ────────────────────────────────────────────────────────────
  void _showPaymentDialog(List<RestaurantOrder> orderGroup) {
    final tableId = orderGroup.first.tableId;
    final table = tableId != null
        ? _tables.firstWhereOrNull((t) => t.id == tableId)
        : null;

    showDialog(
      context: context,
      builder: (_) => _KitchenPaymentDialog(
        orderGroup: orderGroup,
        table: table,
        restaurantService: _restaurantService,
        bookingService: _bookingService,
        onComplete: () {
          Navigator.pop(context);
          _loadData(silent: true);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Payment dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _KitchenPaymentDialog extends StatefulWidget {
  final List<RestaurantOrder> orderGroup;
  final RestaurantTable? table;
  final RestaurantService restaurantService;
  final BookingService bookingService;
  final VoidCallback onComplete;

  const _KitchenPaymentDialog({
    required this.orderGroup,
    this.table,
    required this.restaurantService,
    required this.bookingService,
    required this.onComplete,
  });

  @override
  State<_KitchenPaymentDialog> createState() =>
      _KitchenPaymentDialogState();
}

class _KitchenPaymentDialogState extends State<_KitchenPaymentDialog> {
  NumberFormat get _currency => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);
  final _uuid = const Uuid();

  // 'cash' | 'card' | 'room'
  String _payMethod = 'cash';
  bool _loading = false;

  List<Map<String, dynamic>> _checkedInGuests = [];
  Map<String, dynamic>? _selectedGuest;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    final enriched = await widget.bookingService.getEnrichedCheckIns();
    final checkedIn = enriched.where((d) {
      final b = d['booking'] as Booking?;
      return b != null && b.status == BookingStatus.checkedIn;
    }).toList();
    if (mounted) setState(() => _checkedInGuests = checkedIn);
  }

  Future<void> _collectPaid() async {
    setState(() => _loading = true);
    final parent = widget.orderGroup.first;
    if (parent.tableId != null) {
      // Settle all open orders for this table at once
      await widget.restaurantService.settleAllTableOrders(
        tableId: parent.tableId!,
        paymentStatus: PaymentStatus.paid,
      );
    } else {
      // Takeaway / no table — settle each order individually
      for (final o in widget.orderGroup) {
        await widget.restaurantService.collectTablePayment(
          orderId: o.id,
          paymentStatus: PaymentStatus.paid,
        );
      }
    }
    if (!mounted) return;
    // Show invoice before dismissing
    await showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(
        order: widget.orderGroup.first,
        table: widget.table,
        allOrders: widget.orderGroup.length > 1 ? widget.orderGroup : null,
      ),
    );
    widget.onComplete();
  }

  Future<void> _collectRoomCharge() async {
    if (_selectedGuest == null) return;
    final b = _selectedGuest!['booking'] as Booking;
    setState(() => _loading = true);
    final parent = widget.orderGroup.first;

    if (parent.tableId != null) {
      // Settle all open orders for this table at once (creates one combined expense)
      await widget.restaurantService.settleAllTableOrders(
        tableId: parent.tableId!,
        paymentStatus: PaymentStatus.chargedToRoom,
        bookingId: b.id,
        roomId: b.roomId,
      );
    } else {
      final combinedAmount =
          widget.orderGroup.fold(0.0, (s, o) => s + o.totalAmount);
      final nums = widget.orderGroup.map((o) => '#${o.orderNumber}').join(', ');
      for (final o in widget.orderGroup) {
        await widget.restaurantService.collectTablePayment(
          orderId: o.id,
          paymentStatus: PaymentStatus.chargedToRoom,
          bookingId: b.id,
          roomId: b.roomId,
        );
      }
      await widget.bookingService.addExpense(Expense(
        id: _uuid.v4(),
        description: 'Restaurant Orders $nums',
        amount: combinedAmount,
        date: DateTime.now(),
        category: ExpenseCategory.restaurant,
        isBillable: true,
        bookingId: b.id,
        roomId: b.roomId,
        isPaid: false,
      ));
    }

    if (!mounted) return;
    // Show invoice before dismissing
    await showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(
        order: widget.orderGroup.first,
        table: widget.table,
        allOrders: widget.orderGroup.length > 1 ? widget.orderGroup : null,
      ),
    );
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orderGroup;
    final combinedTotal = orders.fold(0.0, (s, o) => s + o.totalAmount);
    final titleText = orders.length == 1
        ? 'Collect Payment — #${orders.first.orderNumber}'
        : 'Collect Payment — ${orders.map((o) => "#${o.orderNumber}").join(" + ")}';

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payments_rounded,
              color: Colors.purple, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(titleText,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 120,
                child:
                    Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount due
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Amount Due',
                            style: TextStyle(
                                color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_currency.format(combinedTotal),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.purple)),
                        if (orders.length > 1)
                          Text(
                            '${orders.length} tickets combined',
                            style: TextStyle(
                                color: Colors.purple.shade400, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment method toggle
                  Row(
                    children: [
                      Expanded(
                        child: _methodBtn(
                          icon: Icons.attach_money_rounded,
                          label: 'Cash',
                          selected: _payMethod == 'cash',
                          onTap: () => setState(() => _payMethod = 'cash'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _methodBtn(
                          icon: Icons.credit_card_rounded,
                          label: 'Card',
                          selected: _payMethod == 'card',
                          onTap: () => setState(() => _payMethod = 'card'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _methodBtn(
                          icon: Icons.hotel_rounded,
                          label: 'Room Charge',
                          selected: _payMethod == 'room',
                          onTap: () => setState(() => _payMethod = 'room'),
                        ),
                      ),
                    ],
                  ),

                  // Room charge guest list
                  if (_payMethod == 'room') ...[
                    const SizedBox(height: 16),
                    const Text('Select Guest',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    if (_checkedInGuests.isEmpty)
                      const Text('No checked-in guests.',
                          style: TextStyle(color: Colors.black45))
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          itemCount: _checkedInGuests.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = _checkedInGuests[i];
                            final b = d['booking'] as Booking;
                            final g = d['guest'] as Guest;
                            final r = d['room'];
                            final isSelected =
                                _selectedGuest == d;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor:
                                  Colors.purple.shade50,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    Colors.purple.shade100,
                                child: Icon(Icons.person,
                                    size: 16,
                                    color: Colors.purple.shade700),
                              ),
                              title: Text(g.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              subtitle: Text(
                                  'Room ${r?.roomNumber ?? "?"} · ${b.bookingRef}',
                                  style: const TextStyle(
                                      fontSize: 11)),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: Colors.purple.shade600)
                                  : null,
                              onTap: () => setState(
                                  () => _selectedGuest = d),
                            );
                          },
                        ),
                      ),
                    if (_selectedGuest != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Charging to: ${(_selectedGuest!['guest'] as Guest).fullName}',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
      actions: _loading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _payMethod == 'room'
                    ? (_selectedGuest != null ? _collectRoomCharge : null)
                    : _collectPaid,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(_payMethod == 'room'
                    ? 'Charge to Room'
                    : _payMethod == 'card'
                        ? 'Confirm Card'
                        : 'Confirm Cash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
    );
  }

  Widget _methodBtn({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.purple.shade700
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? Colors.purple.shade700
                  : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.black54,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
