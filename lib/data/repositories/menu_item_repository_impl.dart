import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/menu_item_cost_record.dart';
import '../../domain/repositories/menu_item_repository.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../../di/injection_container.dart';

class MenuItemRepositoryImpl implements MenuItemRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String? hotelId;

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

  static MenuItemCostRecord _costRecordFromRow(Map<String, dynamic> r) =>
      MenuItemCostRecord.fromMap({
        'id': r['id'],
        'menuItemId': r['menu_item_id'],
        'cost': r['cost'],
        'date': r['date'],
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

  @override
  Future<List<MenuItem>> getMenuItems() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('menu_items')
        .select()
        .eq('hotel_id', hotelId!)
        .order('category')
        .order('name');
    return rows.map(_menuItemFromRow).toList();
  }

  @override
  Future<void> saveMenuItem(MenuItem item) async {
    await _db.from('menu_items').upsert(_menuItemToRow(item));
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    await _db.from('menu_items').delete().eq('id', id);
  }

  @override
  Future<double?> getComputedCostForItem(MenuItem item) async {
    if (item.ingredients.isEmpty) return null;
    double total = 0;
    final ingRepo = sl<IngredientRepository>();
    for (final recipeIng in item.ingredients) {
      final price = await ingRepo.getCurrentPriceForIngredient(recipeIng.ingredientId);
      if (price != null) {
        total += price * recipeIng.quantity;
      }
    }
    return total;
  }

  @override
  Future<List<MenuItemCostRecord>> getCostRecordsForItem(String menuItemId) async {
    final rows = await _db
        .from('menu_item_cost_records')
        .select()
        .eq('menu_item_id', menuItemId)
        .order('date', ascending: false);
    return rows.map(_costRecordFromRow).toList();
  }
}
