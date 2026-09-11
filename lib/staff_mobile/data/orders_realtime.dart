import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/staff_session.dart';

/// Emits a tick every time a `restaurant_orders` row changes for the active
/// property. Screens watch this and re-read through the repository, rather than
/// trying to patch rows in place — the board is small and a re-read keeps one
/// source of truth.
///
/// Scoped to the active property via a `PostgresChangeFilter` on `hotel_id`.
/// The equivalent web subscription in `lib/web/table_floor_screen.dart` uses a
/// fixed channel name and no filter, so in a multi-property deployment it wakes
/// on other tenants' orders; this one does not. That web screen is working and
/// deliberately left alone.
///
/// `restaurant_orders` is the only table in the `supabase_realtime` publication
/// (verified against the database), and it is set to `REPLICA IDENTITY FULL` so
/// status-only updates still carry `hotel_id` and survive the RLS check on the
/// realtime path. `restaurant_tables` is NOT published — table configuration
/// changes arrive on pull-to-refresh instead.
final ordersRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final propertyId =
      ref.watch(staffSessionProvider).valueOrNull?.activeProperty?.id;

  // No property resolved yet — nothing to subscribe to.
  if (propertyId == null) return const Stream<int>.empty();

  final controller = StreamController<int>();
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
        callback: (_) {
          if (!controller.isClosed) controller.add(++tick);
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
