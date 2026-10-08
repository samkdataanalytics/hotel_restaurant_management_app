import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/staff_session.dart';

/// Tables the staff app mutates, mapped to the column carrying the tenant key.
///
/// `property_staff` is the odd one out: properties and hotels are the same
/// entity in this schema, but that table names the column `property_id` while
/// everything else says `hotel_id`. Filtering on the wrong name silently
/// matches nothing — the subscription succeeds and simply never fires — so the
/// column belongs in data next to the table name rather than assumed.
///
/// Front-desk tables (`bookings`, `check_ins`, `rooms`) are deliberately absent:
/// they have their own single-tick channel in `front_desk_realtime.dart`,
/// because those boards re-read wholesale and gain nothing from knowing which
/// of the three moved.
const _tenantColumn = <String, String>{
  'menu_items': 'hotel_id',
  'restaurant_tables': 'hotel_id',
  'expenses': 'hotel_id',
  'staff_shifts': 'hotel_id',
  'ingredients': 'hotel_id',
  'inventory': 'hotel_id',
  'notifications': 'hotel_id',
  'property_staff': 'property_id',
};

/// A change to one watched table.
class TableChange {
  final String table;
  final PostgresChangeEvent event;

  const TableChange(this.table, this.event);
}

/// One websocket carrying every table in [_tenantColumn].
///
/// A `StreamProvider.family` per table would be simpler to read but would open
/// a channel per table — eight websockets on a phone that may be on hotel wifi
/// at the edge of range. This holds one and lets [tableRealtimeProvider] fan it
/// out, so the cost is a single connection regardless of how many screens are
/// watching.
///
/// Returns a broadcast stream because several family members listen at once.
final _tableChangesProvider = Provider.autoDispose<Stream<TableChange>>((ref) {
  final propertyId = ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  if (propertyId == null) return const Stream<TableChange>.empty();

  final controller = StreamController<TableChange>.broadcast();

  var channel =
      Supabase.instance.client.channel('staff_mobile_tables_$propertyId');

  for (final entry in _tenantColumn.entries) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: entry.key,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: entry.value,
        value: propertyId,
      ),
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(TableChange(entry.key, payload.eventType));
        }
      },
    );
  }
  channel.subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// Emits an incrementing tick whenever [table] changes for the active property.
///
/// Watch it next to a screen's data provider to make that screen live:
///
/// ```dart
/// final _menuProvider = FutureProvider.autoDispose((ref) {
///   ref.watch(tableRealtimeProvider('menu_items'));
///   return ref.watch(repoProvider).loadMenu();
/// });
/// ```
///
/// Watching a table that is not in [_tenantColumn] is a programming error and
/// throws, rather than returning a stream that quietly never fires.
final tableRealtimeProvider =
    StreamProvider.autoDispose.family<int, String>((ref, table) {
  assert(
    _tenantColumn.containsKey(table),
    'No realtime subscription for "$table". Add it to _tenantColumn and '
    'publish it in a migration, or the tick will never arrive.',
  );

  var tick = 0;
  return ref
      .watch(_tableChangesProvider)
      .where((change) => change.table == table)
      .map((_) => ++tick);
});
