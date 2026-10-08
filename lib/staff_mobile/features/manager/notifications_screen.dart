import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../services/notification_service.dart';
import '../../data/connectivity.dart';
import '../../data/manager_repository.dart';
import '../../data/notifications_feed.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/offline_banner.dart';

/// The history behind the alerts.
///
/// Read state is shared with the web panel — both write `is_read` on the same
/// rows — so clearing the inbox on a phone clears the bell on the desktop.
///
/// Live: backed by [notificationsFeedProvider], which the shell also watches
/// for its badge, so the two cannot disagree. Migration 20261008160951 put
/// `notifications` in the realtime publication — before that it was poll-only,
/// because `notification_service`'s `.stream()` sat on an unpublished table and
/// never emitted past its first snapshot.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _busy = false;
  static final _stamp = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsFeedProvider);
    final unread = async.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _busy ? null : _markAllRead,
              child: Text('Mark all read ($unread)'),
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(notificationsFeedProvider.future),
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Could not load notifications.\n\n$e',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                data: (items) => items.isEmpty
                    ? ListView(children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  size: 52,
                                  color:
                                      Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('Nothing yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge),
                            ],
                          ),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotificationCard(
                          item: items[i],
                          stamp: _stamp,
                          onTap: () => _markRead(items[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead) return;
    try {
      await ref.read(managerRepositoryProvider).markNotificationRead(item.id);
      if (mounted) ref.invalidate(notificationsFeedProvider);
    } catch (e) {
      if (!mounted) return;
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Marking it read',
      );
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      await ref.read(managerRepositoryProvider).markAllNotificationsRead();
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(notificationsFeedProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Marking everything read',
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final DateFormat stamp;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.stamp,
    required this.onTap,
  });

  /// One glyph and colour per event type, so the inbox is scannable without
  /// reading every title.
  static ({IconData icon, Color colour}) _style(String type) =>
      switch (type) {
        'reservation' => (
            icon: Icons.calendar_month_rounded,
            colour: StaffTheme.tableSeated
          ),
        'checkin' => (
            icon: Icons.how_to_reg_rounded,
            colour: StaffTheme.tableReady
          ),
        'checkout' => (
            icon: Icons.logout_rounded,
            colour: StaffTheme.tableFree
          ),
        'room_service' => (
            icon: Icons.room_service_rounded,
            colour: StaffTheme.tableInKitchen
          ),
        'low_availability' => (
            icon: Icons.warning_amber_rounded,
            colour: StaffTheme.tableBillRequested
          ),
        'housekeeping' => (
            icon: Icons.cleaning_services_rounded,
            colour: StaffTheme.tableBillRequested
          ),
        _ => (icon: Icons.notifications_rounded, colour: StaffTheme.tableFree),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _style(item.type);

    return Card(
      clipBehavior: Clip.antiAlias,
      // Unread is carried by a tinted surface as well as the dot, so it reads
      // at a glance rather than needing a hunt for the marker.
      color: item.isRead ? null : scheme.secondaryContainer.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: style.colour.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 19, color: style.colour),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            item.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(item.body,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: scheme.onSurfaceVariant,
                            height: 1.35)),
                    const SizedBox(height: 5),
                    Text(stamp.format(item.createdAt),
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
