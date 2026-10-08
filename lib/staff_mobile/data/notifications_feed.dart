import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notification_service.dart';
import '../session/staff_session.dart';
import 'manager_repository.dart';
import 'table_realtime.dart';

/// The notification inbox for the active property, kept live.
///
/// Shared by the inbox screen and the shell's badge so the two can never
/// disagree — a badge reading "3" over an empty list is the kind of thing staff
/// stop trusting the app over.
///
/// Not `autoDispose`: the shell watches this for the badge and must keep it for
/// the whole signed-in session, while the inbox screen comes and goes. The
/// property selector below resets it on a property switch, which is the only
/// case where holding stale rows would matter.
final notificationsFeedProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  // Live since 20261008160951 published `notifications`. Before that this
  // table was read through a `.stream()` that never fired, so the inbox was
  // effectively poll-only.
  ref.watch(tableRealtimeProvider('notifications'));

  return ref.watch(managerRepositoryProvider).loadNotifications();
});

/// Unread count for the shell badge.
///
/// Derived rather than queried separately: a second `count(*)` round trip could
/// return a different number from the list on screen.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final feed = ref.watch(notificationsFeedProvider);
  return feed.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});
