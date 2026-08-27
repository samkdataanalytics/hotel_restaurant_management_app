import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../app_theme.dart';

// ─── Icon types ───────────────────────────────────────────────────────────────

const _kTypes = {
  'reservation':      (icon: Icons.calendar_today_rounded,   color: Color(0xFF2563EB)),
  'checkin':          (icon: Icons.login_rounded,             color: Color(0xFF22C55E)),
  'checkout':         (icon: Icons.logout_rounded,            color: Color(0xFF64748B)),
  'room_service':     (icon: Icons.room_service_rounded,      color: Color(0xFF8B5CF6)),
  'low_availability': (icon: Icons.warning_amber_rounded,     color: Color(0xFFF59E0B)),
  'housekeeping':     (icon: Icons.cleaning_services_rounded, color: Color(0xFF06B6D4)),
  'shift_change':     (icon: Icons.calendar_month_rounded,    color: Color(0xFF818CF8)),
};

({IconData icon, Color color}) _typeInfo(String type) =>
    _kTypes[type] ?? (icon: Icons.notifications_rounded, color: AppTheme.adminPrimary);

// ─── Bell widget (placed in the top bar) ─────────────────────────────────────

class NotificationBell extends StatefulWidget {
  final NotificationService service;

  const NotificationBell({super.key, required this.service});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  List<AppNotification> _notifications = [];
  StreamSubscription<List<AppNotification>>? _sub;
  bool _panelOpen = false;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;
  final _overlayKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    final viewerUserId = Supabase.instance.client.auth.currentUser?.id;
    _sub = widget.service.watchNotifications(viewerUserId: viewerUserId).listen((list) {
      final prevUnread = _notifications.where((n) => !n.isRead).length;
      final newUnread = list.where((n) => !n.isRead).length;
      setState(() => _notifications = list);
      if (newUnread > prevUnread) _shakeCtrl.forward(from: 0);
      // Refresh panel if open
      if (_panelOpen) _refreshOverlay();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _shakeCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _togglePanel() {
    if (_panelOpen) {
      _removeOverlay();
    } else {
      _openPanel();
    }
  }

  void _openPanel() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => _NotificationPanel(
        notifications: _notifications,
        anchorRight: offset.dx + size.width,
        anchorTop: offset.dy + size.height + 8,
        onMarkRead: (id) async {
          await widget.service.markAsRead(id);
        },
        onMarkAllRead: () async {
          await widget.service.markAllAsRead();
        },
        onDismiss: _removeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() => _panelOpen = true);
  }

  void _refreshOverlay() {
    _overlay?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _panelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.rotate(
        angle: _shakeAnim.value * 0.3 * ((_shakeCtrl.value < 0.5) ? 1 : -1),
        child: child,
      ),
      child: GestureDetector(
        key: _overlayKey,
        onTap: _togglePanel,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _panelOpen
                ? AppTheme.adminPrimary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_rounded,
                size: 22,
                color: _panelOpen
                    ? AppTheme.adminPrimary
                    : const Color(0xFF94A3B8),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification panel (overlay) ────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  final List<AppNotification> notifications;
  final double anchorRight;
  final double anchorTop;
  final Future<void> Function(String id) onMarkRead;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onDismiss;

  const _NotificationPanel({
    required this.notifications,
    required this.anchorRight,
    required this.anchorTop,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = notifications.any((n) => !n.isRead);

    return Stack(
      children: [
        // Tap-away barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Panel
        Positioned(
          top: anchorTop,
          right: MediaQuery.of(context).size.width - anchorRight,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black26,
            child: Container(
              width: 360,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        if (hasUnread)
                          TextButton(
                            onPressed: onMarkAllRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF2563EB)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 40, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 10),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) =>
                            _NotificationTile(
                          notification: notifications[i],
                          onTap: () => onMarkRead(notifications[i].id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Single notification tile ─────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo(notification.type);
    final isUnread = !notification.isRead;
    final timeAgo = _formatTime(notification.createdAt);

    return InkWell(
      onTap: isUnread ? onTap : null,
      child: Container(
        color: isUnread
            ? AppTheme.adminPrimary.withOpacity(0.03)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: info.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(info.icon, size: 18, color: info.color),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }
}
