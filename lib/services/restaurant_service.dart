import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';

class RestaurantService {
  final String _menuKey = 'mock_menu_data';
  final String _tablesKey = 'mock_tables_data';
  final String _ordersKey = 'mock_orders_data';

  // Make singleton
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
    // 1. Seed Menu Items
    final menuItems = [
      MenuItem(id: 'm1', name: 'Eggs Benedict', description: 'Classic poached eggs on English muffins.', price: 14.0, category: 'Breakfast', imageUrl: '🍳'),
      MenuItem(id: 'm2', name: 'Avocado Toast', description: 'Smashed avocado with cherry tomatoes.', price: 12.0, category: 'Breakfast', imageUrl: '🥑'),
      MenuItem(id: 'm3', name: 'Luxe Burger', description: 'Wagyu beef patty with truffle mayo.', price: 24.0, category: 'Mains', imageUrl: '🍔'),
      MenuItem(id: 'm4', name: 'Grilled Salmon', description: 'Wild-caught salmon with asparagus.', price: 32.0, category: 'Mains', imageUrl: '🐟'),
      MenuItem(id: 'm5', name: 'Caesar Salad', description: 'Crisp romaine, parmesan, croutons.', price: 16.0, category: 'Starters', imageUrl: '🥗'),
      MenuItem(id: 'm6', name: 'Tiramisu', description: 'Classic Italian dessert.', price: 11.0, category: 'Dessert', imageUrl: '🍰'),
      MenuItem(id: 'm7', name: 'Cappuccino', description: 'Freshly roasted espresso.', price: 5.5, category: 'Beverages', imageUrl: '☕'),
      MenuItem(id: 'm8', name: 'Mango Smoothie', description: 'Fresh tropical blend.', price: 7.0, category: 'Beverages', imageUrl: '🥭'),
      MenuItem(id: 'm9', name: 'Club Sandwich', description: 'Triple decker with chicken and bacon.', price: 18.0, category: 'Lunch', imageUrl: '🥪'),
    ];
    await prefs.setString(_menuKey, json.encode(menuItems.map((e) => e.toMap()).toList()));

    // 2. Seed Tables
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

    // 3. Empty Orders initially
    await prefs.setString(_ordersKey, json.encode([]));
  }

  // --- Menu ---

  Future<List<MenuItem>> getMenuItems() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_menuKey);
    if (data == null) return [];
    final List<dynamic> list = json.decode(data);
    return list.map((e) => MenuItem.fromMap(e)).toList();
  }

  Future<void> addMenuItem(MenuItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getMenuItems();
    items.add(item);
    await prefs.setString(_menuKey, json.encode(items.map((e) => e.toMap()).toList()));
  }

  // --- Tables ---

  Future<List<RestaurantTable>> getTables() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tablesKey);
    if (data == null) return [];
    final List<dynamic> list = json.decode(data);
    return list.map((e) => RestaurantTable.fromMap(e)).toList();
  }

  Future<void> updateTable(RestaurantTable table) async {
    final prefs = await SharedPreferences.getInstance();
    final tables = await getTables();
    final index = tables.indexWhere((t) => t.id == table.id);
    if (index != -1) {
      tables[index] = table;
      await prefs.setString(_tablesKey, json.encode(tables.map((e) => e.toMap()).toList()));
    }
  }

  // --- Orders ---

  Future<List<RestaurantOrder>> getOrders() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_ordersKey);
    if (data == null) return [];
    final List<dynamic> list = json.decode(data);
    return list.map((e) => RestaurantOrder.fromMap(e)).toList();
  }

  Future<void> saveOrder(RestaurantOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await getOrders();
    final index = orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      orders[index] = order;
    } else {
      orders.add(order);
    }
    await prefs.setString(_ordersKey, json.encode(orders.map((e) => e.toMap()).toList()));
  }
}
