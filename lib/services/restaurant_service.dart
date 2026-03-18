import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/ingredient.dart';
import '../models/ingredient_price.dart';
import '../models/menu_item_cost_record.dart';
import '../models/inventory_item.dart';
import 'booking_service.dart';
import '../models/expense.dart';

class RestaurantService {
  final String _menuKey = 'mock_menu_data';
  final String _tablesKey = 'mock_tables_data';
  final String _ordersKey = 'mock_orders_data';
  final String _ingredientsKey = 'mock_ingredients_data';
  final String _ingredientPricesKey = 'mock_ingredient_prices_data';
  final String _costRecordsKey = 'mock_cost_records_data';
  final String _inventoryKey = 'mock_inventory_data';

  final _uuid = const Uuid();
  final _bookingService = BookingService();

  static final RestaurantService _instance = RestaurantService._internal();
  factory RestaurantService() => _instance;
  RestaurantService._internal();

  bool _isSeeded = false;

  Future<void> init() async {
    if (_isSeeded) return;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_menuKey)) {
      await _seedData(prefs);
    }
    _isSeeded = true;
  }

  Future<void> _seedData(SharedPreferences prefs) async {
    // 1. Seed Ingredients
    final ingredients = [
      Ingredient(id: 'ing1', name: 'Eggs', unit: 'piece'),
      Ingredient(id: 'ing2', name: 'English Muffin', unit: 'piece'),
      Ingredient(id: 'ing3', name: 'Avocado', unit: 'piece'),
      Ingredient(id: 'ing4', name: 'Cherry Tomatoes', unit: 'gram'),
      Ingredient(id: 'ing5', name: 'Wagyu Beef', unit: 'gram'),
      Ingredient(id: 'ing6', name: 'Truffle Mayo', unit: 'ml'),
      Ingredient(id: 'ing7', name: 'Salmon Fillet', unit: 'gram'),
      Ingredient(id: 'ing8', name: 'Asparagus', unit: 'gram'),
      Ingredient(id: 'ing9', name: 'Romaine Lettuce', unit: 'gram'),
      Ingredient(id: 'ing10', name: 'Parmesan', unit: 'gram'),
      Ingredient(id: 'ing11', name: 'Espresso Beans', unit: 'gram'),
      Ingredient(id: 'ing12', name: 'Milk', unit: 'ml'),
      Ingredient(id: 'ing13', name: 'Mango', unit: 'piece'),
      Ingredient(id: 'ing14', name: 'Chicken Breast', unit: 'gram'),
      Ingredient(id: 'ing15', name: 'Bread Loaf', unit: 'slice'),
    ];
    await prefs.setString(_ingredientsKey, json.encode(ingredients.map((e) => e.toMap()).toList()));

    // 2. Seed Ingredient Prices (historical)
    final now = DateTime.now();
    final prices = [
      IngredientPrice(id: 'ip1', ingredientId: 'ing1', pricePerUnit: 0.40, date: now.subtract(const Duration(days: 7))),
      IngredientPrice(id: 'ip2', ingredientId: 'ing1', pricePerUnit: 0.45, date: now),
      IngredientPrice(id: 'ip3', ingredientId: 'ing2', pricePerUnit: 0.80, date: now),
      IngredientPrice(id: 'ip4', ingredientId: 'ing3', pricePerUnit: 1.20, date: now.subtract(const Duration(days: 3))),
      IngredientPrice(id: 'ip5', ingredientId: 'ing3', pricePerUnit: 1.50, date: now),
      IngredientPrice(id: 'ip6', ingredientId: 'ing4', pricePerUnit: 0.02, date: now),
      IngredientPrice(id: 'ip7', ingredientId: 'ing5', pricePerUnit: 0.08, date: now),
      IngredientPrice(id: 'ip8', ingredientId: 'ing6', pricePerUnit: 0.05, date: now),
      IngredientPrice(id: 'ip9', ingredientId: 'ing7', pricePerUnit: 0.06, date: now),
      IngredientPrice(id: 'ip10', ingredientId: 'ing8', pricePerUnit: 0.03, date: now),
      IngredientPrice(id: 'ip11', ingredientId: 'ing9', pricePerUnit: 0.015, date: now),
      IngredientPrice(id: 'ip12', ingredientId: 'ing10', pricePerUnit: 0.04, date: now),
      IngredientPrice(id: 'ip13', ingredientId: 'ing11', pricePerUnit: 0.10, date: now),
      IngredientPrice(id: 'ip14', ingredientId: 'ing12', pricePerUnit: 0.003, date: now),
      IngredientPrice(id: 'ip15', ingredientId: 'ing13', pricePerUnit: 0.90, date: now),
      IngredientPrice(id: 'ip16', ingredientId: 'ing14', pricePerUnit: 0.02, date: now),
      IngredientPrice(id: 'ip17', ingredientId: 'ing15', pricePerUnit: 0.30, date: now),
    ];
    await prefs.setString(_ingredientPricesKey, json.encode(prices.map((e) => e.toMap()).toList()));

    // 3. Seed Menu Items (with ingredients)
    final menuItems = [
      MenuItem(id: 'm1', name: 'Eggs Benedict', description: 'Classic poached eggs on English muffins.', price: 14.0, category: 'Breakfast', imageUrl: '🍳',
          ingredients: [MenuItemIngredient(ingredientId: 'ing1', quantity: 2), MenuItemIngredient(ingredientId: 'ing2', quantity: 1)]),
      MenuItem(id: 'm2', name: 'Avocado Toast', description: 'Smashed avocado with cherry tomatoes.', price: 12.0, category: 'Breakfast', imageUrl: '🥑',
          ingredients: [MenuItemIngredient(ingredientId: 'ing3', quantity: 1), MenuItemIngredient(ingredientId: 'ing4', quantity: 50)]),
      MenuItem(id: 'm3', name: 'Luxe Burger', description: 'Wagyu beef patty with truffle mayo.', price: 24.0, category: 'Mains', imageUrl: '🍔',
          ingredients: [MenuItemIngredient(ingredientId: 'ing5', quantity: 180), MenuItemIngredient(ingredientId: 'ing6', quantity: 20)]),
      MenuItem(id: 'm4', name: 'Grilled Salmon', description: 'Wild-caught salmon with asparagus.', price: 32.0, category: 'Mains', imageUrl: '🐟',
          ingredients: [MenuItemIngredient(ingredientId: 'ing7', quantity: 200), MenuItemIngredient(ingredientId: 'ing8', quantity: 80)]),
      MenuItem(id: 'm5', name: 'Caesar Salad', description: 'Crisp romaine, parmesan, croutons.', price: 16.0, category: 'Starters', imageUrl: '🥗',
          ingredients: [MenuItemIngredient(ingredientId: 'ing9', quantity: 120), MenuItemIngredient(ingredientId: 'ing10', quantity: 30)]),
      MenuItem(id: 'm6', name: 'Tiramisu', description: 'Classic Italian dessert.', price: 11.0, category: 'Dessert', imageUrl: '🍰', ingredients: []),
      MenuItem(id: 'm7', name: 'Cappuccino', description: 'Freshly roasted espresso.', price: 5.5, category: 'Beverages', imageUrl: '☕',
          ingredients: [MenuItemIngredient(ingredientId: 'ing11', quantity: 18), MenuItemIngredient(ingredientId: 'ing12', quantity: 150)]),
      MenuItem(id: 'm8', name: 'Mango Smoothie', description: 'Fresh tropical blend.', price: 7.0, category: 'Beverages', imageUrl: '🥭',
          ingredients: [MenuItemIngredient(ingredientId: 'ing13', quantity: 1)]),
      MenuItem(id: 'm9', name: 'Club Sandwich', description: 'Triple decker with chicken and bacon.', price: 18.0, category: 'Lunch', imageUrl: '🥪',
          ingredients: [MenuItemIngredient(ingredientId: 'ing14', quantity: 120), MenuItemIngredient(ingredientId: 'ing15', quantity: 3)]),
    ];
    await prefs.setString(_menuKey, json.encode(menuItems.map((e) => e.toMap()).toList()));

    // 4. Seed Tables
    final tables = [
      RestaurantTable(id: 't1', tableNumber: '1', capacity: 2),
      RestaurantTable(id: 't2', tableNumber: '2', capacity: 2),
      RestaurantTable(id: 't3', tableNumber: '3', capacity: 4),
      RestaurantTable(id: 't4', tableNumber: '4', capacity: 4),
      RestaurantTable(id: 't5', tableNumber: '5', capacity: 6),
      RestaurantTable(id: 't6', tableNumber: '6', capacity: 8),
      RestaurantTable(id: 't7', tableNumber: '7', capacity: 2),
      RestaurantTable(id: 't8', tableNumber: '8', capacity: 4),
    ];
    await prefs.setString(_tablesKey, json.encode(tables.map((e) => e.toMap()).toList()));

    // 5. Seed cost records from current ingredient prices
    await prefs.setString(_ordersKey, json.encode([]));
    await prefs.setString(_costRecordsKey, json.encode([]));

    // Compute initial costs
    final pricesLoaded = prices;
    for (final item in menuItems) {
      final cost = _computeCost(item.ingredients, pricesLoaded);
      if (cost > 0) {
        final record = MenuItemCostRecord(
          id: _uuid.v4(),
          menuItemId: item.id,
          cost: cost,
          date: now,
        );
        await _appendCostRecord(prefs, record);
      }
    }

    // 6. Seed Inventory (initial stock for each ingredient)
    final inventory = [
      InventoryItem(ingredientId: 'ing1',  currentStock: 120, minStockLevel: 20),  // Eggs
      InventoryItem(ingredientId: 'ing2',  currentStock: 40,  minStockLevel: 10),  // English Muffin
      InventoryItem(ingredientId: 'ing3',  currentStock: 25,  minStockLevel: 5),   // Avocado
      InventoryItem(ingredientId: 'ing4',  currentStock: 2000,minStockLevel: 300), // Cherry Tomatoes (g)
      InventoryItem(ingredientId: 'ing5',  currentStock: 3000,minStockLevel: 500), // Wagyu Beef (g)
      InventoryItem(ingredientId: 'ing6',  currentStock: 800, minStockLevel: 100), // Truffle Mayo (ml)
      InventoryItem(ingredientId: 'ing7',  currentStock: 4000,minStockLevel: 600), // Salmon (g)
      InventoryItem(ingredientId: 'ing8',  currentStock: 1500,minStockLevel: 200), // Asparagus (g)
      InventoryItem(ingredientId: 'ing9',  currentStock: 2000,minStockLevel: 300), // Romaine (g)
      InventoryItem(ingredientId: 'ing10', currentStock: 800, minStockLevel: 100), // Parmesan (g)
      InventoryItem(ingredientId: 'ing11', currentStock: 500, minStockLevel: 50),  // Espresso (g)
      InventoryItem(ingredientId: 'ing12', currentStock: 5000,minStockLevel: 500), // Milk (ml)
      InventoryItem(ingredientId: 'ing13', currentStock: 30,  minStockLevel: 5),   // Mango
      InventoryItem(ingredientId: 'ing14', currentStock: 3000,minStockLevel: 400), // Chicken (g)
      InventoryItem(ingredientId: 'ing15', currentStock: 60,  minStockLevel: 10),  // Bread slices
    ];
    await prefs.setString(_inventoryKey, json.encode(inventory.map((e) => e.toMap()).toList()));
  }

  double _computeCost(List<MenuItemIngredient> ingredients, List<IngredientPrice> allPrices) {
    double total = 0;
    for (final ing in ingredients) {
      final history = allPrices.where((p) => p.ingredientId == ing.ingredientId).toList();
      if (history.isEmpty) continue;
      history.sort((a, b) => b.date.compareTo(a.date));
      total += history.first.pricePerUnit * ing.quantity;
    }
    return total;
  }

  Future<void> _appendCostRecord(SharedPreferences prefs, MenuItemCostRecord record) async {
    final data = prefs.getString(_costRecordsKey);
    final List<dynamic> list = data != null ? json.decode(data) : [];
    list.add(record.toMap());
    await prefs.setString(_costRecordsKey, json.encode(list));
  }

  // ─── MENU ───────────────────────────────────────────

  Future<List<MenuItem>> getMenuItems() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_menuKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => MenuItem.fromMap(e)).toList();
  }

  Future<void> saveMenuItem(MenuItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getMenuItems();
    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      items[index] = item;
    } else {
      items.add(item);
    }
    await prefs.setString(_menuKey, json.encode(items.map((e) => e.toMap()).toList()));
    // Recalculate cost for this item
    await _recalcCostForItem(item.id);
  }

  Future<void> deleteMenuItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getMenuItems();
    items.removeWhere((i) => i.id == id);
    await prefs.setString(_menuKey, json.encode(items.map((e) => e.toMap()).toList()));
  }

  Future<void> addMenuItem(MenuItem item) async => saveMenuItem(item);

  // ─── INGREDIENTS ────────────────────────────────────

  Future<List<Ingredient>> getIngredients() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_ingredientsKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => Ingredient.fromMap(e)).toList();
  }

  Future<void> saveIngredient(Ingredient ingredient) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getIngredients();
    final index = items.indexWhere((i) => i.id == ingredient.id);
    if (index != -1) {
      items[index] = ingredient;
    } else {
      items.add(ingredient);
    }
    await prefs.setString(_ingredientsKey, json.encode(items.map((e) => e.toMap()).toList()));
  }

  Future<void> deleteIngredient(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getIngredients();
    items.removeWhere((i) => i.id == id);
    await prefs.setString(_ingredientsKey, json.encode(items.map((e) => e.toMap()).toList()));
  }

  // ─── INGREDIENT PRICES ──────────────────────────────

  Future<List<IngredientPrice>> getIngredientPrices() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_ingredientPricesKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => IngredientPrice.fromMap(e)).toList();
  }

  Future<List<IngredientPrice>> getPricesForIngredient(String ingredientId) async {
    final all = await getIngredientPrices();
    final filtered = all.where((p) => p.ingredientId == ingredientId).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<double?> getCurrentPriceForIngredient(String ingredientId) async {
    final history = await getPricesForIngredient(ingredientId);
    return history.isNotEmpty ? history.first.pricePerUnit : null;
  }

  /// Adds a new price record and recalculates costs for all menu items using this ingredient.
  Future<void> addIngredientPrice(IngredientPrice price) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getIngredientPrices();
    all.add(price);
    await prefs.setString(_ingredientPricesKey, json.encode(all.map((e) => e.toMap()).toList()));

    // Recalculate costs for affected menu items
    final menuItems = await getMenuItems();
    for (final item in menuItems) {
      if (item.ingredients.any((ing) => ing.ingredientId == price.ingredientId)) {
        await _recalcCostForItem(item.id);
      }
    }
  }

  Future<void> _recalcCostForItem(String menuItemId) async {
    final prefs = await SharedPreferences.getInstance();
    final menuItems = await getMenuItems();
    final item = menuItems.firstWhere((i) => i.id == menuItemId, orElse: () => MenuItem(id: '', name: '', description: '', price: 0, category: ''));
    if (item.id.isEmpty || item.ingredients.isEmpty) return;

    final allPrices = await getIngredientPrices();
    final cost = _computeCost(item.ingredients, allPrices);
    if (cost <= 0) return;

    final record = MenuItemCostRecord(
      id: _uuid.v4(),
      menuItemId: menuItemId,
      cost: cost,
      date: DateTime.now(),
    );
    await _appendCostRecord(prefs, record);
  }

  // ─── COST RECORDS ───────────────────────────────────

  Future<List<MenuItemCostRecord>> getCostRecordsForItem(String menuItemId) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_costRecordsKey);
    if (data == null) return [];
    final all = (json.decode(data) as List).map((e) => MenuItemCostRecord.fromMap(e)).toList();
    final filtered = all.where((r) => r.menuItemId == menuItemId).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<double?> getCurrentCostForItem(String menuItemId) async {
    final records = await getCostRecordsForItem(menuItemId);
    return records.isNotEmpty ? records.first.cost : null;
  }

  // ─── TABLES ─────────────────────────────────────────

  Future<List<RestaurantTable>> getTables() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tablesKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => RestaurantTable.fromMap(e)).toList();
  }

  Future<void> saveTable(RestaurantTable table) async {
    final prefs = await SharedPreferences.getInstance();
    final tables = await getTables();
    final index = tables.indexWhere((t) => t.id == table.id);
    if (index != -1) {
      tables[index] = table;
    } else {
      tables.add(table);
    }
    await prefs.setString(_tablesKey, json.encode(tables.map((e) => e.toMap()).toList()));
  }

  Future<void> updateTable(RestaurantTable table) async => saveTable(table);

  Future<void> deleteTable(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final tables = await getTables();
    tables.removeWhere((t) => t.id == id);
    await prefs.setString(_tablesKey, json.encode(tables.map((e) => e.toMap()).toList()));
  }

  // ─── ORDERS ─────────────────────────────────────────

  Future<List<RestaurantOrder>> getOrders() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_ordersKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => RestaurantOrder.fromMap(e)).toList();
  }

  /// Saves a new order. If it's a new order (not an update), deducts inventory.
  Future<void> saveOrder(RestaurantOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await getOrders();
    final index = orders.indexWhere((o) => o.id == order.id);
    final isNew = index == -1;
    if (index != -1) {
      orders[index] = order;
    } else {
      orders.add(order);
    }
    await prefs.setString(_ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));

    // Sync table status.
    // Table is freed only when: cancelled, OR served AND payment collected.
    // "served but unpaid" keeps the table occupied so payment can be collected first.
    if (order.tableId != null) {
      final shouldFree = order.status == OrderStatus.cancelled ||
          (order.status == OrderStatus.served &&
              (order.paymentStatus == PaymentStatus.paid ||
                  order.paymentStatus == PaymentStatus.chargedToRoom));
      final tables = await getTables();
      final tIdx = tables.indexWhere((t) => t.id == order.tableId);
      if (tIdx != -1) {
        final newStatus = shouldFree ? TableStatus.available : TableStatus.occupied;
        await saveTable(tables[tIdx].copyWith(status: newStatus));
      }
    }

    // Auto-deduct inventory only for new orders
    if (isNew) {
      await _deductInventoryForOrder(order);
    }
  }

  Future<void> _deductInventoryForOrder(RestaurantOrder order) async {
    await _deductInventoryForItems(order.items);
  }

  Future<void> _deductInventoryForItems(List<OrderItem> items) async {
    final menuItemsData = await getMenuItems();
    final inventory = await getInventory();

    for (final orderItem in items) {
      final menuItem = menuItemsData.firstWhere(
        (m) => m.id == orderItem.menuItem.id,
        orElse: () => orderItem.menuItem,
      );
      for (final ing in menuItem.ingredients) {
        final deductAmount = ing.quantity * orderItem.quantity;
        final invIdx =
            inventory.indexWhere((inv) => inv.ingredientId == ing.ingredientId);
        if (invIdx != -1) {
          final current = inventory[invIdx].currentStock;
          inventory[invIdx] = inventory[invIdx].copyWith(
            currentStock: (current - deductAmount).clamp(0.0, double.infinity),
          );
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _inventoryKey, json.encode(inventory.map((e) => e.toMap()).toList()));
  }

  // ─── TABLE TAB MANAGEMENT ────────────────────────────

  /// Creates a new dine-in tab for a table and returns the saved order.
  Future<RestaurantOrder> createTableOrder({
    required String tableId,
    required List<OrderItem> items,
  }) async {
    final ts = DateTime.now();
    final orderNumber = ts.millisecondsSinceEpoch.toString().substring(7);
    final order = RestaurantOrder(
      id: _uuid.v4(),
      orderNumber: orderNumber,
      tableId: tableId,
      type: OrderType.dineIn,
      status: OrderStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: ts,
      items: items,
    );
    await saveOrder(order); // handles table occupied status + inventory deduction
    return order;
  }

  /// Appends [newItems] to an existing active order and deducts inventory
  /// for the newly added items only.
  Future<RestaurantOrder> addItemsToOrder(
      String orderId, List<OrderItem> newItems) async {
    final orders = await getOrders();
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw Exception('Order not found');
    final order = orders[idx];
    final updatedOrder =
        order.copyWith(items: [...order.items, ...newItems]);
    orders[idx] = updatedOrder;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));
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
    final orders = await getOrders();
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw Exception('Order not found');
    final order = orders[idx];

    final updatedOrder = order.copyWith(
      status: OrderStatus.served,
      paymentStatus: paymentStatus,
      bookingId: bookingId,
    );
    orders[idx] = updatedOrder;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));

    // Free the table
    if (order.tableId != null) {
      final tables = await getTables();
      final tIdx = tables.indexWhere((t) => t.id == order.tableId);
      if (tIdx != -1) {
        await saveTable(tables[tIdx].copyWith(status: TableStatus.available));
      }
    }

    // Create room-charge expense
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

  /// Returns the most recent active order for a table.
  /// "Active" = not cancelled AND not (served + payment collected).
  /// Served-but-unpaid orders keep the table occupied until payment.
  Future<RestaurantOrder?> getActiveOrderForTable(String tableId) async {
    final orders = await getOrders();
    final active = orders.where((o) {
      if (o.tableId != tableId) return false;
      if (o.status == OrderStatus.cancelled) return false;
      if (o.status == OrderStatus.served &&
          (o.paymentStatus == PaymentStatus.paid ||
              o.paymentStatus == PaymentStatus.chargedToRoom)) return false;
      return true;
    }).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return active.first;
  }

  // ─── INVENTORY ──────────────────────────────────────

  Future<List<InventoryItem>> getInventory() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_inventoryKey);
    if (data == null) return [];
    return (json.decode(data) as List).map((e) => InventoryItem.fromMap(e)).toList();
  }

  Future<InventoryItem?> getInventoryForIngredient(String ingredientId) async {
    final inventory = await getInventory();
    try {
      return inventory.firstWhere((i) => i.ingredientId == ingredientId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final inventory = await getInventory();
    final idx = inventory.indexWhere((i) => i.ingredientId == item.ingredientId);
    if (idx != -1) {
      inventory[idx] = item;
    } else {
      inventory.add(item);
    }
    await prefs.setString(_inventoryKey, json.encode(inventory.map((e) => e.toMap()).toList()));
  }

  /// Add stock to an ingredient (positive delta = add, negative = remove).
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

  // ─── CANCEL & REFUND ────────────────────────────────

  /// Cancels an active order.
  /// Inventory is restored **only** when the order was still [OrderStatus.pending]
  /// (i.e. preparation had not started). For preparing / ready orders the
  /// ingredients are considered consumed and are NOT returned to stock.
  Future<void> cancelOrder(String orderId) async {
    final orders = await getOrders();
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    if (order.status == OrderStatus.cancelled) return;

    final shouldRestoreInventory = order.status == OrderStatus.pending;

    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      inventoryRestored: shouldRestoreInventory,
    );
    orders[idx] = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));

    // Only restore ingredients if the order hadn't started being prepared
    if (shouldRestoreInventory) {
      await _restoreInventoryForOrder(order);
    }

    // Remove the room charge from the guest's folio if charged to room
    if (order.paymentStatus == PaymentStatus.chargedToRoom &&
        order.bookingId != null) {
      await _removeRoomChargeForOrder(order);
    }

    // Free up the table
    if (order.tableId != null) {
      final tables = await getTables();
      final tIdx = tables.indexWhere((t) => t.id == order.tableId);
      if (tIdx != -1) {
        await saveTable(tables[tIdx].copyWith(status: TableStatus.available));
      }
    }
  }

  /// Refunds [refundQty] units of a single order item and restores inventory.
  /// Pass the full remaining quantity to do a complete line-item refund.
  Future<void> refundOrderItem(
      String orderId, String orderItemId, int refundQty) async {
    final orders = await getOrders();
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];

    final itemIdx = order.items.indexWhere((i) => i.id == orderItemId);
    if (itemIdx == -1) return;
    final item = order.items[itemIdx];
    if (item.isFullyRefunded) return;

    // Clamp to whatever is still chargeable
    final actualQty = refundQty.clamp(0, item.activeQuantity);
    if (actualQty <= 0) return;

    final newRefundedQty = item.refundedQuantity + actualQty;
    final fullyRefunded = newRefundedQty >= item.quantity;

    final updatedItems = List<OrderItem>.from(order.items);
    updatedItems[itemIdx] = item.copyWith(
      isRefunded: fullyRefunded,
      refundedQuantity: newRefundedQty,
    );
    final updatedOrder = order.copyWith(items: updatedItems);

    orders[idx] = updatedOrder;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));

    // NOTE: Inventory is NOT restored on refunds — the food was already served
    // and consumed. Restoring would misrepresent actual stock levels.

    // Reduce the room charge on the guest folio by exactly what was refunded
    if (order.paymentStatus == PaymentStatus.chargedToRoom &&
        order.bookingId != null) {
      final refundAmount = item.menuItem.price * actualQty;
      await _adjustRoomChargeForRefund(order, refundAmount);
    }
  }

  Future<void> _restoreInventoryForOrder(RestaurantOrder order) async {
    final menuItems = await getMenuItems();
    final inventory = await getInventory();

    for (final orderItem in order.items) {
      // Only restore the units that haven't already been refunded individually
      final qty = orderItem.activeQuantity;
      if (qty <= 0) continue;
      final menuItem = menuItems.firstWhere(
        (m) => m.id == orderItem.menuItem.id,
        orElse: () => orderItem.menuItem,
      );
      for (final ing in menuItem.ingredients) {
        final restoreAmount = ing.quantity * qty;
        final invIdx = inventory.indexWhere((inv) => inv.ingredientId == ing.ingredientId);
        if (invIdx != -1) {
          inventory[invIdx] = inventory[invIdx].copyWith(
            currentStock: inventory[invIdx].currentStock + restoreAmount,
          );
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inventoryKey, json.encode(inventory.map((e) => e.toMap()).toList()));
  }

  // ─── ROOM INVOICE SYNC ──────────────────────────────

  /// Deletes the room-charge expense for a cancelled order.
  Future<void> _removeRoomChargeForOrder(RestaurantOrder order) async {
    final expenses =
        await _bookingService.getExpensesByBookingId(order.bookingId!);
    for (final e in expenses) {
      if (e.description.contains(order.orderNumber)) {
        await _bookingService.deleteExpense(e.id);
      }
    }
  }

  /// Reduces the room-charge expense when item(s) are refunded.
  /// [refundAmount] is the exact monetary value to subtract.
  /// If the remaining amount reaches zero the expense is deleted entirely.
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
        await _bookingService.updateExpense(
          e.copyWith(
            amount: newAmount,
            description:
                'Restaurant Order #${order.orderNumber} (partial refund)',
          ),
        );
      }
      break; // only one expense per order
    }
  }

}
