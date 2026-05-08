import '../entities/restaurant_order.dart';

abstract class OrderRepository {
  Future<List<RestaurantOrder>> getOrders();
  Future<RestaurantOrder?> getOrder(String id);
  Future<void> upsertOrder(RestaurantOrder order);
  Future<void> updateOrderFields(String orderId, Map<String, dynamic> fields);
  Future<List<RestaurantOrder>> getChargedToRoomOrders(String bookingId);
  Future<int> countActiveKitchenOrdersToday();
  Future<List<RestaurantOrder>> getOpenOrdersForTable(String tableId);
}
