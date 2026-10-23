import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/user_tracking_service.dart';
import 'users_format.dart';

/// A filterable, pageable view of the activity log: everything, one company, or
/// one person. Used on the Users page, in a user's detail, and on a company.
class ActivityList extends ConsumerStatefulWidget {
  const ActivityList({super.key, this.userId, this.orgId, this.showActor = true, this.emptyHint});

  final String? userId;
  final String? orgId;

  /// Hidden when the list is already one person's.
  final bool showActor;
  final String? emptyHint;

  @override
  ConsumerState<ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends ConsumerState<ActivityList> {
  static const _pageSize = 40;

  final _entries = <ActivityEntry>[];
  String _prefix = '';
  bool _loading = true;
  bool _more = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(ActivityList old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.orgId != widget.orgId) _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _entries.clear();
        _more = true;
        _error = null;
      });
    }
    setState(() => _loading = true);
    try {
      final page = await ref.read(userTrackingServiceProvider).activity(
            userId: widget.userId,
            orgId: widget.orgId,
            actionPrefix: _prefix,
            limit: _pageSize,
            before: _entries.isEmpty ? null : _entries.last.createdAt,
          );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _more = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('superadmin_user_activity') || s.contains('42883') || s.contains('PGRST202')) {
      return 'The user-tracking functions are not installed on this database yet. Apply '
          'supabase/migrations/20261023000002_superadmin_user_tracking.sql, then reload.';
    }
    if (s.contains('42501')) return 'Only a superadmin can view activity.';
    return 'Could not load activity: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
          child: Row(
            children: [
              for (final g in ActivityLabels.groups)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(g.$1, style: TextStyle(fontSize: 12.5, color: _prefix == g.$2 ? AppTheme.brandTeal : const Color(0xFF334155))),
                    selected: _prefix == g.$2,
                    selectedColor: const Color(0xFFEFF8F7),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _prefix == g.$2 ? AppTheme.brandTeal : Colors.grey.shade300),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _prefix = g.$2);
                      _load(reset: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          _Message(icon: Icons.error_outline_rounded, color: AppTheme.danger, text: _error!, action: 'Retry', onTap: () => _load(reset: true))
        else if (_entries.isEmpty && _loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_entries.isEmpty)
          _Message(
            icon: Icons.history_rounded,
            color: AppTheme.adminTextMuted,
            text: widget.emptyHint ??
                'Nothing recorded yet. Activity is logged from the moment tracking was switched on: '
                    'sign-ins, bookings, orders, team and billing changes.',
          )
        else ...[
          for (final e in _entries) _Row(entry: e, showActor: widget.showActor),
          if (_more)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _load(reset: false),
                  child: Text(_loading ? 'Loading…' : 'Load older'),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.color, required this.text, this.action, this.onTap});

  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onTap, child: Text(action!)),
            ],
          ],
        ),
      );
}

({IconData icon, Color color}) _style(String action) {
  final p = action.split('.').first;
  return switch (p) {
    'auth' => (icon: action == 'auth.sign_up' ? Icons.person_add_alt_1_rounded : Icons.login_rounded, color: const Color(0xFF2563EB)),
    'booking' || 'check_in' => (icon: Icons.event_available_rounded, color: const Color(0xFF0A7D77)),
    'order' => (icon: Icons.restaurant_rounded, color: const Color(0xFFF97316)),
    'expense' => (icon: Icons.receipt_long_rounded, color: const Color(0xFF64748B)),
    'room' || 'menu_item' || 'table' => (icon: Icons.meeting_room_rounded, color: const Color(0xFF8B5CF6)),
    'org_member' || 'property_staff' || 'staff_invite' || 'shift' || 'time_record' =>
      (icon: Icons.groups_rounded, color: const Color(0xFFEC4899)),
    'payment' => (icon: Icons.payments_rounded, color: const Color(0xFF16A34A)),
    'org' => (icon: Icons.business_rounded, color: const Color(0xFF012C58)),
    'profile' => (icon: Icons.badge_rounded, color: const Color(0xFF0891B2)),
    _ => (icon: Icons.bolt_rounded, color: const Color(0xFF64748B)),
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.showActor});

  final ActivityEntry entry;
  final bool showActor;

  @override
  Widget build(BuildContext context) {
    final s = _style(entry.action);
    final extra = ActivityLabels.summary(entry);
    final where = [if (entry.orgName.isNotEmpty) entry.orgName, if (entry.propertyName.isNotEmpty) entry.propertyName].join(' › ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(s.icon, size: 16, color: s.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    if (showActor) TextSpan(text: '${entry.actor}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ActivityLabels.label(entry.action)),
                  ]),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                ),
                if (extra.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(extra, style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)),
                  ),
                if (where.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(where, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: fullTime(entry.createdAt),
            child: Text(relativeTime(entry.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }
}
