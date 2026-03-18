import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/expense.dart';
import '../services/restaurant_service.dart';
import '../services/booking_service.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _restaurantService = RestaurantService();
  final _bookingService = BookingService();
  final _timeFormat = DateFormat('hh:mm a');

  List<RestaurantOrder> _allOrders = [];
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final orders = await _restaurantService.getOrders();
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
      _isLoading = false;
    });
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
  Widget _buildPaymentColumn() {
    final orders = _paymentDueOrders;
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
                    child: Text('${orders.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
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
                      itemCount: orders.length,
                      itemBuilder: (_, i) =>
                          _buildPaymentCard(orders[i]),
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
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isUrgent =
        order.status == OrderStatus.pending && minutes > 15;

    return Card(
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isUrgent
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
              children: [
                _badge(order.type.name.toUpperCase(), Colors.black38,
                    Colors.white70),
                if (order.tableId != null) ...[
                  const SizedBox(width: 8),
                  _badge('Tbl ${order.tableId!.substring(order.tableId!.length > 4 ? order.tableId!.length - 4 : 0)}',
                      Colors.blue.withOpacity(0.3), Colors.blue),
                ],
                const Spacer(),
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
              onPressed: () => _updateStatus(order, nextStatus),
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

  // ── Payment-due card ─────────────────────────────────────────────────────────
  Widget _buildPaymentCard(RestaurantOrder order) {
    final currency =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
              children: [
                _badge(order.type.name.toUpperCase(), Colors.black38,
                    Colors.white70),
                if (order.tableId != null) ...[
                  const SizedBox(width: 8),
                  _badge(
                      'Tbl ${order.tableId!.substring(order.tableId!.length > 4 ? order.tableId!.length - 4 : 0)}',
                      Colors.purple.withOpacity(0.3),
                      Colors.purple.shade200),
                ],
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            ...order.items
                .where((i) => !i.isFullyRefunded)
                .map((item) => Padding(
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
                                      color: Colors.white,
                                      fontSize: 15))),
                        ],
                      ),
                    )),
            const Divider(color: Colors.white24, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
                Text(currency.format(order.totalAmount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _showPaymentDialog(order),
              icon: const Icon(Icons.payments_rounded, size: 16),
              label: const Text('Collect Payment',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
  void _showPaymentDialog(RestaurantOrder order) {
    showDialog(
      context: context,
      builder: (_) => _KitchenPaymentDialog(
        order: order,
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
  final RestaurantOrder order;
  final RestaurantService restaurantService;
  final BookingService bookingService;
  final VoidCallback onComplete;

  const _KitchenPaymentDialog({
    required this.order,
    required this.restaurantService,
    required this.bookingService,
    required this.onComplete,
  });

  @override
  State<_KitchenPaymentDialog> createState() =>
      _KitchenPaymentDialogState();
}

class _KitchenPaymentDialogState extends State<_KitchenPaymentDialog> {
  final _currency =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
    await widget.restaurantService.collectTablePayment(
      orderId: widget.order.id,
      paymentStatus: PaymentStatus.paid,
    );
    widget.onComplete();
  }

  Future<void> _collectRoomCharge() async {
    if (_selectedGuest == null) return;
    final b = _selectedGuest!['booking'] as Booking;
    setState(() => _loading = true);

    await widget.restaurantService.collectTablePayment(
      orderId: widget.order.id,
      paymentStatus: PaymentStatus.chargedToRoom,
      bookingId: b.id,
      roomId: b.roomId,
    );

    // Record expense on the room invoice
    await widget.bookingService.addExpense(Expense(
      id: _uuid.v4(),
      description: 'Restaurant Order #${widget.order.orderNumber}',
      amount: widget.order.totalAmount,
      date: DateTime.now(),
      category: ExpenseCategory.restaurant,
      isBillable: true,
      bookingId: b.id,
      roomId: b.roomId,
      isPaid: false,
    ));

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.totalAmount;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.payments_rounded,
              color: Colors.purple, size: 22),
          const SizedBox(width: 10),
          Text('Collect Payment — #${widget.order.orderNumber}'),
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
                        Text(_currency.format(total),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.purple)),
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
