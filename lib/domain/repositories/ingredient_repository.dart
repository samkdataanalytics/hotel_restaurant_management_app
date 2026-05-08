import '../entities/ingredient.dart';
import '../entities/ingredient_price.dart';
import '../entities/inventory_item.dart';
import '../entities/menu_item_cost_record.dart';

abstract class IngredientRepository {
  // Ingredients
  Future<List<Ingredient>> getIngredients();
  Future<void> saveIngredient(Ingredient ingredient);
  Future<void> deleteIngredient(String id);

  // Ingredient Prices
  Future<List<IngredientPrice>> getIngredientPrices();
  Future<List<IngredientPrice>> getPricesForIngredient(String ingredientId);
  Future<double?> getCurrentPriceForIngredient(String ingredientId);
  Future<void> addIngredientPrice(IngredientPrice price);

  // Inventory
  Future<List<InventoryItem>> getInventory();
  Future<InventoryItem?> getInventoryForIngredient(String ingredientId);
  Future<void> updateInventoryItem(InventoryItem item);
  Future<void> applyInventoryDelta(Map<String, double> deltas, {required bool subtract});

  // Cost Records
  Future<List<MenuItemCostRecord>> getCostRecordsForItem(String menuItemId);
  Future<void> insertCostRecord(MenuItemCostRecord record);
}
