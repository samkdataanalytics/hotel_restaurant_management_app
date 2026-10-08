import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/staff_session.dart';

/// A change to `restaurant_orders` for the active property.
class OrderChange {
  /// Monotonic counter, so widgets can watch this provider purely as a
  /// "something moved" signal without caring what changed.
  final int tick;

  final PostgresChangeEvent event;

  /// The new row, as Supabase delivered it. Snake-case DB columns, not a
  /// domain entity — callers that need a full order re-read through the
  /// repository rather than trusting a partial payload.
  final Map<String, dynamic> record;

  const OrderChange({
    required this.tick,
    required this.event,
    required this.record,
  });

  bool get isNewOrder => event == PostgresChangeEvent.insert;

  String? get orderNumber => record['order_number'] as String?;
  String? get tableId => record['table_id'] as String?;
  String? get status => record['status'] as String?;
  String? get type => record['type'] as String?;

  /// Number of lines on the order, read defensively — `items` is jsonb and an
  /// older row could be shaped differently.
  int get itemCount {
    final items = record['items'];
    return items is List ? items.length : 0;
  }
}

/// Streams `restaurant_orders` changes for the active property.
///
/// Scoped by a `PostgresChangeFilter` on `hotel_id`. The equivalent web
/// subscription in `lib/web/table_floor_screen.dart` uses a fixed channel name
/// and no filter, so in a multi-property deployment it wakes on other tenants'
/// orders; this one does not. That web screen works and is deliberately left
/// alone.
///
/// `restaurant_orders` is `REPLICA IDENTITY FULL`, so status-only updates
/// still carry `hotel_id` and survive the RLS check on the realtime path.
///
/// It was once the only published table. The front-desk tables followed in
/// 20261008160951 and the rest in 20261008164027; see `front_desk_realtime.dart`
/// and `table_realtime.dart` for those.
final ordersRealtimeProvider =
    StreamProvider.autoDispose<OrderChange>((ref) {
  final propertyId =
      ref.watch(staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  if (propertyId == null) return const Stream<OrderChange>.empty();

  final controller = StreamController<OrderChange>();
  var tick = 0;

  final channel = Supabase.instance.client
      .channel('staff_mobile_orders_$propertyId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'restaurant_orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'hotel_id',
          value: propertyId,
        ),
        callback: (payload) {
          if (controller.isClosed) return;
          controller.add(OrderChange(
            tick: ++tick,
            event: payload.eventType,
            record: payload.newRecord,
          ));
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
