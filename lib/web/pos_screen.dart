import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../providers/hotel_session.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/expense.dart';
import '../models/inventory_item.dart';
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
  List<InventoryItem> _inventoryItems = [];
  String _selectedCategory = 'All';
  String _menuSearchQuery = '';
  final _menuSearchController = TextEditingController();

  List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String? _selectedTableId;
  String? _selectedBookingId;

  // Delivery fields
  String  _deliveryPlatform = 'UberEats'; // 'UberEats' | 'PickMe' | 'Other'
  final   _deliveryRefController = TextEditingController();
  static const _kDeliveryPlatforms = ['UberEats', 'PickMe', 'Other'];

  // Discount applied to the current cart before checkout
  String  _discountType   = 'percentage'; // 'percentage' | 'flat'
  double  _discountAmount = 0.0;
  final   _discountController = TextEditingController();
  bool    _showDiscount   = false; // hidden by default; revealed on tap
  bool    _mobileCartExpanded = false; // mobile cart panel open/closed

  bool _isLoading = true;
  /// All open (non-cancelled, non-paid) orders per table, sorted oldest→newest.
  Map<String, List<RestaurantOrder>> _allTableOrders = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _deliveryRefController.dispose();
    _menuSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final items = await _restaurantService.getMenuItems();
    final tables = await _restaurantService.getTables();

    // Load orders and inventory in parallel — failures should not block the menu
    List<RestaurantOrder> orders = [];
    List<InventoryItem> inventory = [];
    try {
      final results = await Future.wait([
        _restaurantService.getOrders(),
        _restaurantService.getInventory(),
      ]);
      orders    = results[0] as List<RestaurantOrder>;
      inventory = results[1] as List<InventoryItem>;
    } catch (_) {}

    if (!mounted) return;

    // Build open-order map: tableId → list of all open orders (oldest→newest).
    final allOrders = <String, List<RestaurantOrder>>{};
    for (final o in orders) {
      if (o.tableId == null) continue;
      if (o.status == OrderStatus.cancelled) continue;
      if (o.paymentStatus == PaymentStatus.paid ||
          o.paymentStatus == PaymentStatus.chargedToRoom) continue;
      // Skip fully-refunded ghost orders ($0 total, all items refunded)
      if (o.items.isNotEmpty && o.items.every((i) => i.isFullyRefunded)) continue;
      allOrders.putIfAbsent(o.tableId!, () => []).add(o);
    }
    for (final list in allOrders.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    setState(() {
      _menuItems        = items;
      _tables           = tables;
      _inventoryItems   = inventory;
      _allTableOrders   = allOrders;
      _isLoading        = false;
    });
  }

  /// Returns true if any ingredient for [item] has insufficient stock
  /// to add one more unit (accounting for what's already in the cart).
  bool _isIngredientOutOfStock(MenuItem item) {
    if (item.ingredients.isEmpty) return false;
    final cartQty = _cart.fold(0, (s, c) => c.menuItem.id == item.id ? s + c.quantity : s);
    for (final ing in item.ingredients) {
      final inv = _inventoryItems.where((i) => i.ingredientId == ing.ingredientId).firstOrNull;
      if (inv == null) continue; // no inventory tracked → skip
      final needed = ing.quantity * (cartQty + 1);
      if (inv.currentStock < needed) return true;
    }
    return false;
  }

  List<String> get _categories {
    final cats = _menuItems.map((e) => e.category).toSet().toList();
    cats.insert(0, 'All');
    return cats;
  }

  List<MenuItem> get _filteredMenu {
    var items = _selectedCategory == 'All'
        ? _menuItems
        : _menuItems.where((e) => e.category == _selectedCategory).toList();
    if (_menuSearchQuery.isNotEmpty) {
      final q = _menuSearchQuery.toLowerCase();
      items = items.where((e) => e.name.toLowerCase().contains(q)).toList();
    }
    return items;
  }

  double get _cartItemsTotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  double get _discountValue {
    if (_discountAmount <= 0) return 0.0;
    if (_discountType == 'percentage') return _cartItemsTotal * (_discountAmount / 100);
    return _discountAmount; // flat
  }

  double get _cartTotal => (_cartItemsTotal - _discountValue).clamp(0.0, double.infinity);

  int _findCartItemIndex(MenuItem item, Map<String, List<String>> mods) {
    return _cart.indexWhere((e) {
      if (e.menuItem.id != item.id) return false;
      if (e.selectedModifiers.length != mods.length) return false;
      for (final k in mods.keys) {
        if (!e.selectedModifiers.containsKey(k)) return false;
        final listA = List<String>.from(e.selectedModifiers[k]!)..sort();
        final listB = List<String>.from(mods[k]!)..sort();
        if (listA.join('|') != listB.join('|')) return false;
      }
      return true;
    });
  }

  void _addToCart(MenuItem item, {Map<String, List<String>>? selectedModifiers}) {
    if (!item.isAvailable) return;
    if (_isIngredientOutOfStock(item)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} cannot be added — ingredient stock is insufficient.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (item.modifiers.isNotEmpty && selectedModifiers == null) {
      _showModifierDialog(item);
      return;
    }

    final mods = selectedModifiers ?? {};

    setState(() {
      final idx = _findCartItemIndex(item, mods);
      if (idx >= 0) {
        _cart[idx].quantity++;
      } else {
        _cart.add(OrderItem(
          id: _uuid.v4(),
          menuItem: item,
          quantity: 1,
          selectedModifiers: mods,
        ));
      }
    });
  }

  Future<void> _showModifierDialog(MenuItem item) async {
    final Map<String, List<String>> selections = {};
    for (final mod in item.modifiers) {
      selections[mod.name] = [];
    }
    
    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool isValid = true;
          for (final mod in item.modifiers) {
            if (mod.isRequired && selections[mod.name]!.isEmpty) {
              isValid = false; break;
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Customize ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.modifiers.map((mod) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(mod.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              if (mod.isRequired)
                                const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(mod.allowMultiple ? '(Choose multiple)' : '(Choose 1)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...mod.options.map((opt) {
                            final isSelected = selections[mod.name]!.contains(opt.name);
                            final priceText = opt.priceAdjustment > 0 ? ' (+${_currencyFormat.format(opt.priceAdjustment)})' : '';
                            return InkWell(
                              onTap: () {
                                setSt(() {
                                  if (mod.allowMultiple) {
                                    if (isSelected) selections[mod.name]!.remove(opt.name);
                                    else selections[mod.name]!.add(opt.name);
                                  } else {
                                    selections[mod.name] = [opt.name];
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      mod.allowMultiple 
                                          ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                                          : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                                      color: isSelected ? _kOrange : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(opt.name + priceText, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, selections) : null,
                style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white),
                child: const Text('Add to Cart'),
              )
            ],
          );
        }
      )
    );

    if (result != null) {
      _addToCart(item, selectedModifiers: result);
    }
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

    final isDelivery = _orderType == OrderType.delivery;
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
      discountType:     _discountAmount > 0 ? _discountType : null,
      discountAmount:   _discountAmount,
      deliveryPlatform: isDelivery ? _deliveryPlatform : null,
      deliveryOrderRef: isDelivery ? _deliveryRefController.text.trim() : null,
    );

    try {
      await _restaurantService.saveOrder(order); // also deducts inventory
    } catch (e) {
      if (!mounted) return null;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
      return null;
    }

    if (paymentStatus == PaymentStatus.chargedToRoom && bookingId != null) {
      final s = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
      final tRate = s?.taxRate ?? 0.0;
      final scRate = order.type == OrderType.dineIn ? (s?.serviceChargeRate ?? 0.0) : 0.0;
      final billAmount = order.totalAmount * (1 + tRate + scRate);
      await _bookingService.addExpense(Expense(
        id: _uuid.v4(),
        description: 'Restaurant Order #${order.orderNumber}',
        amount: billAmount,
        date: DateTime.now(),
        category: ExpenseCategory.restaurant,
        isBillable: true,
        bookingId: bookingId,
        roomId: roomId,
        isPaid: false,
      ));
    }

    setState(() {
      _cart.clear();
      // Keep _selectedTableId so the next order can be placed immediately
      // for the same table (e.g. dessert after mains).
      _selectedBookingId = null;
      _discountAmount = 0.0;
      _discountController.clear();
      _deliveryRefController.clear();
      _showDiscount = false;
      _mobileCartExpanded = false;
      _isLoading = false;
    });

    return order;
  }

  Future<void> _handleCheckout(PaymentStatus status, {String? bookingId, String? roomId}) async {
    final order = await _checkout(paymentStatus: status, bookingId: bookingId, roomId: roomId);
    if (order == null || !mounted) return;
    // Show invoice and refresh table/inventory data in parallel —
    // sidebar occupancy updates while the user reviews the invoice.
    await Future.wait([
      _showInvoiceDialog(order),
      _loadData(),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${order.orderNumber} placed!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
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

  Future<void> _showInvoiceDialog(RestaurantOrder order, {List<RestaurantOrder>? allOrders}) {
    final table = order.tableId != null
        ? _tables.firstWhere((t) => t.id == order.tableId, orElse: () => RestaurantTable(id: '', tableNumber: '?', capacity: 0))
        : null;
    return showDialog(
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
    if (_isLoading) return const PosMenuSkeleton();

    final isMobile = MediaQuery.of(context).size.width < 600;

    final content = isMobile ? ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          _buildHeader(),
          _buildCategoryTabs(),
          Expanded(child: _buildMenuGrid()),
          _buildMobileCartBar(),
        ],
      ),
    ) : ColoredBox(
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

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_cart.isNotEmpty) {
              setState(() => _cart.clear());
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (_cart.isNotEmpty && canEditSection(ref, 'restaurant_pos')) {
              _handleCheckout(PaymentStatus.paid);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: content,
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
          if (MediaQuery.of(context).size.width >= 600)
            Text(DateFormat('EEEE, MMM dd').format(DateTime.now()),
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                    fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Search bar
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              controller: _menuSearchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search items…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
                suffixIcon: _menuSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => setState(() {
                          _menuSearchQuery = '';
                          _menuSearchController.clear();
                        }),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _menuSearchQuery = v.trim()),
              onSubmitted: (v) {
                final items = _filteredMenu;
                if (items.isNotEmpty) {
                  _addToCart(items.first);
                  setState(() {
                    _menuSearchQuery = '';
                    _menuSearchController.clear();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          // Category chips scrollable
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSel = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat,
                          style: TextStyle(
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13)),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: _kOrange,
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                      backgroundColor: Colors.grey.shade100,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final w = MediaQuery.of(context).size.width;
    final cols = w < 600 ? 2 : (w < 900 ? 3 : 4);
    final pad  = w < 600 ? 12.0 : 20.0;
    final gap  = w < 600 ? 10.0 : 14.0;
    return GridView.builder(
      padding: EdgeInsets.all(pad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.85,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
      ),
      itemCount: _filteredMenu.length,
      itemBuilder: (_, i) => _buildMenuTile(_filteredMenu[i]),
    );
  }

  Widget _buildMenuTile(MenuItem item) {
    final unavailable = !item.isAvailable || _isIngredientOutOfStock(item);
    final outOfStock  = item.isAvailable && _isIngredientOutOfStock(item);
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
                  Text(
                    !item.isAvailable
                        ? 'Unavailable'
                        : outOfStock
                            ? 'Out of Stock'
                            : _currencyFormat.format(item.price),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: unavailable ? Colors.red.shade400 : _kOrange,
                        fontSize: 13),
                  ),
                  if (item.modifiers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('+ Variants', style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w700)),
                      ),
                    ),
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

  // ─── MOBILE CART BAR ─────────────────────────────────────────────────────

  /// Sticky bottom panel on mobile. Collapses to a summary strip and expands
  /// to show order-type selector, cart items, totals, and checkout buttons.
  Widget _buildMobileCartBar() {
    final settings =
        pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate = settings?.taxRate ?? 0.0;
    final svcRate = _orderType == OrderType.dineIn
        ? (settings?.serviceChargeRate ?? 0.0)
        : 0.0;
    final taxValue = _cartTotal * taxRate;
    final svcValue = _cartTotal * svcRate;
    final grandTotal = _cartTotal + taxValue + svcValue;
    final hasItems = _cart.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Summary strip ──────────────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasItems
                  ? () => setState(
                      () => _mobileCartExpanded = !_mobileCartExpanded)
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 22,
                          color: hasItems ? _kOrange : Colors.grey.shade300),
                      if (hasItems)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: const BoxDecoration(
                                color: _kOrange, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${_cart.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    if (!hasItems)
                      Text('Cart is empty',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14))
                    else ...[
                      Text(
                        '${_cart.length} item${_cart.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${_currencyFormat.format(grandTotal)}',
                        style: const TextStyle(
                            color: _kOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ],
                    const Spacer(),
                    if (hasItems)
                      Icon(
                        _mobileCartExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
            ),

            // ── Expanded: order type + table + items + total ───────────
            if (_mobileCartExpanded && hasItems) ...[
              const Divider(height: 1),
              // Order type chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(children: [
                  Expanded(child: _typeBtn('Dine-in', OrderType.dineIn)),
                  const SizedBox(width: 6),
                  Expanded(child: _typeBtn('Takeaway', OrderType.takeaway)),
                  const SizedBox(width: 6),
                  Expanded(child: _typeBtn('Delivery', OrderType.delivery)),
                ]),
              ),
              // Delivery panel
              if (_orderType == OrderType.delivery)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _buildDeliveryPanel(),
                ),
              // Table selector (dine-in only)
              if (_orderType == OrderType.dineIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Table',
                      prefixIcon: const Icon(Icons.table_restaurant_rounded,
                          size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    value: _selectedTableId,
                    items: _tables
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                  'Table ${t.tableNumber} (${t.capacity} pax)'),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedTableId = val),
                  ),
                ),
              const Divider(height: 1),
              // Cart items (scrollable, capped height)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 1),
                  itemCount: _cart.length,
                  itemBuilder: (_, i) => _buildCartItem(_cart[i], i),
                ),
              ),
              // Totals
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    if (taxRate > 0)
                      _mobileRow('Tax (${(taxRate * 100).toStringAsFixed(0)}%)',
                          _currencyFormat.format(taxValue)),
                    if (svcRate > 0)
                      _mobileRow(
                          'Service (${(svcRate * 100).toStringAsFixed(0)}%)',
                          _currencyFormat.format(svcValue)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          _currencyFormat.format(grandTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: _kOrange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            // ── Checkout buttons ───────────────────────────────────────
            if (hasItems)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: !canEditSection(ref, 'restaurant_pos')
                          ? null
                          : () => _handleCheckout(PaymentStatus.paid),
                      icon: const Icon(Icons.attach_money_rounded, size: 16),
                      label: Text(
                        'Cash  •  ${_currencyFormat.format(grandTotal)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: _showChargeToRoomDialog,
                      icon: const Icon(Icons.hotel_rounded, size: 14),
                      label: const Text('Room',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warning,
                        side: BorderSide(color: AppTheme.warning),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Text(value,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Container(
                  key: ValueKey(_cart.length),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cart.isEmpty
                        ? Colors.grey.shade100
                        : _kOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cart.isEmpty ? 'Empty' : '${_cart.length} items',
                    style: TextStyle(
                      color: _cart.isEmpty ? Colors.grey.shade400 : _kOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _typeBtn('Dine-in', OrderType.dineIn)),
              const SizedBox(width: 6),
              Expanded(child: _typeBtn('Takeaway', OrderType.takeaway)),
              const SizedBox(width: 6),
              Expanded(child: _typeBtn('Delivery', OrderType.delivery)),
            ],
          ),
          if (_orderType == OrderType.delivery) ...[
            const SizedBox(height: 12),
            _buildDeliveryPanel(),
          ],
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
    final icon = switch (type) {
      OrderType.dineIn   => Icons.table_restaurant_rounded,
      OrderType.takeaway => Icons.takeout_dining_rounded,
      OrderType.delivery => Icons.delivery_dining_rounded,
      _                  => Icons.receipt_rounded,
    };
    return ElevatedButton.icon(
      onPressed: () => setState(() {
        _orderType = type;
        if (type != OrderType.dineIn) _selectedTableId = null;
      }),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: sel ? _kOrange : Colors.grey.shade100,
        foregroundColor: sel ? Colors.white : Colors.black54,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDeliveryPanel() {
    const _kUber   = Color(0xFF06C167); // Uber Eats green
    const _kPickMe = Color(0xFFFF6B35); // PickMe orange
    const _kOther  = Color(0xFF6B7280); // grey

    Color platformColor(String p) => switch (p) {
      'UberEats' => _kUber,
      'PickMe'   => _kPickMe,
      _          => _kOther,
    };

    IconData platformIcon(String p) => switch (p) {
      'UberEats' => Icons.delivery_dining_rounded,
      'PickMe'   => Icons.two_wheeler_rounded,
      _          => Icons.storefront_rounded,
    };

    final color = platformColor(_deliveryPlatform);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform picker
          Row(children: [
            Icon(Icons.storefront_rounded, size: 13, color: color),
            const SizedBox(width: 6),
            Text('Platform', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: color)),
          ]),
          const SizedBox(height: 8),
          Row(children: _kDeliveryPlatforms.map((p) {
            final sel = _deliveryPlatform == p;
            final c   = platformColor(p);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: p != _kDeliveryPlatforms.last ? 6 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _deliveryPlatform = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? c : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? c : Colors.grey.shade200, width: sel ? 2 : 1),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(platformIcon(p), size: 18,
                          color: sel ? Colors.white : c),
                      const SizedBox(height: 3),
                      Text(p, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : c)),
                    ]),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 10),
          // Order reference
          Row(children: [
            Icon(Icons.tag_rounded, size: 13, color: color),
            const SizedBox(width: 6),
            Text('Order Reference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 4),
            Text('(optional)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _deliveryRefController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. #4829 from app',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color.withOpacity(0.3))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color.withOpacity(0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color, width: 1.5)),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(OrderItem item, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.menuItem.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      InkWell(
                        onTap: () => _editItemNoteDialog(item, index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.edit_note_rounded, size: 16, color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                  Text(_currencyFormat.format(item.unitPrice),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  if (item.selectedModifiers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.selectedModifiers.entries
                            .where((e) => e.value.isNotEmpty)
                            .map((e) => e.value.join(", "))
                            .join(' · '),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            Text(_currencyFormat.format(item.subtotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        if (item.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 34),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 12, color: _kOrange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(item.notes,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editItemNoteDialog(OrderItem item, int index) async {
    final noteCtrl = TextEditingController(text: item.notes);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Special Instructions', style: TextStyle(fontSize: 18)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: noteCtrl,
            maxLines: 2,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. No onions, extra spicy...',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => Navigator.pop(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save'),
          ),
        ],
      )
    );

    if (!mounted) return;
    setState(() {
      _cart[index].notes = noteCtrl.text.trim();
    });
  }

  Widget _buildCartFooter() {
    final settings = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate  = settings?.taxRate ?? 0.0;
    final svcRate  = _orderType == OrderType.dineIn ? (settings?.serviceChargeRate ?? 0.0) : 0.0;
    // Delivery orders: no service charge (same as takeaway)
    final taxValue = _cartTotal * taxRate;
    final svcValue = _cartTotal * svcRate;
    final grandTotal = _cartTotal + taxValue + svcValue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          // ── Discount row — hidden until tapped ───────────────────────
          if (_cart.isNotEmpty) ...[
            if (!_showDiscount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showDiscount = true),
                  icon: Icon(Icons.local_offer_outlined,
                      size: 13, color: Colors.grey.shade500),
                  label: Text('Add Discount',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              )
            else ...[
              Row(children: [
                // Type toggle: % / flat
                _DiscountTypeToggle(
                  selected: _discountType,
                  onChanged: (t) => setState(() {
                    _discountType = t;
                    final raw = double.tryParse(_discountController.text.trim()) ?? 0.0;
                    _discountAmount = t == 'percentage'
                        ? raw.clamp(0.0, 100.0)
                        : raw.clamp(0.0, _cartItemsTotal);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _discountController,
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
                        _discountAmount = _discountType == 'percentage'
                            ? raw.clamp(0.0, 100.0)
                            : raw.clamp(0.0, _cartItemsTotal);
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18,
                      color: _discountAmount > 0 ? Colors.red : Colors.grey.shade400),
                  tooltip: 'Hide discount',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() {
                    _discountAmount = 0.0;
                    _discountController.clear();
                    _showDiscount = false;
                  }),
                ),
              ]),
              const SizedBox(height: 10),
            ],
          ],

          // ── Subtotal / Discount / Total rows ─────────────────────────
          if (_discountAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                Text(_currencyFormat.format(_cartItemsTotal),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _discountType == 'percentage'
                      ? 'Discount (${_discountAmount.toStringAsFixed(0)}%)'
                      : 'Discount',
                  style: const TextStyle(fontSize: 13, color: Colors.green),
                ),
                Text('− ${_currencyFormat.format(_discountValue)}',
                    style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 12),
          ],
          if (taxRate > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax (${(taxRate * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                Text(_currencyFormat.format(taxValue),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (svcRate > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Service (${(svcRate * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                Text(_currencyFormat.format(svcValue),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              Text(_currencyFormat.format(grandTotal),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kOrange)),
            ],
          ),
          const SizedBox(height: 14),
          // Delivery badge (shown when delivery mode active)
          if (_orderType == OrderType.delivery)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _deliveryRefController,
              builder: (_, val, __) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF06C167).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF06C167).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.delivery_dining_rounded,
                      size: 15, color: Color(0xFF06C167)),
                  const SizedBox(width: 8),
                  Text(_deliveryPlatform,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFF06C167))),
                  if (val.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('· Ref: ${val.text.trim()}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  ],
                ]),
              ),
            ),
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
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: _cart.isEmpty ? 0 : 2,
                    shadowColor: AppTheme.success.withOpacity(0.4),
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
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: _cart.isEmpty ? 0 : 2,
                    shadowColor: const Color(0xFF0EA5E9).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          // ── Send to Kitchen (Dine-In) ──
          Builder(builder: (_) {
            if (_orderType != OrderType.dineIn || _selectedTableId == null) {
              return const SizedBox.shrink();
            }
            final openOrders = _allTableOrders[_selectedTableId!];
            final hasOpenOrders = openOrders != null && openOrders.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _sendDineInOrderToKitchen,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _cart.isEmpty
                        ? (hasOpenOrders ? 'Add items then Send to Kitchen' : 'Select items to Send to Kitchen')
                        : (hasOpenOrders ? 'Send Add-On to Kitchen  ·  ${_currencyFormat.format(grandTotal)}' : 'Send to Kitchen  ·  ${_currencyFormat.format(grandTotal)}'),
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
                      discountType:   _discountAmount > 0 ? _discountType : null,
                      discountAmount: _discountAmount,
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
                    onPressed: _sendDineInOrderToKitchen,
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
    // itemsTotal = sum of each order's items before individual discounts
    final itemsTotal = openOrders.fold(0.0, (s, o) => s + o.itemsTotal);

    final settings = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate           = settings?.taxRate           ?? 0.0;
    final serviceChargeRate = settings?.serviceChargeRate ?? 0.0;

    final result = await showDialog<_PosPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PosPaymentDialog(
        displayOrder: openOrders.last,
        table: table,
        bookingService: _bookingService,
        currency: _currencyFormat,
        itemsTotal: itemsTotal,
        taxRate: taxRate,
        serviceChargeRate: serviceChargeRate,
        orderCount: openOrders.length,
        roomNumber: openOrders.last.roomNumber,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      // Apply discount to the first (parent) order before settling
      if (result.discountAmount > 0 || result.discountType != null) {
        await _restaurantService.updateOrderDiscount(
          orderId:        openOrders.first.id,
          discountType:   result.discountType,
          discountAmount: result.discountAmount,
        );
      }
      await _restaurantService.settleAllTableOrders(
        tableId: tableId,
        paymentStatus: result.paymentStatus,
        bookingId: result.bookingId,
        roomId: result.roomId,
      );
      if (!mounted) return;
      // Build updated orders list — first order carries the discount
      final updatedFirst = openOrders.first.copyWith(
        discountType:   result.discountType,
        discountAmount: result.discountAmount,
      );
      final updatedOrders = [updatedFirst, ...openOrders.skip(1)];
      // Show combined invoice
      await showDialog(
        context: context,
        builder: (_) => RestaurantInvoiceDialog(
          order: updatedOrders.first,
          table: table,
          allOrders: updatedOrders.length > 1 ? updatedOrders : null,
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

  /// Creates a new pending order for the current table and sends
  /// it directly to the kitchen.
  Future<void> _sendDineInOrderToKitchen() async {
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
          content: Text(openOrders.isEmpty 
              ? 'Order sent to kitchen for Table $tableNum.'
              : 'Add-on order sent to kitchen for Table $tableNum.'),
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
  final String? discountType;
  final double discountAmount;
  const _PosPaymentResult({
    required this.paymentStatus,
    this.bookingId,
    this.roomId,
    this.discountType,
    this.discountAmount = 0.0,
  });
}

class _PosPaymentDialog extends StatefulWidget {
  final RestaurantOrder displayOrder;
  final RestaurantTable table;
  final BookingService bookingService;
  final NumberFormat currency;
  final double itemsTotal; // pre-discount total from all open orders
  final double taxRate;
  final double serviceChargeRate;
  final int orderCount;
  /// For room service orders: the room number the order came from.
  /// When set, the Room Charge guest list is pre-filtered to that room.
  final String? roomNumber;

  const _PosPaymentDialog({
    required this.displayOrder,
    required this.table,
    required this.bookingService,
    required this.currency,
    required this.itemsTotal,
    required this.taxRate,
    required this.serviceChargeRate,
    this.orderCount = 1,
    this.roomNumber,
  });

  @override
  State<_PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<_PosPaymentDialog> {
  String? _method; // 'cash' | 'card' | 'room'
  List<Map<String, dynamic>> _checkedInGuests = [];
  bool _loadingGuests = false;
  Map<String, dynamic>? _selectedGuest;

  String _discountType   = 'percentage';
  double _discountAmount = 0.0;
  final  _discountController = TextEditingController();

  static const _kPurple = Color(0xFF8B5CF6);
  static const _kGreen = Color(0xFF22C55E);
  static const _kGreenBg = Color(0xFFF0FFF4);

  double get _discountValue {
    if (_discountAmount <= 0) return 0.0;
    if (_discountType == 'percentage') return widget.itemsTotal * (_discountAmount / 100);
    return _discountAmount;
  }
  double get _subtotal => (widget.itemsTotal - _discountValue).clamp(0.0, double.infinity);
  double get _tax => _subtotal * widget.taxRate;
  double get _serviceCharge => _subtotal * widget.serviceChargeRate;
  double get _total => _subtotal + _tax + _serviceCharge;

  @override
  void initState() {
    super.initState();
    _loadCheckedInGuests();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckedInGuests() async {
    setState(() => _loadingGuests = true);
    final enriched = await widget.bookingService.getEnrichedCheckIns();
    if (!mounted) return;
    final checkedIn = enriched.where((d) {
      final booking = d['booking'] as Booking?;
      return booking != null && booking.status == BookingStatus.checkedIn;
    }).toList();

    // For room service orders, auto-select the guest from the originating room.
    Map<String, dynamic>? autoSelected;
    if (widget.roomNumber != null) {
      autoSelected = checkedIn.firstWhere(
        (d) => (d['room'] as Room?)?.roomNumber == widget.roomNumber,
        orElse: () => <String, dynamic>{},
      );
      if (autoSelected.isEmpty) autoSelected = null;
    }

    setState(() {
      _checkedInGuests = checkedIn;
      _loadingGuests = false;
      if (autoSelected != null) _selectedGuest = autoSelected;
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
    Navigator.pop(context, _PosPaymentResult(
      paymentStatus: status,
      bookingId: bookingId,
      roomId: roomId,
      discountType:   _discountAmount > 0 ? _discountType : null,
      discountAmount: _discountAmount,
    ));
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

              // ── Discount row ──────────────────────────────────────────────
              Row(
                children: [
                  _DiscountTypeToggle(
                    selected: _discountType,
                    onChanged: (t) => setState(() {
                      _discountType   = t;
                      final raw = double.tryParse(_discountController.text.trim()) ?? 0.0;
                      _discountAmount = t == 'percentage'
                          ? raw.clamp(0.0, 100.0)
                          : raw.clamp(0.0, widget.itemsTotal);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
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
                        _discountAmount = _discountType == 'percentage'
                            ? raw.clamp(0.0, 100.0)
                            : raw.clamp(0.0, widget.itemsTotal);
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
                        _discountController.clear();
                      }),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

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
                        Text('Items   ${widget.currency.format(widget.itemsTotal)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (_discountAmount > 0)
                          Text(
                            _discountType == 'percentage'
                                ? 'Discount (${_discountAmount.toStringAsFixed(0)}%)   − ${widget.currency.format(_discountValue)}'
                                : 'Discount   − ${widget.currency.format(_discountValue)}',
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        Text(
                          'Tax (${(widget.taxRate * 100).toStringAsFixed(0)}%)   ${widget.currency.format(_tax)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (widget.serviceChargeRate > 0)
                          Text(
                            'Service (${(widget.serviceChargeRate * 100).toStringAsFixed(0)}%)   ${widget.currency.format(_serviceCharge)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
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
                        Text(widget.currency.format(_total),
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
                // Room service origin banner
                if (widget.roomNumber != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedGuest != null
                          ? const Color(0xFFF0FFF4)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedGuest != null
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedGuest != null
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          size: 14,
                          color: _selectedGuest != null
                              ? Colors.green.shade600
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedGuest != null
                              ? 'Order from Room ${widget.roomNumber} — guest auto-selected'
                              : 'Order from Room ${widget.roomNumber} — no guest checked in to this room',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedGuest != null
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text('Select checked-in guest',
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

// ── Discount type toggle (%  /  flat) ────────────────────────────────────────

class _DiscountTypeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _DiscountTypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn('%',    'percentage'),
        _btn('Flat', 'flat'),
      ]),
    );
  }

  Widget _btn(String label, String value) {
    final active = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _kOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
