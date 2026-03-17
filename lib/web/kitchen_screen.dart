import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_service.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _restaurantService = RestaurantService();
  final _timeFormat = DateFormat('hh:mm a');
  
  List<RestaurantOrder> _allOrders = [];
  Timer? _refreshTimer;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto refresh every 10 seconds for kitchen updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final orders = await _restaurantService.getOrders();
    // Show only today's active orders
    final now = DateTime.now();
    final todayOrders = orders.where((o) => 
      o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day && 
      o.status != OrderStatus.cancelled
    ).toList();
    
    // Sort by oldest first
    todayOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (!mounted) return;
    setState(() {
      _allOrders = todayOrders;
      _isLoading = false;
    });
  }

  Future<void> _updateOrderStatus(RestaurantOrder order, OrderStatus newStatus) async {
    final updated = order.copyWith(status: newStatus);
    await _restaurantService.saveOrder(updated);
    _loadData(silent: true);
  }

  List<RestaurantOrder> get _pendingOrders => _allOrders.where((o) => o.status == OrderStatus.pending).toList();
  List<RestaurantOrder> get _preparingOrders => _allOrders.where((o) => o.status == OrderStatus.preparing).toList();
  List<RestaurantOrder> get _readyOrders => _allOrders.where((o) => o.status == OrderStatus.ready || o.status == OrderStatus.served).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark theme for kitchen
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _loadData()),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumn('Pending', _pendingOrders, OrderStatus.preparing, Colors.orange),
          _buildColumn('Preparing', _preparingOrders, OrderStatus.ready, Colors.blue),
          _buildColumn('Ready / Served', _readyOrders, OrderStatus.served, Colors.green),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, List<RestaurantOrder> orders, OrderStatus nextStatus, MaterialColor themeColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(color: themeColor.shade200, fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: themeColor.shade900, borderRadius: BorderRadius.circular(12)),
                    child: Text('${orders.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(orders[index], nextStatus, themeColor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrder order, OrderStatus nextStatus, MaterialColor themeColor) {
    final duration = DateTime.now().difference(order.createdAt);
    final minutesWaiting = duration.inMinutes;
    final isUrgent = order.status == OrderStatus.pending && minutesWaiting > 15;

    return Card(
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isUrgent ? BorderSide(color: Colors.red.shade400, width: 2) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${order.orderNumber}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_timeFormat.format(order.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                  child: Text(order.type.name.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (order.tableId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                    child: Text('Tbl ${order.tableId![order.tableId!.length - 1]}', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                if (minutesWaiting > 0)
                  Text('${minutesWaiting}m ago', style: TextStyle(color: isUrgent ? Colors.red.shade300 : Colors.grey.shade400, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            // Items
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.quantity}x', style: TextStyle(color: themeColor.shade300, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.menuItem.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            )),
            
            if (order.status != OrderStatus.served) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _updateOrderStatus(order, nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Mark as ${nextStatus.name.toUpperCase()}'),
              ),
            ],
            if (order.status == OrderStatus.served) ...[
              const SizedBox(height: 16),
              const Center(child: Text('SERVED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 2))),
            ]
          ],
        ),
      ),
    );
  }
}
