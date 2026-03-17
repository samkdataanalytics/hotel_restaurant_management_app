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

  // Current Cart State
  List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String? _selectedTableId;
  String? _selectedBookingId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await _restaurantService.getMenuItems();
    final tables = await _restaurantService.getTables();
    if (!mounted) return;
    setState(() {
      _menuItems = items;
      _tables = tables;
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

  double get _cartTotal {
    return _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  void _addToCart(MenuItem item) {
    setState(() {
      final existingIndex = _cart.indexWhere((e) => e.menuItem.id == item.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(OrderItem(id: _uuid.v4(), menuItem: item, quantity: 1));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
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

  Future<void> _checkout({required PaymentStatus paymentStatus, String? bookingId}) async {
    if (_cart.isEmpty) return;
    if (_orderType == OrderType.dineIn && _selectedTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a table for Dine-in orders.')));
      return;
    }

    setState(() => _isLoading = true);

    // 1. Create Order
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

    await _restaurantService.saveOrder(order);

    // 2. If charged to room, inject Expense into the Hotel Bookings
    if (paymentStatus == PaymentStatus.chargedToRoom && bookingId != null) {
      final expense = Expense(
        id: _uuid.v4(),
        description: 'Restaurant Order #${order.orderNumber}',
        amount: order.totalAmount,
        date: DateTime.now(),
        category: ExpenseCategory.restaurant,
        isBillable: true,
        bookingId: bookingId,
        isPaid: false, // Wait until final checkout to clear balance
      );
      await _bookingService.addExpense(expense);
    }

    setState(() {
      _cart.clear();
      _selectedTableId = null;
      _selectedBookingId = null;
      _isLoading = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order #${order.orderNumber} placed successfully!'), backgroundColor: AppTheme.success));
  }

  Future<void> _showChargeToRoomDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Only load Active guests (checked-in)
    final enrichedBookings = await _bookingService.getEnrichedBookings();
    final activeBookings = enrichedBookings.where((data) => (data['booking'] as Booking).status == BookingStatus.checkedIn).toList();
    
    if (!mounted) return;
    Navigator.pop(context); // close loader

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Charge to Room'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: activeBookings.isEmpty
                ? const Center(child: Text('No checked-in guests found.'))
                : ListView.builder(
                    itemCount: activeBookings.length,
                    itemBuilder: (context, i) {
                      final b = activeBookings[i]['booking'] as Booking;
                      final g = activeBookings[i]['guest'] as Guest;
                      final r = activeBookings[i]['room'] as dynamic; // Can be Room obj
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: AppTheme.adminPrimary.withOpacity(0.1), child: Icon(Icons.bed, color: AppTheme.adminPrimary)),
                        title: Text(g.fullName),
                        subtitle: Text('Room: ${r?.roomNumber ?? "N/A"} | Ref: ${b.bookingRef}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _checkout(paymentStatus: PaymentStatus.chargedToRoom, bookingId: b.id);
                          },
                          child: const Text('Charge'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // ─── LEFT: MENU GRID ───
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryTabs(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredMenu.length,
                    itemBuilder: (context, i) {
                      final item = _filteredMenu[i];
                      return _buildMenuItemTile(item);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // ─── RIGHT: CART ───
          Container(
            width: 380,
            color: Colors.white,
            child: Column(
              children: [
                _buildCartHeader(),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.black38, fontSize: 16)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          separatorBuilder: (context, i) => Divider(color: Colors.grey.shade200),
                          itemCount: _cart.length,
                          itemBuilder: (context, i) => _buildCartItem(_cart[i], i),
                        ),
                ),
                _buildCartFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Restaurant POS', style: Theme.of(context).textTheme.displayMedium),
          Text(DateFormat('EEEE, MMM dd').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 10, bottom: 10),
            child: ChoiceChip(
              label: Text(cat, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: AppTheme.adminPrimary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.grey.shade100,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemTile(MenuItem item) {
    return InkWell(
      onTap: () => _addToCart(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(item.imageUrl, style: const TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_currencyFormat.format(item.price), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.adminPrimary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.adminPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('#${_cart.length} Items', style: TextStyle(color: AppTheme.adminPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Order Type Toggle
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _orderType = OrderType.dineIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orderType == OrderType.dineIn ? AppTheme.adminPrimary : Colors.grey.shade100,
                    foregroundColor: _orderType == OrderType.dineIn ? Colors.white : Colors.black87,
                    elevation: 0,
                  ),
                  child: const Text('Dine-in'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _orderType = OrderType.takeaway;
                    _selectedTableId = null;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orderType == OrderType.takeaway ? AppTheme.adminPrimary : Colors.grey.shade100,
                    foregroundColor: _orderType == OrderType.takeaway ? Colors.white : Colors.black87,
                    elevation: 0,
                  ),
                  child: const Text('Takeaway'),
                ),
              ),
            ],
          ),
          if (_orderType == OrderType.dineIn) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Table',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: _selectedTableId,
              items: _tables.map((t) => DropdownMenuItem(value: t.id, child: Text('Table ${t.tableNumber} (${t.capacity} pax)'))).toList(),
              onChanged: (val) => setState(() => _selectedTableId = val),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCartItem(OrderItem item, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Qty controls
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              InkWell(onTap: () => _updateQuantity(index, 1), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 16))),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
              InkWell(onTap: () => _updateQuantity(index, -1), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 16))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.menuItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_currencyFormat.format(item.menuItem.price), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        Text(_currencyFormat.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
              Text(_currencyFormat.format(_cartTotal), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.adminPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : () => _checkout(paymentStatus: PaymentStatus.paid),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Pay Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _showChargeToRoomDialog,
                  icon: const Icon(Icons.hotel_rounded),
                  label: const Text('Room Charge'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.warning, // Or secondary color
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
