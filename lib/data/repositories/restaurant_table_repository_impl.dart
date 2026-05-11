import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/restaurant_table.dart';
import '../../domain/repositories/restaurant_table_repository.dart';

class RestaurantTableRepositoryImpl implements RestaurantTableRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String? hotelId;

  static RestaurantTable _tableFromRow(Map<String, dynamic> r) =>
      RestaurantTable.fromMap({
        'id': r['id'],
        'tableNumber': r['table_number'],
        'capacity': r['capacity'],
        'status': r['status'] ?? 'available',
      });

  Map<String, dynamic> _tableToRow(RestaurantTable t) => {
        'id': t.id,
        'table_number': t.tableNumber,
        'capacity': t.capacity,
        'status': t.status.name,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  @override
  Future<List<RestaurantTable>> getTables() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('restaurant_tables')
        .select()
        .eq('hotel_id', hotelId!)
        .order('table_number');
    return rows.map(_tableFromRow).toList();
  }

  @override
  Future<void> saveTable(RestaurantTable table) async {
    await _db.from('restaurant_tables').upsert(_tableToRow(table));
  }

  @override
  Future<void> deleteTable(String id) async {
    await _db.from('restaurant_tables').delete().eq('id', id);
  }

  @override
  Future<void> updateTableStatus(String tableId, String status) async {
    await _db
        .from('restaurant_tables')
        .update({'status': status})
        .eq('id', tableId);
  }
}
