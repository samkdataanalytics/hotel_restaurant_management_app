import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/ingredient_price.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/menu_item_cost_record.dart';
import '../../domain/repositories/ingredient_repository.dart';

class IngredientRepositoryImpl implements IngredientRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String? hotelId;

  // ─── Mappers ───────────────────────────────────────────────────────────

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

  // ─── Ingredients ───────────────────────────────────────────────────────

  @override
  Future<List<Ingredient>> getIngredients() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('ingredients')
        .select()
        .eq('hotel_id', hotelId!)
        .order('name');
    return rows.map(_ingredientFromRow).toList();
  }

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    await _db.from('ingredients').upsert(_ingredientToRow(ingredient));
  }

  @override
  Future<void> deleteIngredient(String id) async {
    await _db.from('ingredients').delete().eq('id', id);
  }

  // ─── Ingredient Prices ─────────────────────────────────────────────────

  @override
  Future<List<IngredientPrice>> getIngredientPrices() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('ingredient_prices')
        .select()
        .eq('hotel_id', hotelId!)
        .order('date', ascending: false);
    return rows.map(_priceFromRow).toList();
  }

  @override
  Future<List<IngredientPrice>> getPricesForIngredient(
      String ingredientId) async {
    final rows = await _db
        .from('ingredient_prices')
        .select()
        .eq('ingredient_id', ingredientId)
        .order('date', ascending: false);
    return rows.map(_priceFromRow).toList();
  }

  @override
  Future<void> addIngredientPrice(IngredientPrice price) async {
    await _db.from('ingredient_prices').insert(_priceToRow(price));
  }

  @override
  Future<double?> getCurrentPriceForIngredient(String ingredientId) async {
    final rows = await _db
        .from('ingredient_prices')
        .select('price_per_unit')
        .eq('ingredient_id', ingredientId)
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return (rows.first['price_per_unit'] as num).toDouble();
  }

  // ─── Inventory ─────────────────────────────────────────────────────────

  @override
  Future<List<InventoryItem>> getInventory() async {
    if (hotelId == null) return [];
    final rows =
        await _db.from('inventory').select().eq('hotel_id', hotelId!);
    return rows.map(_inventoryFromRow).toList();
  }

  @override
  Future<InventoryItem?> getInventoryForIngredient(
      String ingredientId) async {
    final rows = await _db
        .from('inventory')
        .select()
        .eq('ingredient_id', ingredientId)
        .limit(1);
    return rows.isNotEmpty ? _inventoryFromRow(rows.first) : null;
  }

  @override
  Future<void> updateInventoryItem(InventoryItem item) async {
    await _db.from('inventory').upsert(_inventoryToRow(item));
  }

  @override
  Future<void> applyInventoryDelta(
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

  // ─── Cost Records ─────────────────────────────────────────────────────

  @override
  Future<List<MenuItemCostRecord>> getCostRecordsForItem(
      String menuItemId) async {
    final rows = await _db
        .from('menu_item_cost_records')
        .select()
        .eq('menu_item_id', menuItemId)
        .order('date', ascending: false);
    return rows.map(_costRecordFromRow).toList();
  }

  @override
  Future<void> insertCostRecord(MenuItemCostRecord record) async {
    await _db.from('menu_item_cost_records').insert({
      'id': record.id,
      'menu_item_id': record.menuItemId,
      'cost': record.cost,
      'date': record.date.toIso8601String(),
      if (hotelId != null) 'hotel_id': hotelId,
    });
  }
}
