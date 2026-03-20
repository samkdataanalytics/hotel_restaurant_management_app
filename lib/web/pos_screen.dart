import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/expense.dart';
import '../services/restaurant_service.dart';
import '../models/staff_permission.dart';
import '../services/booking_service.dart';
import 'restaurant_invoice_dialog.dart';

// ─── Restaurant brand colors — sourced from AppTheme ─────────────────────────
const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _restaurantService = RestaurantService();
  final _bookingService = BookingService();
  NumberFormat get _currencyFormat => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);
  final _uuid = const Uuid();

  List<MenuItem> _menuItems = [];
  List<RestaurantTable> _tables = [];
  String _selectedCategory = 'All';

  List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String? _selectedTableId;
  String? _selectedBookingId;

  bool _isLoading = true;
  /// All open (non-cancelled, non-paid) orders per table, sorted oldest→newest.
  Map<String, List<RestaurantOrder>> _allTableOrders = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await _restaurantService.getMenuItems();
    final tables = await _restaurantService.getTables();

    // Load orders separately — bad stored data should never block the menu
    List<RestaurantOrder> orders = [];
    try {
      orders = await _restaurantService.getOrders();
    } catch (_) {}

    if (!mounted) return;

    // Build open-order map: tableId → list of all open orders (oldest→newest).
    final allOrders = <String, List<RestaurantOrder>>{};
    for (final o in orders) {
      if (o.tableId == null) continue;
      if (o.status == OrderStatus.cancelled) continue;
      if (o.paymentStatus == PaymentStatus.paid ||
          o.paymentStatus == PaymentStatus.chargedToRoom) continue;
      allOrders.putIfAbsent(o.tableId!, () => []).add(o);
    }
    for (final list in allOrders.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    setState(() {
      _menuItems = items;
      _tables = tables;
      _allTableOrders = allOrders;
      _isLoading = false;
    });
  }

  List<String> get _categories {
    final cats = _menuItems.map((e) => e.category).toSet().toList();
    cats.insert(0, 'All');
    return cats;
  }

  List<MenuItem> get _filteredMenu {
    if (_selectedCategory == 'All') return _menuItems;
    return _menuItems.where((e) => e.category == _selectedCategory).toList();
  }

  double get _cartTotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  void _addToCart(MenuItem item) {
    if (!item.isAvailable) return;
    setState(() {
      final idx = _cart.indexWhere((e) => e.menuItem.id == item.id);
      if (idx >= 0) {
        _cart[idx].quantity++;
      } else {
        _cart.add(OrderItem(id: _uuid.v4(), menuItem: item, quantity: 1));
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQ = _cart[index].quantity + delta;
      if (newQ > 0) {
        _cart[index].quantity = newQ;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  Future<RestaurantOrder?> _checkout({required PaymentStatus paymentStatus, String? bookingId, String? roomId}) async {
    if (_cart.isEmpty) return null;
    if (_orderType == OrderType.dineIn && _selectedTableId == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a table for Dine-in orders.'),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }

    setState(() => _isLoading = true);

    final order = RestaurantOrder(
      id: _uuid.v4(),
      orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableId: _selectedTableId,
      type: _orderType,
      status: OrderStatus.pending,
      paymentStatus: paymentStatus,
      bookingId: bookingId,
      createdAt: DateTime.now(),
      items: List.from(_cart),
    );

    await _restaurantService.saveOrder(order); // also deducts inventory

    if (paymentStatus == PaymentStatus.chargedToRoom && bookingId != null) {
      await _bookingService.addExpense(Expense(
        id: _uuid.v4(),
        description: 'Restaurant Order #${order.orderNumber}',
        amount: order.totalAmount,
        date: DateTime.now(),
        category: ExpenseCategory.restaurant,
        isBillable: true,
        bookingId: bookingId,
        roomId: roomId,   // ← needed so RoomExpensesDialog picks it up
        isPaid: false,
      ));
    }

    setState(() {
      _cart.clear();
      // Keep _selectedTableId so the next order can be placed immediately
      // for the same table (e.g. dessert after mains).
      _selectedBookingId = null;
      _isLoading = false;
    });

    // Refresh tables to reflect the latest occupancy status.
    _loadData();

    return order;
  }

  Future<void> _handleCheckout(PaymentStatus status, {String? bookingId, String? roomId}) async {
    final order = await _checkout(paymentStatus: status, bookingId: bookingId, roomId: roomId);
    if (order == null || !mounted) return;
    // Clear any queued snackbars (e.g. previous "Order placed!" still visible)
    // before showing the new one so messages never stack invisibly.
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${order.orderNumber} placed!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Print Invoice',
          textColor: Colors.white,
          onPressed: () {
            if (mounted) _showInvoiceDialog(order);
          },
        ),
      ),
    );
  }

  Future<void> _showChargeToRoomDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final enrichedBookings = await _bookingService.getEnrichedBookings();
    final active = enrichedBookings
        .where((d) => (d['booking'] as Booking).status == BookingStatus.checkedIn)
        .toList();
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.hotel_rounded, color: AppTheme.warning, size: 20),
            const SizedBox(width: 8),
            const Text('Charge to Room'),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 360,
          child: active.isEmpty
              ? const Center(child: Text('No checked-in guests found.', style: TextStyle(color: Colors.black38)))
              : ListView.builder(
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final b = active[i]['booking'] as Booking;
                    final g = active[i]['guest'] as Guest;
                    final r = active[i]['room'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.adminPrimary.withOpacity(0.1),
                        child: Icon(Icons.bed, color: AppTheme.adminPrimary),
                      ),
                      title: Text(g.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Room ${r?.roomNumber ?? "N/A"} • Ref: ${b.bookingRef}'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleCheckout(
                            PaymentStatus.chargedToRoom,
                            bookingId: b.id,
                            roomId: b.roomId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Charge'),
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
  }

  void _showInvoiceDialog(RestaurantOrder order, {List<RestaurantOrder>? allOrders}) {
    final table = order.tableId != null
        ? _tables.firstWhere((t) => t.id == order.tableId, orElse: () => RestaurantTable(id: '', tableNumber: '?', capacity: 0))
        : null;
    showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(order: order, table: table, allOrders: allOrders ?? (openOrdersAvailable(order) ? _allTableOrders[order.tableId!] : null)),
    );
  }

  bool openOrdersAvailable(RestaurantOrder order) {
    return order.tableId != null && _allTableOrders.containsKey(order.tableId) && _allTableOrders[order.tableId!]!.length > 1;
  }

  // ─── BUILD ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryTabs(),
                Expanded(child: _buildMenuGrid()),
              ],
            ),
          ),
          _buildCart(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _kOrangeBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.point_of_sale_rounded, color: _kOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Text('Restaurant POS', style: Theme.of(context).textTheme.displayMedium),
          const Spacer(),
          Text(DateFormat('EEEE, MMM dd').format(DateTime.now()),
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black45, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 58,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSel = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            child: ChoiceChip(
              label: Text(cat,
                  style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
              selected: isSel,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: _kOrange,
              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
              backgroundColor: Colors.grey.shade100,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _filteredMenu.length,
      itemBuilder: (_, i) => _buildMenuTile(_filteredMenu[i]),
    );
  }

  Widget _buildMenuTile(MenuItem item) {
    final unavailable = !item.isAvailable;
    return GestureDetector(
      onTap: unavailable || !canEditSection(ref, 'restaurant_pos') ? null : () => _addToCart(item),
      child: Opacity(
        opacity: unavailable ? 0.45 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: unavailable ? Border.all(color: Colors.grey.shade300) : null,
            boxShadow: unavailable
                ? null
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(item.imageUrl.isNotEmpty ? item.imageUrl : '🍽️',
                          style: const TextStyle(fontSize: 44)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(unavailable ? 'Unavailable' : _currencyFormat.format(item.price),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: unavailable ? Colors.red.shade400 : _kOrange,
                          fontSize: 13)),
                ],
              ),
              if (unavailable)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('OFF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CART ────────────────────────────────────────────

  Widget _buildCart() {
    return Container(
      width: 370,
      color: Colors.white,
      child: Column(
        children: [
          _buildCartHeader(),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('Cart is empty', style: TextStyle(color: Colors.black38, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) => _buildCartItem(_cart[i], i),
                  ),
          ),
          _buildCartFooter(),
        ],
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${_cart.length} items',
                    style: const TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _typeBtn('Dine-in', OrderType.dineIn)),
              const SizedBox(width: 8),
              Expanded(child: _typeBtn('Takeaway', OrderType.takeaway)),
            ],
          ),
          if (_orderType == OrderType.dineIn) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Table',
                prefixIcon: const Icon(Icons.table_restaurant_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              value: _selectedTableId,
              items: _tables.map((t) {
                final hasTab = _allTableOrders.containsKey(t.id);
                return DropdownMenuItem(
                  value: t.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Table ${t.tableNumber} (${t.capacity} pax)'),
                      if (hasTab) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ACTIVE TAB',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _kOrange)),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedTableId = val),
            ),
            if (_selectedTableId != null &&
                _allTableOrders.containsKey(_selectedTableId!))
              _buildActiveTabBanner(_allTableOrders[_selectedTableId!]!),
          ],
        ],
      ),
    );
  }

  Widget _typeBtn(String label, OrderType type) {
    final sel = _orderType == type;
    return ElevatedButton(
      onPressed: () => setState(() {
        _orderType = type;
        if (type == OrderType.takeaway) _selectedTableId = null;
      }),
      style: ElevatedButton.styleFrom(
        backgroundColor: sel ? _kOrange : Colors.grey.shade100,
        foregroundColor: sel ? Colors.white : Colors.black54,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildCartItem(OrderItem item, int index) {
    return Row(
      children: [
        // Qty controls
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _updateQuantity(index, 1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.add, size: 14)),
              ),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              InkWell(
                onTap: () => _updateQuantity(index, -1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.remove, size: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.menuItem.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(_currencyFormat.format(item.menuItem.price),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
        Text(_currencyFormat.format(item.subtotal),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          // Subtotal row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              Text(_currencyFormat.format(_cartTotal),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kOrange)),
            ],
          ),
          const SizedBox(height: 14),
          // Cash / Card
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty || !canEditSection(ref, 'restaurant_pos') ? null : () => _handleCheckout(PaymentStatus.paid),
                  icon: const Icon(Icons.attach_money_rounded, size: 18),
                  label: const Text('Cash', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty || !canEditSection(ref, 'restaurant_pos') ? null : () => _handleCheckout(PaymentStatus.paid),
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: const Text('Card', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          // ── Send to Kitchen (shown when selected table has an in-progress order) ──
          Builder(builder: (_) {
            if (_orderType != OrderType.dineIn || _selectedTableId == null) {
              return const SizedBox.shrink();
            }
            final openOrders = _allTableOrders[_selectedTableId!];
            if (openOrders == null || openOrders.isEmpty) return const SizedBox.shrink();
            final latest = openOrders.last;
            final inKitchen = latest.status == OrderStatus.preparing ||
                latest.status == OrderStatus.ready;
            if (!inKitchen) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _sendAddonOrder,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _cart.isEmpty
                        ? 'Add items then Send to Kitchen'
                        : 'Send Add-On to Kitchen  ·  ${_currencyFormat.format(_cartTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF0D9488).withOpacity(0.35),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _showChargeToRoomDialog,
                  icon: const Icon(Icons.hotel_rounded, size: 16),
                  label: const Text('Room Charge', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cart.isEmpty ? null : () {
                    // Build a preview order to show invoice without placing it
                    final previewOrder = RestaurantOrder(
                      id: 'preview',
                      orderNumber: 'PREVIEW',
                      tableId: _selectedTableId,
                      type: _orderType,
                      status: OrderStatus.pending,
                      paymentStatus: PaymentStatus.unpaid,
                      createdAt: DateTime.now(),
                      items: List.from(_cart),
                    );
                    _showInvoiceDialog(previewOrder);
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _kOrange,
                    side: const BorderSide(color: _kOrange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Banner shown below the table dropdown when the selected table has open orders.
  ///
  /// States:
  ///  • pending          → "Active tab" — [View Invoice] [Add Cart to Tab]
  ///  • preparing/ready  → "In kitchen" — [Send to Kitchen] (creates add-on order)
  ///  • served + unpaid  → "Payment due" — [Collect Payment]
  ///  Multiple open orders → combined total shown
  Widget _buildActiveTabBanner(List<RestaurantOrder> openOrders) {
    if (openOrders.isEmpty) return const SizedBox.shrink();

    final latestOrder = openOrders.last;
    final combinedTotal = openOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final combinedItems = openOrders.fold(0, (s, o) => s + o.items.fold(0, (si, i) => si + i.activeQuantity));
    final hasMultiple = openOrders.length > 1;

    const _kPurple = Color(0xFF8B5CF6);
    const _kPurpleBg = Color(0xFFF5F3FF);
    const _kTeal = Color(0xFF0D9488);
    const _kTealBg = Color(0xFFF0FDFA);

    // Determine state based on latest order
    final allServedUnpaid = openOrders.every((o) =>
        o.status == OrderStatus.served && o.paymentStatus == PaymentStatus.unpaid);
    final latestIsInKitchen = latestOrder.status == OrderStatus.preparing ||
        latestOrder.status == OrderStatus.ready;
    final isPaymentDue = allServedUnpaid;
    final isInKitchen = !isPaymentDue && latestIsInKitchen;

    // Pick color theme
    final Color accentColor;
    final Color bgColor;
    final Color borderColor;
    final IconData headerIcon;
    final String statusBadge;

    if (isPaymentDue) {
      accentColor = _kPurple; bgColor = _kPurpleBg;
      borderColor = _kPurple.withOpacity(0.45);
      headerIcon = Icons.payments_rounded; statusBadge = 'PAYMENT DUE';
    } else if (isInKitchen) {
      accentColor = _kTeal; bgColor = _kTealBg;
      borderColor = _kTeal.withOpacity(0.45);
      headerIcon = Icons.restaurant_rounded;
      statusBadge = latestOrder.status == OrderStatus.preparing ? 'PREPARING' : 'READY';
    } else {
      accentColor = _kOrange; bgColor = _kOrangeBg;
      borderColor = _kOrange.withOpacity(0.35);
      headerIcon = Icons.receipt_long_rounded; statusBadge = 'ACTIVE';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + summary + badge
          Row(
            children: [
              Icon(headerIcon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: hasMultiple
                    ? Text(
                        '${openOrders.length} open orders · $combinedItems item(s)  ·  ${_currencyFormat.format(combinedTotal)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor),
                      )
                    : Text(
                        '$combinedItems item(s)  ·  ${_currencyFormat.format(combinedTotal)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
                child: Text(statusBadge,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),

          // In-kitchen hint
          if (isInKitchen) ...[
            const SizedBox(height: 6),
            Text(
              'Order is ${latestOrder.status.name} in the kitchen. New items will be sent as a separate kitchen ticket.',
              style: TextStyle(fontSize: 11, color: accentColor.withOpacity(0.8)),
            ),
          ],

          const SizedBox(height: 8),

          // Action row
          if (isPaymentDue)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _collectPayment(openOrders),
                icon: const Icon(Icons.payment_rounded, size: 15),
                label: Text(
                  hasMultiple
                      ? 'Collect Payment · ${_currencyFormat.format(combinedTotal)}'
                      : 'Collect Payment',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            )
          else if (isInKitchen)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showInvoiceDialog(latestOrder, allOrders: openOrders),
                  icon: const Icon(Icons.receipt_outlined, size: 13),
                  label: const Text('View Invoice', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTeal,
                    side: const BorderSide(color: _kTeal),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                ),
                const SizedBox(width: 8),
                if (_cart.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _sendAddonOrder,
                    icon: const Icon(Icons.send_rounded, size: 13),
                    label: const Text('Send to Kitchen', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
              ],
            )
          else
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showInvoiceDialog(latestOrder, allOrders: openOrders),
                  icon: const Icon(Icons.receipt_outlined, size: 13),
                  label: const Text('View Invoice', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kOrange,
                    side: const BorderSide(color: _kOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                ),
                const SizedBox(width: 8),
                if (_cart.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _addCartToTab,
                    icon: const Icon(Icons.playlist_add_rounded, size: 13),
                    label: const Text('Add Cart to Tab', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Collect payment for all open orders on a table (combined settlement).
  Future<void> _collectPayment(List<RestaurantOrder> openOrders) async {
    if (openOrders.isEmpty) return;
    final tableId = openOrders.first.tableId!;
    final table = _tables.firstWhere((t) => t.id == tableId,
        orElse: () => RestaurantTable(id: '', tableNumber: '?', capacity: 0));
    final combinedTotal = openOrders.fold(0.0, (s, o) => s + o.totalAmount);

    final result = await showDialog<_PosPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PosPaymentDialog(
        displayOrder: openOrders.last,
        table: table,
        bookingService: _bookingService,
        currency: _currencyFormat,
        combinedTotal: combinedTotal,
        orderCount: openOrders.length,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final settled = await _restaurantService.settleAllTableOrders(
        tableId: tableId,
        paymentStatus: result.paymentStatus,
        bookingId: result.bookingId,
        roomId: result.roomId,
      );
      if (!mounted) return;
      // Show combined invoice using openOrders (already in memory, guaranteed complete)
      await showDialog(
        context: context,
        builder: (_) => RestaurantInvoiceDialog(
          order: openOrders.first,
          table: table,
          allOrders: openOrders.length > 1 ? openOrders : null,
        ),
      );
      setState(() {
        _selectedTableId = null;
        _isLoading = false;
      });
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Adds all cart items to the existing pending tab (append to same order).
  Future<void> _addCartToTab() async {
    final orders = _allTableOrders[_selectedTableId!];
    if (orders == null || orders.isEmpty || _cart.isEmpty) return;
    final pendingOrder = orders.lastWhere(
      (o) => o.status == OrderStatus.pending,
      orElse: () => orders.last,
    );
    setState(() => _isLoading = true);
    try {
      final newItems = _cart
          .map((i) => OrderItem(id: _uuid.v4(), menuItem: i.menuItem, quantity: i.quantity))
          .toList();
      await _restaurantService.addItemsToOrder(pendingOrder.id, newItems);
      setState(() {
        _cart.clear();
        _isLoading = false;
      });
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${newItems.length} item(s) added to Table ${_tables.firstWhere((t) => t.id == _selectedTableId).tableNumber} tab.'),
          backgroundColor: _kOrange,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Creates a new pending "add-on" order for the current table and sends
  /// it directly to the kitchen. Called when the existing order is in
  /// preparing/ready state.
  Future<void> _sendAddonOrder() async {
    if (_cart.isEmpty || _selectedTableId == null) return;
    setState(() => _isLoading = true);
    try {
      final tableNum = _tables
          .firstWhere((t) => t.id == _selectedTableId)
          .tableNumber;
      // Find the root parent for this table's session
      final openOrders = _allTableOrders[_selectedTableId!] ?? [];
      final rootParent = openOrders.firstOrNull;
      final parentId =
          rootParent?.parentOrderId ?? rootParent?.id; // always link to root

      final order = RestaurantOrder(
        id: _uuid.v4(),
        orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        tableId: _selectedTableId,
        type: OrderType.dineIn,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now(),
        items: List.from(_cart),
        parentOrderId: parentId,
      );
      await _restaurantService.saveOrder(order);
      setState(() {
        _cart.clear();
        _isLoading = false;
      });
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add-on order sent to kitchen for Table $tableNum.'),
          backgroundColor: const Color(0xFF0D9488),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) _showInvoiceDialog(order);
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  POS PAYMENT DIALOG  (collect payment for a payment-due tab)
// ═══════════════════════════════════════════════════════════════════════════

class _PosPaymentResult {
  final PaymentStatus paymentStatus;
  final String? bookingId;
  final String? roomId;
  const _PosPaymentResult(
      {required this.paymentStatus, this.bookingId, this.roomId});
}

class _PosPaymentDialog extends StatefulWidget {
  final RestaurantOrder displayOrder;
  final RestaurantTable table;
  final BookingService bookingService;
  final NumberFormat currency;
  final double? combinedTotal; // override when multiple orders
  final int orderCount;

  const _PosPaymentDialog({
    required this.displayOrder,
    required this.table,
    required this.bookingService,
    required this.currency,
    this.combinedTotal,
    this.orderCount = 1,
  });

  @override
  State<_PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<_PosPaymentDialog> {
  String? _method; // 'cash' | 'card' | 'room'
  List<Map<String, dynamic>> _checkedInGuests = [];
  bool _loadingGuests = false;
  Map<String, dynamic>? _selectedGuest;

  static const _kPurple = Color(0xFF8B5CF6);
  static const _kGreen = Color(0xFF22C55E);
  static const _kGreenBg = Color(0xFFF0FFF4);

  @override
  void initState() {
    super.initState();
    _loadCheckedInGuests();
  }

  Future<void> _loadCheckedInGuests() async {
    setState(() => _loadingGuests = true);
    final enriched = await widget.bookingService.getEnrichedCheckIns();
    if (!mounted) return;
    final checkedIn = enriched.where((d) {
      final booking = d['booking'] as Booking?;
      return booking != null && booking.status == BookingStatus.checkedIn;
    }).toList();
    setState(() {
      _checkedInGuests = checkedIn;
      _loadingGuests = false;
    });
  }

  bool get _canConfirm {
    if (_method == null) return false;
    if (_method == 'room' && _selectedGuest == null) return false;
    return true;
  }

  void _confirm() {
    PaymentStatus status;
    String? bookingId;
    String? roomId;
    if (_method == 'room') {
      status = PaymentStatus.chargedToRoom;
      final b = _selectedGuest!['booking'] as Booking;
      bookingId = b.id;
      roomId = b.roomId;
    } else {
      status = PaymentStatus.paid;
    }
    Navigator.pop(context,
        _PosPaymentResult(paymentStatus: status, bookingId: bookingId, roomId: roomId));
  }

  Widget _methodTile(IconData icon, String label, String value, Color color) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _method = value;
          if (value != 'room') _selectedGuest = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.black38, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.combinedTotal ?? widget.displayOrder.totalAmount;
    final tax = subtotal * 0.08;
    final total = subtotal + tax;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.payment_rounded, color: _kPurple, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Collect Payment',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                          widget.orderCount > 1
                              ? 'Table ${widget.table.tableNumber}  ·  ${widget.orderCount} orders'
                              : 'Table ${widget.table.tableNumber}  ·  Order #${widget.displayOrder.orderNumber}',
                          style: const TextStyle(fontSize: 12, color: Colors.black38)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(foregroundColor: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subtotal   ${widget.currency.format(subtotal)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Text('Tax (8%)   ${widget.currency.format(tax)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TOTAL DUE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black38)),
                        Text(widget.currency.format(total),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _kPurple)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment method
              const Text('Select payment method',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _methodTile(Icons.money_rounded, 'Cash', 'cash', Colors.green.shade600),
                  const SizedBox(width: 10),
                  _methodTile(Icons.credit_card_rounded, 'Card', 'card', Colors.blue.shade600),
                  const SizedBox(width: 10),
                  _methodTile(Icons.hotel_rounded, 'Room Charge', 'room', _kOrange),
                ],
              ),

              // Room charge — checked-in guest list
              if (_method == 'room') ...[
                const SizedBox(height: 16),
                const Text('Select checked-in guest',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _loadingGuests
                      ? const Center(child: CircularProgressIndicator())
                      : _checkedInGuests.isEmpty
                          ? const Center(
                              child: Text('No guests currently checked in',
                                  style: TextStyle(color: Colors.black38, fontSize: 13)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(6),
                              itemCount: _checkedInGuests.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = _checkedInGuests[i];
                                final booking = d['booking'] as Booking;
                                final guest = d['guest'] as Guest;
                                final room = d['room'] as Room?;
                                final isSelected = _selectedGuest == d;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedColor: _kOrange,
                                  selectedTileColor: _kOrange.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _kOrange.withOpacity(0.1),
                                    child: const Icon(Icons.person_rounded,
                                        size: 16, color: _kOrange),
                                  ),
                                  title: Text(guest.fullName,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      'Room ${room?.roomNumber ?? "N/A"}  ·  Ref: ${booking.bookingRef}',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey.shade500)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: _kOrange, size: 18)
                                      : null,
                                  onTap: () => setState(() => _selectedGuest = d),
                                );
                              },
                            ),
                ),
                if (_selectedGuest != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: _kGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Charging to: ${(_selectedGuest!['guest'] as Guest).fullName}'
                          '  ·  Room ${(_selectedGuest!['room'] as Room?)?.roomNumber ?? "—"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Confirm
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirm Payment & Close Table',
                      style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade100,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
