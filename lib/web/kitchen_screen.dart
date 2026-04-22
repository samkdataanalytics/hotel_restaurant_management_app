import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import '../providers/hotel_session.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/expense.dart';
import '../models/restaurant_table.dart';
import '../services/restaurant_service.dart';
import '../models/staff_permission.dart';
import '../services/booking_service.dart';
import 'restaurant_invoice_dialog.dart';
import 'widgets/split_payment_inputs.dart';

// ── Web Audio beep (JS interop) ──────────────────────────────────────────────
@JS('eval')
external JSAny? _jsEval(JSString code);

void _playNotificationBeep() {
  try {
    _jsEval(r'''
      (() => {
        try {
          const ctx = new AudioContext();
          const g = ctx.createGain();
          g.connect(ctx.destination);
          g.gain.value = 0.25;
          const o1 = ctx.createOscillator();
          o1.connect(g); o1.frequency.value = 880; o1.type = 'sine';
          o1.start(ctx.currentTime); o1.stop(ctx.currentTime + 0.12);
          const o2 = ctx.createOscillator();
          o2.connect(g); o2.frequency.value = 1100; o2.type = 'sine';
          o2.start(ctx.currentTime + 0.18); o2.stop(ctx.currentTime + 0.3);
        } catch(e) {}
      })();
    '''.toJS);
  } catch (_) {}
}

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
  int _previousPendingCount = 0;
  bool _soundEnabled = true;

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
    try {
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
      final newPendingCount = todayOrders.where((o) => o.status == OrderStatus.pending).length;
      if (_soundEnabled && newPendingCount > _previousPendingCount && _previousPendingCount >= 0) {
        _playNotificationBeep();
      }
      _previousPendingCount = newPendingCount;
      setState(() {
        _allOrders = todayOrders;
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load kitchen data: $e'), backgroundColor: Colors.red),
      );
    }
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

  String _roomName(String? roomNumber) =>
      roomNumber != null ? 'Room $roomNumber' : 'Room ?';

  // ── Age-based urgency helpers ────────────────────────────────────────────────

  /// Card background colour escalates with age.
  Color _cardBgColor(DateTime createdAt) {
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes >= 15) return const Color(0xFF321515); // dark red tint
    if (minutes >= 8)  return const Color(0xFF2D2610); // dark amber tint
    return const Color(0xFF334155);                    // default slate
  }

  /// Border colour based on age; isNew overrides to orange.
  BorderSide _cardBorderSide(DateTime createdAt, bool isNew) {
    if (isNew) return BorderSide(color: Colors.orange.shade300, width: 2);
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes >= 15) return BorderSide(color: Colors.red.shade400,   width: 2.0);
    if (minutes >= 8)  return BorderSide(color: Colors.amber.shade600, width: 1.5);
    return BorderSide.none;
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
          // Sound toggle
          IconButton(
            icon: Icon(
              _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _soundEnabled ? Colors.green.shade300 : Colors.white38,
            ),
            tooltip: _soundEnabled ? 'Mute alerts' : 'Unmute alerts',
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
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
              nextStatus: OrderStatus.preparing,
              color: Colors.orange,
              bgTint: Colors.orange.withOpacity(0.04),
              emptyLabel: 'No pending orders'),
          _buildColumn('Preparing', _preparingOrders,
              nextStatus: OrderStatus.ready,
              color: Colors.blue,
              bgTint: Colors.blue.withOpacity(0.04),
              emptyLabel: 'Nothing in progress'),
          _buildColumn('Ready to Serve', _readyOrders,
              nextStatus: OrderStatus.served,
              color: Colors.green,
              bgTint: Colors.green.withOpacity(0.05),
              emptyLabel: 'All caught up!'),
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
    Color? bgTint,
    String emptyLabel = 'No orders',
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgTint != null
              ? Color.alphaBlend(bgTint, const Color(0xFF0F172A).withOpacity(0.5))
              : const Color(0xFF0F172A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _columnHeader(title, orders.length, color),
            Expanded(
              child: orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: color.withOpacity(0.25), size: 40),
                          const SizedBox(height: 8),
                          Text(emptyLabel,
                              style: TextStyle(
                                  color: color.withOpacity(0.45),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
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
    final age        = DateTime.now().difference(order.createdAt);
    final isNew      = order.status == OrderStatus.pending && age.inSeconds < 30;
    final isAddon    = order.parentOrderId != null;
    final isTakeaway = order.type == OrderType.takeaway;

    return Card(
      color: isTakeaway ? const Color(0xFF2D2208) : _cardBgColor(order.createdAt),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isTakeaway
            ? const BorderSide(color: Colors.amber, width: 2)
            : _cardBorderSide(order.createdAt, isNew),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Takeaway banner ───────────────────────────────────────────────
          if (isTakeaway)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFB45309),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📦', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 8),
                  Text('PACK FOR TAKEAWAY',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
          Padding(
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
                          if (order.type == OrderType.roomService)
                            _badge('ROOM SERVICE', Colors.purple.withOpacity(0.3), Colors.purpleAccent.shade100)
                          else if (isTakeaway)
                            _badge('TAKEAWAY', Colors.amber.withOpacity(0.3), Colors.amber.shade300)
                          else
                            _badge(order.type.name.toUpperCase(), Colors.black38, Colors.white70),
                          if (order.type == OrderType.roomService && order.tableId != null)
                            _badge(_roomName(order.tableId),
                                Colors.purple.withOpacity(0.2), Colors.purple.shade200)
                          else if (order.tableId != null)
                            _badge(_tableName(order.tableId),
                                Colors.blue.withOpacity(0.3), Colors.blue),
                          if (isAddon)
                            _badge('ADD-ON', Colors.amber.withOpacity(0.25), Colors.amber.shade300),
                          if (isNew)
                            _badge('NEW', Colors.orange.shade700, Colors.white),
                        ],
                      ),
                    ),
                    _ElapsedTimerBadge(createdAt: order.createdAt),
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
                                  color: isTakeaway
                                      ? Colors.amber.shade300
                                      : color.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.menuItem.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                if (item.selectedModifiers.isNotEmpty)
                                  ...item.selectedModifiers.entries
                                      .where((e) => e.value.isNotEmpty)
                                      .map((e) {
                                        final counts = <String, int>{};
                                        for (final n in e.value) {
                                          counts[n] = (counts[n] ?? 0) + 1;
                                        }
                                        final summary = counts.entries.map((c) => c.value > 1 ? '${c.key} ×${c.value}' : c.key).join(', ');
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${e.key}: $summary',
                                            style: TextStyle(
                                              color: Colors.blue.shade200,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }),
                                if (item.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '⚠ ${item.notes}',
                                      style: TextStyle(
                                        color: Colors.orange.shade300,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                // Reminder shown in the Ready column for takeaway
                if (isTakeaway && nextStatus == OrderStatus.served) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withOpacity(0.35)),
                    ),
                    child: const Row(
                      children: [
                        Text('📦', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Hand to customer — do not plate',
                              style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: canEditSection(ref, 'restaurant_kitchen') ? () => _updateStatus(order, nextStatus) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTakeaway ? Colors.amber.shade700 : color.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isTakeaway && nextStatus == OrderStatus.ready
                        ? 'Mark as Ready — Packed ✓'
                        : 'Mark as ${nextStatus.name[0].toUpperCase()}${nextStatus.name.substring(1)}',
                  ),
                ),
                if (canEditSection(ref, 'restaurant_kitchen'))
                  TextButton.icon(
                    onPressed: () => _cancelOrderKitchen(order),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    icon: Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade300),
                    label: const Text('Cancel Order', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cancel order from kitchen ─────────────────────────────────────────────────
  Future<void> _cancelOrderKitchen(RestaurantOrder order) async {
    final isPending = order.status == OrderStatus.pending;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12)),
        title: Row(children: [
          const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Text(
            isPending ? 'Cancel Order?' : 'Cancel Order — Food May Be Ready',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ]),
        content: Text(
          isPending
              ? 'This order will be cancelled and inventory will be restored.'
              : 'The order is being prepared. Cancelling will NOT restore inventory — food is already being made.',
          style: TextStyle(
            color: isPending ? Colors.white70 : Colors.orange.shade300,
            fontSize: 14, height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Keep', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _restaurantService.cancelOrder(order.id);
      await _loadData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
                if (orderGroup.any((o) => o.type == OrderType.dineIn))
                  _badge('DINE-IN', Colors.blue.withOpacity(0.2), Colors.blue.shade300),
                if (orderGroup.any((o) => o.type == OrderType.takeaway))
                  _badge('📦 TAKEAWAY', Colors.amber.withOpacity(0.2), Colors.amber.shade300),
                if (orderGroup.any((o) => o.type == OrderType.roomService))
                  _badge('ROOM SERVICE', Colors.purple.withOpacity(0.2), Colors.purple.shade300),
                if (!orderGroup.any((o) => o.type == OrderType.dineIn ||
                    o.type == OrderType.takeaway || o.type == OrderType.roomService))
                  _badge(parent.type.name.toUpperCase(), Colors.black38, Colors.white70),
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
              final isTakeawayTicket = o.type == OrderType.takeaway;
              return [
                if (isMulti)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      isTakeawayTicket
                          ? '📦 Takeaway #${o.orderNumber}'
                          : o.parentOrderId != null
                              ? '— Add-On #${o.orderNumber}'
                              : '— Ticket #${o.orderNumber}',
                      style: TextStyle(
                          color: isTakeawayTicket
                              ? Colors.amber.shade300
                              : o.parentOrderId != null
                              ? Colors.teal.shade300
                              : Colors.blue.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ...visibleItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.activeQuantity}x',
                              style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.menuItem.name,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15)),
                                  if (item.selectedModifiers.isNotEmpty)
                                    ...item.selectedModifiers.entries
                                        .where((e) => e.value.isNotEmpty)
                                        .map((e) {
                                          final counts = <String, int>{};
                                          for (final n in e.value) {
                                            counts[n] = (counts[n] ?? 0) + 1;
                                          }
                                          final summary = counts.entries.map((c) => c.value > 1 ? '${c.key} ×${c.value}' : c.key).join(', ');
                                          return Text(
                                            '${e.key}: $summary',
                                            style: TextStyle(
                                              color: Colors.blue.shade200,
                                              fontSize: 11,
                                            ),
                                          );
                                        }),
                                ],
                              )),
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
          _loadData(silent: true);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Live elapsed-time badge — rebuilds itself every second independently
// ═══════════════════════════════════════════════════════════════════════════════

class _ElapsedTimerBadge extends StatefulWidget {
  final DateTime createdAt;
  const _ElapsedTimerBadge({required this.createdAt});

  @override
  State<_ElapsedTimerBadge> createState() => _ElapsedTimerBadgeState();
}

class _ElapsedTimerBadgeState extends State<_ElapsedTimerBadge> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(widget.createdAt));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;

    final Color color;
    final IconData icon;
    if (minutes >= 15) {
      color = Colors.red.shade300;
      icon  = Icons.warning_amber_rounded;
    } else if (minutes >= 8) {
      color = Colors.amber.shade400;
      icon  = Icons.timer_outlined;
    } else {
      color = Colors.grey.shade500;
      icon  = Icons.timer_outlined;
    }

    final label = minutes > 0
        ? '${minutes}m ${seconds.toString().padLeft(2, '0')}s'
        : '${seconds}s';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
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

  // Discount
  String _discountType   = 'percentage';
  double _discountAmount = 0.0;
  final  _discountCtrl   = TextEditingController();

  // Split payment
  bool   _splitMode  = false;
  double _splitCash  = 0.0;
  double _splitCard  = 0.0;
  final  _splitCashCtrl = TextEditingController();
  final  _splitCardCtrl = TextEditingController();

  double _discountValue(double itemsTotal) {
    if (_discountAmount <= 0) return 0.0;
    if (_discountType == 'percentage') return itemsTotal * (_discountAmount / 100);
    return _discountAmount;
  }

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    super.dispose();
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
    final updatedOrders = await _applyDiscountAndSettle(
      paymentStatus: PaymentStatus.paid,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(
        order: updatedOrders.first,
        table: widget.table,
        allOrders: updatedOrders.length > 1 ? updatedOrders : null,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onComplete();
  }

  Future<void> _collectRoomCharge() async {
    if (_selectedGuest == null) return;
    final b = _selectedGuest!['booking'] as Booking;
    setState(() => _loading = true);
    final updatedOrders = await _applyDiscountAndSettle(
      paymentStatus: PaymentStatus.chargedToRoom,
      bookingId: b.id,
      roomId: b.roomId,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(
        order: updatedOrders.first,
        table: widget.table,
        allOrders: updatedOrders.length > 1 ? updatedOrders : null,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onComplete();
  }

  Future<void> _collectSplit() async {
    setState(() => _loading = true);
    final updatedOrders = await _applyDiscountAndSettle(
      paymentStatus: PaymentStatus.paid,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(
        order: updatedOrders.first,
        table: widget.table,
        allOrders: updatedOrders.length > 1 ? updatedOrders : null,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onComplete();
  }

  /// Applies the discount to the first order, then settles all orders.
  /// Returns the order group with the first order updated to carry the discount.
  Future<List<RestaurantOrder>> _applyDiscountAndSettle({
    required PaymentStatus paymentStatus,
    String? bookingId,
    String? roomId,
  }) async {
    final orders    = widget.orderGroup;
    final parent    = orders.first;
    final settings  = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate           = settings?.taxRate           ?? 0.0;
    final serviceChargeRate = settings?.serviceChargeRate ?? 0.0;

    final itemsTotal = orders.fold(0.0, (s, o) => s + o.itemsTotal);
    final dv = _discountValue(itemsTotal);
    final String? dType  = dv > 0 ? _discountType : null;
    final double  dAmt   = _discountAmount;

    final subtotal = (itemsTotal - dv).clamp(0.0, double.infinity);
    final tax      = subtotal * taxRate;
    // Service charge only on dine-in / room-service orders
    final dineInItemsTotal = orders
        .where((o) => o.type != OrderType.takeaway && o.type != OrderType.delivery)
        .fold(0.0, (s, o) => s + o.itemsTotal);
    final dineInFraction = itemsTotal > 0 ? dineInItemsTotal / itemsTotal : 1.0;
    final svc      = (dineInFraction * subtotal) * serviceChargeRate;
    final finalTotal = subtotal + tax + svc;

    // Apply discount to first order in DB
    if (dType != null) {
      await widget.restaurantService.updateOrderDiscount(
        orderId:        parent.id,
        discountType:   dType,
        discountAmount: dAmt,
      );
    }

    if (parent.tableId != null) {
      await widget.restaurantService.settleAllTableOrders(
        tableId: parent.tableId!,
        paymentStatus: paymentStatus,
        bookingId: bookingId,
        roomId: roomId,
        finalTotal: finalTotal,
      );
    } else {
      final nums = orders.map((o) => '#${o.orderNumber}').join(', ');
      for (final o in orders) {
        await widget.restaurantService.collectTablePayment(
          orderId: o.id,
          paymentStatus: paymentStatus,
          bookingId: bookingId,
          // Pass roomId: null here — we create ONE combined expense below
          // to avoid double-billing (collectTablePayment would also add an expense).
          roomId: null,
        );
      }
      if (paymentStatus == PaymentStatus.chargedToRoom && bookingId != null) {
        await widget.bookingService.addExpense(Expense(
          id: _uuid.v4(),
          description: 'Restaurant Orders $nums',
          amount: finalTotal,
          date: DateTime.now(),
          category: ExpenseCategory.restaurant,
          isBillable: true,
          bookingId: bookingId,
          roomId: roomId,
          isPaid: false,
        ));
      }
    }

    // Return updated orders with discount reflected in first order
    final updatedFirst = parent.copyWith(discountType: dType, discountAmount: dAmt);
    return [updatedFirst, ...widget.orderGroup.skip(1)];
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orderGroup;
    final settings = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate           = settings?.taxRate           ?? 0.0;
    final serviceChargeRate = settings?.serviceChargeRate ?? 0.0;
    final itemsTotal = orders.fold(0.0, (s, o) => s + o.itemsTotal);
    final dv       = _discountValue(itemsTotal);
    final subtotal = (itemsTotal - dv).clamp(0.0, double.infinity);
    final tax      = subtotal * taxRate;
    // Service charge applies only to dine-in / room-service orders, not takeaway
    final dineInItemsTotal = orders
        .where((o) => o.type != OrderType.takeaway && o.type != OrderType.delivery)
        .fold(0.0, (s, o) => s + o.itemsTotal);
    final dineInFraction = itemsTotal > 0 ? dineInItemsTotal / itemsTotal : 1.0;
    final svc      = (dineInFraction * subtotal) * serviceChargeRate;
    final total    = subtotal + tax + svc;
    final hasMixedTypes = orders.any((o) => o.type == OrderType.takeaway || o.type == OrderType.delivery)
        && orders.any((o) => o.type != OrderType.takeaway && o.type != OrderType.delivery);
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
                  // ── Discount row ─────────────────────────────────────────
                  Row(
                    children: [
                      _discountToggle('%', 'percentage'),
                      const SizedBox(width: 4),
                      _discountToggle('Flat', 'flat'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _discountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _discountType == 'percentage' ? 'Discount %' : 'Discount amount',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            suffixText: _discountType == 'percentage' ? '%' : null,
                          ),
                          onChanged: (v) => setState(() {
                            final raw = double.tryParse(v.trim()) ?? 0.0;
                            final total = widget.orderGroup.fold(0.0, (s, o) => s + o.itemsTotal);
                            _discountAmount = _discountType == 'percentage'
                                ? raw.clamp(0.0, 100.0)
                                : raw.clamp(0.0, total);
                          }),
                        ),
                      ),
                      if (_discountAmount > 0) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => setState(() {
                            _discountAmount = 0.0;
                            _discountCtrl.clear();
                          }),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Items', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text(_currency.format(itemsTotal), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        if (dv > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _discountType == 'percentage'
                                    ? 'Discount (${_discountAmount.toStringAsFixed(0)}%)'
                                    : 'Discount',
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                              ),
                              Text('− ${_currency.format(dv)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ],
                        if (taxRate > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tax (${(taxRate * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              Text(_currency.format(tax), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                        if (svc > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hasMixedTypes
                                    ? 'Service (${(serviceChargeRate * 100).toStringAsFixed(0)}%) — dine-in only'
                                    : 'Service (${(serviceChargeRate * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              Text(_currency.format(svc), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                        const Divider(height: 12),
                        const Text('TOTAL DUE', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_currency.format(total),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment method',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45)),
                      SplitPaymentToggle(
                        active: _splitMode,
                        onTap: () => setState(() {
                          _splitMode = !_splitMode;
                          if (_splitMode) {
                            _splitCash = 0;
                            _splitCard = 0;
                            _splitCashCtrl.clear();
                            _splitCardCtrl.clear();
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_splitMode) Row(
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

                  // Split payment inputs
                  if (_splitMode) ...[
                    const SizedBox(height: 10),
                    SplitPaymentInputs(
                      total: total,
                      currency: _currency,
                      cashCtrl: _splitCashCtrl,
                      cardCtrl: _splitCardCtrl,
                      cashAmount: _splitCash,
                      cardAmount: _splitCard,
                      onChanged: (cash, card) => setState(() {
                        _splitCash = cash;
                        _splitCard = card;
                      }),
                    ),
                  ],

                  // Room charge guest list
                  if (!_splitMode && _payMethod == 'room') ...[
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
                onPressed: _splitMode
                    ? ((_splitCash + _splitCard - total).abs() < 0.01 ? _collectSplit : null)
                    : _payMethod == 'room'
                        ? (_selectedGuest != null ? _collectRoomCharge : null)
                        : _collectPaid,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(_splitMode
                    ? 'Confirm Split Payment'
                    : _payMethod == 'room'
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

  Widget _discountToggle(String label, String value) {
    final active = _discountType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _discountType   = value;
        final raw = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
        final total = widget.orderGroup.fold(0.0, (s, o) => s + o.itemsTotal);
        _discountAmount = value == 'percentage'
            ? raw.clamp(0.0, 100.0)
            : raw.clamp(0.0, total);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.purple.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black54)),
      ),
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
