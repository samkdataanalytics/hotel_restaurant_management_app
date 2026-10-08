import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/staff_session.dart';

/// Emits a tick whenever bookings, check-ins or rooms change for the active
/// property.
///
/// Depends on migration 20261008160951, which adds these three tables to the
/// `supabase_realtime` publication and sets REPLICA IDENTITY FULL on them.
/// Before that migration is applied the subscription simply never fires and the
/// boards fall back to pull-to-refresh — which is what they did previously, so
/// running against an un-migrated database degrades rather than breaks.
final frontDeskRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final propertyId = ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  if (propertyId == null) return const Stream<int>.empty();

  final controller = StreamController<int>();
  var tick = 0;

  void bump(PostgresChangePayload _) {
    if (!controller.isClosed) controller.add(++tick);
  }

  // One channel carrying three subscriptions rather than three channels: the
  // boards re-read wholesale on any change, so they gain nothing from knowing
  // which table moved, and one websocket is cheaper to hold open.
  var channel = Supabase.instance.client.channel('staff_mobile_frontdesk_$propertyId');

  for (final table in const ['bookings', 'check_ins', 'rooms']) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'hotel_id',
        value: propertyId,
      ),
      callback: bump,
    );
  }
  channel.subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
