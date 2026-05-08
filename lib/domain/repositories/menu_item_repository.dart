import '../entities/menu_item.dart';
import '../entities/menu_item_cost_record.dart';

abstract class MenuItemRepository {
  Future<List<MenuItem>> getMenuItems();
  Future<void> saveMenuItem(MenuItem item);
  Future<void> deleteMenuItem(String id);
  Future<double?> getComputedCostForItem(MenuItem item);
  Future<List<MenuItemCostRecord>> getCostRecordsForItem(String menuItemId);
}
