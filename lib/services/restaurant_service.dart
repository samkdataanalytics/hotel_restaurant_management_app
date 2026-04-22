import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/ingredient.dart';
import '../models/ingredient_price.dart';
import '../models/menu_item_cost_record.dart';
import '../models/inventory_item.dart';
import '../models/expense.dart';
import 'booking_service.dart';

SupabaseClient get _db => Supabase.instance.client;

class RestaurantService {
  final _uuid = const Uuid();
  final _bookingService = BookingService();

  static final RestaurantService _instance = RestaurantService._internal();
  factory RestaurantService() => _instance;
  RestaurantService._internal();

  /// The hotel_id for the currently logged-in staff member.
  /// Set this after login alongside BookingService.hotelId.
  String? hotelId;

  /// No-op: data is now persisted in Supabase, no local init required.
  Future<void> init() async {}

  // ─── Row → Model mappers ───────────────────────────────────────────────────

  static MenuItem _menuItemFromRow(Map<String, dynamic> r) => MenuItem.fromMap({
        'id': r['id'],
        'name': r['name'],
        'description': r['description'] ?? '',
        'price': r['price'],
        'category': r['category'] ?? 'Uncategorized',
        'imageUrl': r['image_url'] ?? '',
        'isAvailable': r['is_available'] ?? true,
        'ingredients': r['ingredients'] ?? [],
        'modifiers': r['modifiers'] ?? [],
      });

