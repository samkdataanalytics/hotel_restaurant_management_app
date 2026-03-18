import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/expense.dart';
import '../services/restaurant_service.dart';
import '../services/booking_service.dart';

// ─── Restaurant brand colors — sourced from AppTheme ─────────────────────────
const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _restaurantService = RestaurantService();
  final _bookingService = BookingService();
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _uuid = const Uuid();

  List<MenuItem> _menuItems = [];
  List<RestaurantTable> _tables = [];
  String _selectedCategory = 'All';

  List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String? _selectedTableId;
  String? _selectedBookingId;

  bool _isLoading = true;
  Map<String, RestaurantOrder> _activeTabs = {};

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

    // Build active-tab map: tableId → most-recent unpaid non-terminal order
    final tabs = <String, RestaurantOrder>{};
    for (final o in orders) {
      if (o.tableId == null) continue;
      if (o.status == OrderStatus.cancelled || o.status == OrderStatus.served) continue;
      if (o.paymentStatus == PaymentStatus.paid ||
          o.paymentStatus == PaymentStatus.chargedToRoom) continue;
      final existing = tabs[o.tableId!];
      if (existing == null || o.createdAt.isAfter(existing.createdAt)) {
        tabs[o.tableId!] = o;
      }
    }

    setState(() {
      _menuItems = items;
      _tables = tables;
      _activeTabs = tabs;
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

  void _showInvoiceDialog(RestaurantOrder order) {
    final table = order.tableId != null
        ? _tables.firstWhere((t) => t.id == order.tableId, orElse: () => RestaurantTable(id: '', tableNumber: '?', capacity: 0))
        : null;
    showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(order: order, table: table),
    );
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
      onTap: unavailable ? null : () => _addToCart(item),
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
                final hasTab = _activeTabs.containsKey(t.id);
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
                _activeTabs.containsKey(_selectedTableId!))
              _buildActiveTabBanner(_activeTabs[_selectedTableId!]!),
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
                  onPressed: _cart.isEmpty ? null : () => _handleCheckout(PaymentStatus.paid),
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
                  onPressed: _cart.isEmpty ? null : () => _handleCheckout(PaymentStatus.paid),
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

  /// Banner shown below the table dropdown when the selected table already
  /// has a running tab (opened from the Tables screen).
  Widget _buildActiveTabBanner(RestaurantOrder tab) {
    final table = _tables.firstWhere((t) => t.id == tab.tableId,
        orElse: () => RestaurantTable(id: '', tableNumber: '?', capacity: 0));
    final itemCount = tab.items.fold(0, (s, i) => s + i.activeQuantity);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kOrange.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 14, color: _kOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Active tab — $itemCount item(s)  ·  '
                  '${_currencyFormat.format(tab.totalAmount)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kOrange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showInvoiceDialog(tab),
                icon: const Icon(Icons.receipt_outlined, size: 13),
                label: const Text('View Invoice',
                    style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kOrange,
                  side: const BorderSide(color: _kOrange),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
              ),
              const SizedBox(width: 8),
              if (_cart.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _addCartToTab,
                  icon: const Icon(Icons.playlist_add_rounded, size: 13),
                  label: const Text('Add Cart to Tab',
                      style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adds all cart items to an existing table tab then clears the cart.
  Future<void> _addCartToTab() async {
    final tab = _activeTabs[_selectedTableId!];
    if (tab == null || _cart.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final newItems = _cart
          .map((i) => OrderItem(id: _uuid.v4(), menuItem: i.menuItem, quantity: i.quantity))
          .toList();
      await _restaurantService.addItemsToOrder(tab.id, newItems);
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
}

// ═══════════════════════════════════════════════════════════════════════════
//  INVOICE DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class RestaurantInvoiceDialog extends StatelessWidget {
  final RestaurantOrder order;
  final RestaurantTable? table;

  const RestaurantInvoiceDialog({super.key, required this.order, this.table});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateF = DateFormat('MMM dd, yyyy  HH:mm');
    final isPreview = order.id == 'preview';
    final subtotal = order.totalAmount;
    const taxRate = 0.08; // 8%
    final tax = subtotal * taxRate;
    final grandTotal = subtotal + tax;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─ Header buttons bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 16, color: _kOrange),
                  const SizedBox(width: 8),
                  Text(isPreview ? 'Invoice Preview' : 'Invoice',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(foregroundColor: Colors.black45),
                  ),
                ],
              ),
            ),

            // ─ Invoice body (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: _kOrangeBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.restaurant_rounded, color: _kOrange, size: 28),
                          ),
                          const SizedBox(height: 10),
                          const Text('Grand Luxe Restaurant',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('123 Luxury Ave • Tel: +1 (555) 000-1234',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Invoice meta
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _meta('Order #', isPreview ? '—' : order.orderNumber)),
                          Expanded(child: _meta('Date', dateF.format(order.createdAt))),
                          if (table != null)
                            Expanded(child: _meta('Table', table!.tableNumber)),
                          Expanded(child: _meta('Type', order.type == OrderType.dineIn ? 'Dine-in' : 'Takeaway')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items header
                    Row(
                      children: [
                        Expanded(flex: 4, child: _colHdr('Item')),
                        Expanded(child: _colHdr('Qty', align: TextAlign.center)),
                        Expanded(child: _colHdr('Price', align: TextAlign.end)),
                        Expanded(child: _colHdr('Total', align: TextAlign.end)),
                      ],
                    ),
                    const Divider(thickness: 1.5),

                    // Items (skip fully-refunded lines; show active qty only)
                    ...order.items
                        .where((item) => !item.isFullyRefunded)
                        .map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Text(
                                            item.menuItem.imageUrl.isNotEmpty
                                                ? item.menuItem.imageUrl
                                                : '🍽️',
                                            style: const TextStyle(
                                                fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.menuItem.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13)),
                                              if (item.refundedQuantity > 0)
                                                Text(
                                                  '${item.refundedQuantity} unit(s) refunded',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .orange.shade600),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                        '${item.activeQuantity}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        currency
                                            .format(item.menuItem.price),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        currency.format(item.subtotal),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            )),

                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),

                    // Totals
                    _totalRow('Subtotal', currency.format(subtotal)),
                    const SizedBox(height: 4),
                    _totalRow('Tax (8%)', currency.format(tax), muted: true),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kOrangeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GRAND TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(currency.format(grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _kOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Payment status
                    if (!isPreview)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _paymentColor(order.paymentStatus).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_paymentLabel(order.paymentStatus),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _paymentColor(order.paymentStatus),
                                  fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Thank you for dining with us!',
                          style: TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),

            // ─ Footer action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isPreview)
                    Text('Order #${order.orderNumber}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _colHdr(String text, {TextAlign align = TextAlign.start}) {
    return Text(text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5));
  }

  Widget _totalRow(String label, String value, {bool muted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: muted ? Colors.black38 : Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                color: muted ? Colors.black38 : Colors.black87)),
      ],
    );
  }

  Color _paymentColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid: return const Color(0xFF22C55E);
      case PaymentStatus.chargedToRoom: return const Color(0xFFF59E0B);
      case PaymentStatus.unpaid: return const Color(0xFFEF4444);
    }
  }

  String _paymentLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid: return 'PAID';
      case PaymentStatus.chargedToRoom: return 'CHARGED TO ROOM';
      case PaymentStatus.unpaid: return 'UNPAID';
    }
  }
}
