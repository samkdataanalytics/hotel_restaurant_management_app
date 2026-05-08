import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String? hotelId;

  /// Converts a Supabase TIMESTAMPTZ string to a local [DateTime].
  static DateTime _parseLocalTimestamp(String raw) {
    final dt = DateTime.parse(raw);
    if (!dt.isUtc) return dt;
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
        'createdAt':
            _parseLocalTimestamp(r['created_at'] as String).toIso8601String(),
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

  @override
  Future<List<RestaurantOrder>> getOrders() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('hotel_id', hotelId!)
        .order('created_at', ascending: false);
    return rows.map(_orderFromRow).toList();
  }

  @override
  Future<RestaurantOrder?> getOrder(String id) async {
    final rows = await _db
        .from('restaurant_orders')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return _orderFromRow(rows.first);
  }

  @override
  Future<void> upsertOrder(RestaurantOrder order) async {
    await _db.from('restaurant_orders').upsert(_orderToRow(order));
  }

  @override
  Future<void> updateOrderFields(
      String orderId, Map<String, dynamic> fields) async {
    await _db.from('restaurant_orders').update(fields).eq('id', orderId);
  }

  @override
  Future<List<RestaurantOrder>> getChargedToRoomOrders(
      String bookingId) async {
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

  @override
  Future<int> countActiveKitchenOrdersToday() async {
    if (hotelId == null) return 0;
    try {
      final today = DateTime.now();
      final start =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final rows = await _db
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

  @override
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
}