  Map<String, dynamic> _menuItemToRow(MenuItem item) => {
        'id': item.id,
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'category': item.category,
        'image_url': item.imageUrl,
        'is_available': item.isAvailable,
        'ingredients': item.ingredients.map((e) => e.toMap()).toList(),
        'modifiers': item.modifiers.map((e) => e.toMap()).toList(),
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static RestaurantTable _tableFromRow(Map<String, dynamic> r) =>
      RestaurantTable.fromMap({
        'id': r['id'],
        'tableNumber': r['table_number'],
        'capacity': r['capacity'],
        'status': r['status'] ?? 'available',
      });

  Map<String, dynamic> _tableToRow(RestaurantTable t) => {
        'id': t.id,
        'table_number': t.tableNumber,
        'capacity': t.capacity,
        'status': t.status.name,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  /// Converts a Supabase TIMESTAMPTZ string to a local [DateTime].
  ///
  /// The app saves `DateTime.now()` (local time) via `toIso8601String()` which
  /// omits timezone info → Supabase stores it as UTC. On read-back the "+00:00"
  /// suffix causes `DateTime.parse` to return a UTC DateTime whose epoch is
  /// shifted by the local UTC-offset. Stripping the offset recovers the
  /// original local-time value so date-range filters in analytics work.
  static DateTime _parseLocalTimestamp(String raw) {
    final dt = DateTime.parse(raw);
    if (!dt.isUtc) return dt;
    // Re-create with the same face-value but as local time.
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute,
        dt.second, dt.millisecond, dt.microsecond);
  }

  static RestaurantOrder _orderFromRow(Map<String, dynamic> r) =>
      RestaurantOrder.fromMap({
        'id': r['id'],
        'orderNumber': r['order_number'],
        'tableId': r['table_id'],
        'type': r['type'] ?? 'dineIn',
        'status': r['status'] ?? 'pending',
        'paymentStatus': r['payment_status'] ?? 'unpaid',
        'bookingId': r['booking_id'],
        'createdAt': _parseLocalTimestamp(r['created_at'] as String)
            .toIso8601String(),
        'items': r['items'] ?? [],
        'inventoryRestored': r['inventory_restored'] ?? false,
        'parentOrderId': r['parent_order_id'],
        'discountType': r['discount_type'],
        'discountAmount': r['discount_amount'],
        'roomNumber': r['room_number'],
        'deliveryPlatform': r['delivery_platform'],
        'deliveryOrderRef': r['delivery_order_ref'],
      });

  Map<String, dynamic> _orderToRow(RestaurantOrder o) => {
        'id': o.id,
        'order_number': o.orderNumber,
        'table_id': o.tableId,
        'type': o.type.name,
        'status': o.status.name,
        'payment_status': o.paymentStatus.name,
        'booking_id': o.bookingId,
        'created_at': o.createdAt.toIso8601String(),
        'items': o.items.map((e) => e.toMap()).toList(),
        'inventory_restored': o.inventoryRestored,
        'parent_order_id': o.parentOrderId,
        'discount_type': o.discountType,
        'discount_amount': o.discountAmount,
        'room_number': o.roomNumber,
        if (o.deliveryPlatform != null) 'delivery_platform': o.deliveryPlatform,
        if (o.deliveryOrderRef != null && o.deliveryOrderRef!.isNotEmpty)
          'delivery_order_ref': o.deliveryOrderRef,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  // ─── SETTINGS ─────────────────────────────────────────────────────────────

  /// Fetches tax rate and service charge rate for the current property.
  Future<({double taxRate, double serviceChargeRate})> getChargeSettings() async {
    if (hotelId == null) return (taxRate: 0.0, serviceChargeRate: 0.0);
    final rows = await _db
        .from('hotel_settings')
        .select('tax_rate, service_charge_rate')
        .eq('hotel_id', hotelId!)
        .limit(1);
    if (rows.isEmpty) return (taxRate: 0.0, serviceChargeRate: 0.0);
    final r = rows.first;
    return (
      taxRate:           (r['tax_rate']            as num?)?.toDouble() ?? 0.0,
      serviceChargeRate: (r['service_charge_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Saves tax rate and service charge rate for the current property.
  Future<void> saveChargeSettings({
    required double taxRate,
    required double serviceChargeRate,
  }) async {
    if (hotelId == null) return;
    await _db.from('hotel_settings').upsert({
      'hotel_id':            hotelId,
      'tax_rate':            taxRate,
      'service_charge_rate': serviceChargeRate,
    }, onConflict: 'hotel_id');
  }

  static Ingredient _ingredientFromRow(Map<String, dynamic> r) =>
      Ingredient.fromMap({
        'id': r['id'],
        'name': r['name'],
        'unit': r['unit'] ?? 'kg',
      });

  Map<String, dynamic> _ingredientToRow(Ingredient i) => {
        'id': i.id,
        'name': i.name,
        'unit': i.unit,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static IngredientPrice _priceFromRow(Map<String, dynamic> r) =>
      IngredientPrice.fromMap({
        'id': r['id'],
        'ingredientId': r['ingredient_id'],
        'pricePerUnit': r['price_per_unit'],
        'date': r['date'],
        'note': r['note'],
      });

  Map<String, dynamic> _priceToRow(IngredientPrice p) => {
        'id': p.id,
        'ingredient_id': p.ingredientId,
        'price_per_unit': p.pricePerUnit,
        'date': p.date.toIso8601String(),
        'note': p.note,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static InventoryItem _inventoryFromRow(Map<String, dynamic> r) =>
      InventoryItem.fromMap({
        'ingredientId': r['ingredient_id'],
        'currentStock': r['current_stock'],
        'minStockLevel': r['min_stock_level'],
      });

  Map<String, dynamic> _inventoryToRow(InventoryItem i) => {
        'ingredient_id': i.ingredientId,
        'current_stock': i.currentStock,
        'min_stock_level': i.minStockLevel,
        'updated_at': DateTime.now().toIso8601String(),
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static MenuItemCostRecord _costRecordFromRow(Map<String, dynamic> r) =>
      MenuItemCostRecord.fromMap({
        'id': r['id'],
        'menuItemId': r['menu_item_id'],
        'cost': r['cost'],
        'date': r['date'],
      });

  // ─── Cost computation helper ───────────────────────────────────────────────

  double _computeCost(
      List<MenuItemIngredient> ingredients, List<IngredientPrice> allPrices) {
    double total = 0;
    for (final ing in ingredients) {
      final history =
          allPrices.where((p) => p.ingredientId == ing.ingredientId).toList();
      if (history.isEmpty) continue;
      history.sort((a, b) => b.date.compareTo(a.date));
      total += history.first.pricePerUnit * ing.quantity;
    }
    return total;
  }

  // ─── MENU ──────────────────────────────────────────────────────────────────

  Future<List<MenuItem>> getMenuItems() async {
    if (hotelId == null) return [];
    final rows = await _db.from('menu_items').select()
        .eq('hotel_id', hotelId!)
        .order('category')
        .order('name');
    return rows.map(_menuItemFromRow).toList();
  }

  Future<void> saveMenuItem(MenuItem item) async {
    await _db.from('menu_items').upsert(_menuItemToRow(item));
    await _recalcCostForItem(item.id);
  }

  Future<void> addMenuItem(MenuItem item) async => saveMenuItem(item);

  Future<void> deleteMenuItem(String id) async {
    await _db.from('menu_items').delete().eq('id', id);
  }

  // ─── INGREDIENTS ──────────────────────────────────────────────────────────

  Future<List<Ingredient>> getIngredients() async {
    if (hotelId == null) return [];
    final rows = await _db.from('ingredients').select()
        .eq('hotel_id', hotelId!)
        .order('name');
    return rows.map(_ingredientFromRow).toList();
  }

  Future<void> saveIngredient(Ingredient ingredient) async {
    await _db.from('ingredients').upsert(_ingredientToRow(ingredient));
  }

  Future<void> deleteIngredient(String id) async {
    await _db.from('ingredients').delete().eq('id', id);
  }

  // ─── INGREDIENT PRICES ────────────────────────────────────────────────────

  Future<List<IngredientPrice>> getIngredientPrices() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('ingredient_prices')
        .select()
        .eq('hotel_id', hotelId!)
        .order('date', ascending: false);
    return rows.map(_priceFromRow).toList();
  }

  Future<List<IngredientPrice>> getPricesForIngredient(
      String ingredientId) async {
    final rows = await _db
        .from('ingredient_prices')
        .select()
        .eq('ingredient_id', ingredientId)
        .order('date', ascending: false);
    return rows.map(_priceFromRow).toList();
  }

  Future<double?> getCurrentPriceForIngredient(String ingredientId) async {
    final history = await getPricesForIngredient(ingredientId);
    return history.isNotEmpty ? history.first.pricePerUnit : null;
  }

  /// Adds a new price record and recalculates costs for all menu items using
  /// this ingredient.
  Future<void> addIngredientPrice(IngredientPrice price) async {
    await _db.from('ingredient_prices').insert(_priceToRow(price));

    final menuItems = await getMenuItems();
    for (final item in menuItems) {
      if (item.ingredients.any((ing) => ing.ingredientId == price.ingredientId)) {
        await _recalcCostForItem(item.id);
      }
    }
  }

  Future<void> _recalcCostForItem(String menuItemId) async {
    final rows = await _db
        .from('menu_items')
        .select()
        .eq('id', menuItemId)
        .limit(1);
    if (rows.isEmpty) return;
    final item = _menuItemFromRow(rows.first);
    if (item.ingredients.isEmpty) return;

    final allPrices = await getIngredientPrices();
    final cost = _computeCost(item.ingredients, allPrices);
    if (cost <= 0) return;

    await _db.from('menu_item_cost_records').insert({
      'id': _uuid.v4(),
      'menu_item_id': menuItemId,
      'cost': cost,
      'date': DateTime.now().toIso8601String(),
      if (hotelId != null) 'hotel_id': hotelId,
    });
  }

  /// Computes the current cost for [item] live from today's ingredient prices.
  /// Always returns a fresh value — not affected by stale stored records.
  Future<double?> getComputedCostForItem(MenuItem item) async {
    if (item.ingredients.isEmpty) return null;
    final allPrices = await getIngredientPrices();
    final cost = _computeCost(item.ingredients, allPrices);
    return cost > 0 ? cost : null;
  }

  // ─── COST RECORDS ─────────────────────────────────────────────────────────

  Future<List<MenuItemCostRecord>> getCostRecordsForItem(
      String menuItemId) async {
    final rows = await _db
        .from('menu_item_cost_records')
        .select()
        .eq('menu_item_id', menuItemId)
        .order('date', ascending: false);
    return rows.map(_costRecordFromRow).toList();
  }

  Future<double?> getCurrentCostForItem(String menuItemId) async {
    final records = await getCostRecordsForItem(menuItemId);
    return records.isNotEmpty ? records.first.cost : null;
  }

  // ─── TABLES ───────────────────────────────────────────────────────────────

  Future<List<RestaurantTable>> getTables() async {
    if (hotelId == null) return [];
    final rows = await _db.from('restaurant_tables').select()
        .eq('hotel_id', hotelId!)
        .order('table_number');
    return rows.map(_tableFromRow).toList();
  }

  Future<void> saveTable(RestaurantTable table) async {
    await _db.from('restaurant_tables').upsert(_tableToRow(table));
  }

  Future<void> updateTable(RestaurantTable table) async => saveTable(table);

  Future<void> deleteTable(String id) async {
    await _db.from('restaurant_tables').delete().eq('id', id);
  }

  // ─── ORDERS ───────────────────────────────────────────────────────────────

  Future<List<RestaurantOrder>> getOrders() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('hotel_id', hotelId!)
        .order('created_at', ascending: false);
    return rows.map(_orderFromRow).toList();
  }

  /// Returns all restaurant orders that were charged to a specific hotel booking.
  Future<List<RestaurantOrder>> getChargedToRoomOrders(String bookingId) async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('hotel_id', hotelId!)
        .eq('booking_id', bookingId)
        .eq('payment_status', 'chargedToRoom')
        .neq('status', 'cancelled')
        .order('created_at', ascending: true);
    return rows.map(_orderFromRow).toList();
  }

  /// Returns the number of active kitchen orders created today.
  /// Used by AppShell badge; fetches only IDs, server-filtered.
  Future<int> countActiveKitchenOrdersToday() async {
    if (hotelId == null) return 0;
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day).toIso8601String();
      final rows  = await _db
          .from('restaurant_orders')
          .select('id')
          .eq('hotel_id', hotelId!)
          .inFilter('status', ['pending', 'preparing'])
          .gte('created_at', start);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Upserts an order and keeps table status in sync.
  /// Inventory is deducted only when the order is brand new.
  Future<void> saveOrder(RestaurantOrder order) async {
    final existing = await _db
        .from('restaurant_orders')
        .select('id')
        .eq('id', order.id)
        .limit(1);
    final isNew = existing.isEmpty;

    await _db.from('restaurant_orders').upsert(_orderToRow(order));

    // Sync table occupancy.
    // Free the table only when: cancelled OR (served + payment collected).
    if (order.tableId != null) {
      final shouldFree = order.status == OrderStatus.cancelled ||
          (order.status == OrderStatus.served &&
              (order.paymentStatus == PaymentStatus.paid ||
                  order.paymentStatus == PaymentStatus.chargedToRoom));
      await _db
          .from('restaurant_tables')
          .update({'status': shouldFree ? 'available' : 'occupied'})
          .eq('id', order.tableId!);
    }

    if (isNew) {
      await _deductInventoryForOrder(order);
    }
  }

  Future<void> _deductInventoryForOrder(RestaurantOrder order) async {
    await _deductInventoryForItems(order.items);
  }

  Future<void> _deductInventoryForItems(List<OrderItem> items) async {
    final menuItems = await getMenuItems();
    final deductions = <String, double>{}; // ingredientId → amount

    for (final orderItem in items) {
      final menuItem = menuItems.firstWhere(
        (m) => m.id == orderItem.menuItem.id,
        orElse: () => orderItem.menuItem,
      );
      for (final ing in menuItem.ingredients) {
        deductions[ing.ingredientId] =
            (deductions[ing.ingredientId] ?? 0) + ing.quantity * orderItem.quantity;
      }
    }

    if (deductions.isEmpty) return;
    await _applyInventoryDelta(deductions, subtract: true);
  }

  // ─── TABLE TAB MANAGEMENT ─────────────────────────────────────────────────

  /// Creates a new dine-in order for a table.
  /// Pass [parentOrderId] when this is an add-on to an already in-progress order.
  Future<RestaurantOrder> createTableOrder({
    required String tableId,
    required List<OrderItem> items,
    String? parentOrderId,
    OrderType type = OrderType.dineIn,
  }) async {
    final ts = DateTime.now();
    final orderNumber = ts.millisecondsSinceEpoch.toString().substring(7);
    final order = RestaurantOrder(
      id: _uuid.v4(),
      orderNumber: orderNumber,
      tableId: tableId,
      type: type,
      status: OrderStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: ts,
      items: items,
      parentOrderId: parentOrderId,
    );
    await saveOrder(order);
    return order;
  }

  /// Appends [newItems] to an existing active order and deducts inventory for
  /// the newly added items only.
  Future<RestaurantOrder> addItemsToOrder(
      String orderId, List<OrderItem> newItems) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) throw Exception('Order not found');

    final order = _orderFromRow(rows.first);
    final updatedOrder = order.copyWith(items: [...order.items, ...newItems]);

    await _db.from('restaurant_orders').update({
      'items': updatedOrder.items.map((e) => e.toMap()).toList(),
    }).eq('id', orderId);

    await _deductInventoryForItems(newItems);
    return updatedOrder;
  }

  /// Marks an order as served + paid, frees the table, and creates a
  /// room-charge expense when applicable.
  Future<RestaurantOrder> collectTablePayment({
    required String orderId,
    required PaymentStatus paymentStatus,
    String? bookingId,
    String? roomId,
  }) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) throw Exception('Order not found');
    final order = _orderFromRow(rows.first);

    final updatedOrder = order.copyWith(
      status: OrderStatus.served,
      paymentStatus: paymentStatus,
      bookingId: bookingId,
    );

    await _db.from('restaurant_orders').update({
      'status': 'served',
      'payment_status': paymentStatus.name,
      'booking_id': bookingId,
    }).eq('id', orderId);

    // Free the table
    if (order.tableId != null) {
      await _db
          .from('restaurant_tables')
          .update({'status': 'available'})
          .eq('id', order.tableId!);
    }

    // Create room-charge expense on the guest's folio
    if (paymentStatus == PaymentStatus.chargedToRoom &&
        bookingId != null &&
        roomId != null) {
      await _bookingService.addExpense(Expense(
        id: _uuid.v4(),
        description: 'Restaurant Order #${order.orderNumber}',
        amount: order.totalAmount,
        category: ExpenseCategory.restaurant,
        date: DateTime.now(),
        bookingId: bookingId,
        roomId: roomId,
        isBillable: true,
      ));
    }

    return updatedOrder;
  }

  /// Applies (or clears) a discount on a single order.
  Future<void> updateOrderDiscount({
    required String orderId,
    String? discountType,
    double discountAmount = 0.0,
  }) async {
    await _db.from('restaurant_orders').update({
      'discount_type':   discountType,
      'discount_amount': discountAmount,
    }).eq('id', orderId);
  }

  /// Returns ALL open (non-cancelled, non-paid) orders for a table, oldest first.
  Future<List<RestaurantOrder>> getOpenOrdersForTable(String tableId) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('table_id', tableId)
        .order('created_at', ascending: true);

    return rows
        .map(_orderFromRow)
        .where((o) {
          if (o.status == OrderStatus.cancelled) return false;
          if (o.paymentStatus == PaymentStatus.paid ||
              o.paymentStatus == PaymentStatus.chargedToRoom) {
            return false;
          }
          return true;
        })
        .toList();
  }

  /// Settles ALL open orders for a table at once, frees the table, and
  /// optionally creates a combined room-charge expense.
  Future<List<RestaurantOrder>> settleAllTableOrders({
    required String tableId,
    required PaymentStatus paymentStatus,
    String? bookingId,
    String? roomId,
    // Full amount including tax + service charge; falls back to sum of totalAmount
    // when not provided (for backwards compatibility with POS and other callers).
    double? finalTotal,
  }) async {
    final openOrders = await getOpenOrdersForTable(tableId);
    if (openOrders.isEmpty) return [];

    final settled = <RestaurantOrder>[];
    for (final order in openOrders) {
      await _db.from('restaurant_orders').update({
        'status': 'served',
        'payment_status': paymentStatus.name,
        'booking_id': bookingId,
      }).eq('id', order.id);
      settled.add(order.copyWith(
          status: OrderStatus.served,
          paymentStatus: paymentStatus,
          bookingId: bookingId));
    }

    // Free the table
    await _db
        .from('restaurant_tables')
        .update({'status': 'available'})
        .eq('id', tableId);

    // Create a single combined room-charge expense
    if (paymentStatus == PaymentStatus.chargedToRoom &&
        bookingId != null &&
        roomId != null) {
      final chargeAmount = finalTotal ?? openOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
      final nums = openOrders.map((o) => '#${o.orderNumber}').join(', ');
      await _bookingService.addExpense(Expense(
        id: _uuid.v4(),
        description: 'Restaurant Orders $nums',
        amount: chargeAmount,
        category: ExpenseCategory.restaurant,
        date: DateTime.now(),
        bookingId: bookingId,
        roomId: roomId,
        isBillable: true,
      ));
    }

    return settled;
  }

  /// Returns the most recent active order for a table.
  /// "Active" = not cancelled AND not (served + payment collected).
  Future<RestaurantOrder?> getActiveOrderForTable(String tableId) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('table_id', tableId)
        .order('created_at', ascending: false);

    final active = rows.map(_orderFromRow).where((o) {
      if (o.status == OrderStatus.cancelled) { return false; }
      if (o.status == OrderStatus.served &&
          (o.paymentStatus == PaymentStatus.paid ||
              o.paymentStatus == PaymentStatus.chargedToRoom)) { return false; }
      return true;
    }).toList();

    return active.isEmpty ? null : active.first;
  }

