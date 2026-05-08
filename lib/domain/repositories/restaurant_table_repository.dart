import '../entities/restaurant_table.dart';

abstract class RestaurantTableRepository {
  Future<List<RestaurantTable>> getTables();
  Future<void> saveTable(RestaurantTable table);
  Future<void> deleteTable(String id);
  Future<void> updateTableStatus(String tableId, String status);
}