  // ─── INVENTORY ────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventory() async {
    if (hotelId == null) return [];
    final rows = await _db.from('inventory').select()
        .eq('hotel_id', hotelId!);
    return rows.map(_inventoryFromRow).toList();
  }

  Future<InventoryItem?> getInventoryForIngredient(
      String ingredientId) async {
    final rows = await _db
        .from('inventory')
        .select()
        .eq('ingredient_id', ingredientId)
        .limit(1);
    return rows.isNotEmpty ? _inventoryFromRow(rows.first) : null;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    await _db.from('inventory').upsert(_inventoryToRow(item));
  }

  /// Add or remove stock (positive delta = add, negative = remove).
  Future<void> adjustStock(String ingredientId, double delta) async {
    final inv = await getInventoryForIngredient(ingredientId);
    final current = inv?.currentStock ?? 0;
    final minLevel = inv?.minStockLevel ?? 0;
    await updateInventoryItem(InventoryItem(
      ingredientId: ingredientId,
      currentStock: (current + delta).clamp(0.0, double.infinity),
      minStockLevel: minLevel,
    ));
  }

  // ─── CANCEL & REFUND ──────────────────────────────────────────────────────

  /// Cancels an active order.
  /// Inventory is restored only when the order was still [OrderStatus.pending].
  Future<void> cancelOrder(String orderId) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) return;
    final order = _orderFromRow(rows.first);
    if (order.status == OrderStatus.cancelled) return;

    final shouldRestoreInventory = order.status == OrderStatus.pending;

    await _db.from('restaurant_orders').update({
      'status': 'cancelled',
      'inventory_restored': shouldRestoreInventory,
    }).eq('id', orderId);

    if (shouldRestoreInventory) {
      await _restoreInventoryForOrder(order);
    }

    if (order.paymentStatus == PaymentStatus.chargedToRoom &&
        order.bookingId != null) {
      await _removeRoomChargeForOrder(order);
    }

    if (order.tableId != null) {
      await _db
          .from('restaurant_tables')
          .update({'status': 'available'})
          .eq('id', order.tableId!);
    }
  }

  /// Refunds [refundQty] units of a single order item.
  Future<void> refundOrderItem(
      String orderId, String orderItemId, int refundQty) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) return;
    final order = _orderFromRow(rows.first);

    final itemIdx = order.items.indexWhere((i) => i.id == orderItemId);
    if (itemIdx == -1) return;
    final item = order.items[itemIdx];
    if (item.isFullyRefunded) return;

    final actualQty = refundQty.clamp(0, item.activeQuantity);
    if (actualQty <= 0) return;

    final newRefundedQty = item.refundedQuantity + actualQty;
    final fullyRefunded = newRefundedQty >= item.quantity;

    final updatedItems = List<OrderItem>.from(order.items);
    updatedItems[itemIdx] = item.copyWith(
      isRefunded: fullyRefunded,
      refundedQuantity: newRefundedQty,
    );

    // Check if ALL items are now fully refunded → auto-cancel the order
    final allRefunded = updatedItems.every((i) => i.isFullyRefunded);

    await _db.from('restaurant_orders').update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      if (allRefunded) 'status': 'cancelled',
    }).eq('id', orderId);

    // NOTE: Inventory is NOT restored on refunds — food was already served.

    // If fully refunded, free the table.
    if (allRefunded && order.tableId != null) {
      // Only free the table when there are no other open orders on it.
      final siblingRows = await _db
          .from('restaurant_orders')
          .select('id')
          .eq('table_id', order.tableId!)
          .neq('id', orderId)
          .neq('status', 'cancelled')
          .not('payment_status', 'in', '("paid","chargedToRoom")');
      if (siblingRows.isEmpty) {
        await _db
            .from('restaurant_tables')
            .update({'status': 'available'})
            .eq('id', order.tableId!);
      }
    }

    if (order.paymentStatus == PaymentStatus.chargedToRoom &&
        order.bookingId != null) {
      final refundAmount = item.unitPrice * actualQty;
      await _adjustRoomChargeForRefund(order, refundAmount);
    }
  }

  /// Cancels [cancelQty] units of a single item within an order.
  /// Inventory is restored only when the order is still [OrderStatus.pending].
  /// Auto-cancels the whole order if every item becomes fully cancelled.
  Future<void> cancelOrderItem(
      String orderId, String orderItemId, int cancelQty) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', orderId)
        .limit(1);
    if (rows.isEmpty) return;
    final order = _orderFromRow(rows.first);

    final itemIdx = order.items.indexWhere((i) => i.id == orderItemId);
    if (itemIdx == -1) return;
    final item = order.items[itemIdx];
    if (item.isFullyRefunded) return;

    final actualQty = cancelQty.clamp(0, item.activeQuantity);
    if (actualQty <= 0) return;

    final newRefundedQty = item.refundedQuantity + actualQty;
    final fullyRefunded = newRefundedQty >= item.quantity;

    final updatedItems = List<OrderItem>.from(order.items);
    updatedItems[itemIdx] = item.copyWith(
      isRefunded: fullyRefunded,
      refundedQuantity: newRefundedQty,
    );

    final allRefunded = updatedItems.every((i) => i.isFullyRefunded);

    await _db.from('restaurant_orders').update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      if (allRefunded) 'status': 'cancelled',
      if (allRefunded) 'inventory_restored': order.status == OrderStatus.pending,
    }).eq('id', orderId);

    // Restore inventory only when the order was still pending (not yet cooking).
    if (order.status == OrderStatus.pending) {
      final menuItems = await getMenuItems();
      final menuItem = menuItems.firstWhere(
        (m) => m.id == item.menuItem.id,
        orElse: () => item.menuItem,
      );
      final restorations = <String, double>{};
      for (final ing in menuItem.ingredients) {
        restorations[ing.ingredientId] =
            (restorations[ing.ingredientId] ?? 0) + ing.quantity * actualQty;
      }
      await _applyInventoryDelta(restorations, subtract: false);
    }

    // Free table if the whole order was auto-cancelled with no siblings.
    if (allRefunded && order.tableId != null) {
      final siblingRows = await _db
          .from('restaurant_orders')
          .select('id')
          .eq('table_id', order.tableId!)
          .neq('id', orderId)
          .neq('status', 'cancelled')
          .not('payment_status', 'in', '("paid","chargedToRoom")');
      if (siblingRows.isEmpty) {
        await _db
            .from('restaurant_tables')
            .update({'status': 'available'}).eq('id', order.tableId!);
      }
    }
  }

  // ─── Inventory helpers ────────────────────────────────────────────────────

  Future<void> _applyInventoryDelta(
    Map<String, double> deltas, {
    required bool subtract,
  }) async {
    if (deltas.isEmpty) return;

    final inventoryRows = await _db
        .from('inventory')
        .select()
        .inFilter('ingredient_id', deltas.keys.toList());

    for (final row in inventoryRows) {
      final ingredientId = row['ingredient_id'] as String;
      final currentStock = (row['current_stock'] as num).toDouble();
      final delta = deltas[ingredientId] ?? 0;
      final newStock = subtract
          ? (currentStock - delta).clamp(0.0, double.infinity)
          : currentStock + delta;

      await _db.from('inventory').update({
        'current_stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('ingredient_id', ingredientId);
    }
  }

  Future<void> _restoreInventoryForOrder(RestaurantOrder order) async {
    final menuItems = await getMenuItems();
    final restorations = <String, double>{};

    for (final orderItem in order.items) {
      final qty = orderItem.activeQuantity;
      if (qty <= 0) continue;
      final menuItem = menuItems.firstWhere(
        (m) => m.id == orderItem.menuItem.id,
        orElse: () => orderItem.menuItem,
      );
      for (final ing in menuItem.ingredients) {
        restorations[ing.ingredientId] =
            (restorations[ing.ingredientId] ?? 0) + ing.quantity * qty;
      }
    }

    await _applyInventoryDelta(restorations, subtract: false);
  }

  // ─── Room invoice sync ────────────────────────────────────────────────────

  Future<void> _removeRoomChargeForOrder(RestaurantOrder order) async {
    final expenses =
        await _bookingService.getExpensesByBookingId(order.bookingId!);
    for (final e in expenses) {
      if (e.description.contains(order.orderNumber)) {
        await _bookingService.deleteExpense(e.id);
      }
    }
  }

  Future<void> _adjustRoomChargeForRefund(
      RestaurantOrder order, double refundAmount) async {
    final expenses =
        await _bookingService.getExpensesByBookingId(order.bookingId!);

    for (final e in expenses) {
      if (!e.description.contains(order.orderNumber)) continue;

      final newAmount = e.amount - refundAmount;
      if (newAmount <= 0) {
        await _bookingService.deleteExpense(e.id);
      } else {
        await _bookingService.updateExpense(e.copyWith(
          amount: newAmount,
          description:
              'Restaurant Order #${order.orderNumber} (partial refund)',
        ));
      }
      break; // only one expense per order
    }
  }
}
