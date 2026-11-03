import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/user_tracking_service.dart';
import '../../cms/platform/download_file.dart';
import 'activity_list.dart';
import 'user_detail_dialog.dart';
import 'users_format.dart';

/// Who has registered, how they are doing, and what they have done.
class SuperadminUsersScreen extends ConsumerStatefulWidget {
  const SuperadminUsersScreen({super.key});

  @override
  ConsumerState<SuperadminUsersScreen> createState() => _SuperadminUsersScreenState();
}

enum _View { people, activity }

class _SuperadminUsersScreenState extends ConsumerState<SuperadminUsersScreen> {
  static const _pageSize = 25;

  static const _filters = <(String key, String label)>[
    ('all', 'Everyone'),
    ('new_7d', 'New this week'),
    ('active_7d', 'Active this week'),
    ('inactive_30d', 'Inactive 30+ days'),
    ('never_signed_in', 'Never signed in'),
    ('unconfirmed', 'Email not confirmed'),
    ('superadmin', 'Superadmins'),
    ('deleted', 'Deleted'),
  ];

  _View _view = _View.people;
  String _filter = 'all';
  String _search = '';
  int _page = 0;
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  UsersOverview? _overview;
  UserPage? _users;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  UserTrackingService get _svc => ref.read(userTrackingServiceProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _svc.overview(),
        _svc.listUsers(search: _search, filter: _filter, limit: _pageSize, offset: _page * _pageSize),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as UsersOverview;
        _users = results[1] as UserPage;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('superadmin_list_users') || s.contains('PGRST202') || s.contains('42883')) {
      return 'The user-tracking functions are not installed on this database yet. Apply '
          'supabase/migrations/20261023000002_superadmin_user_tracking.sql in the Supabase SQL editor, then reload.';
    }
    if (s.contains('42501')) return 'Only a superadmin can view users.';
    return 'Could not load users: $s';
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = v.trim();
      _page = 0;
      _reload();
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      // Everything the current search and filter match, up to 2,000 people.
      final all = <UserSummary>[];
      var offset = 0;
      while (all.length < 2000) {
        final page = await _svc.listUsers(search: _search, filter: _filter, limit: 200, offset: offset);
        all.addAll(page.users);
        offset += 200;
        if (page.users.length < 200) break;
      }
      final ok = downloadTextFile('hotrest-users-${DateTime.now().toIso8601String().substring(0, 10)}.csv', usersCsv(all));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Exported ${all.length} users.' : 'Downloads are only available in the browser.'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Expanded(
            child: _view == _View.activity
                ? const SingleChildScrollView(padding: EdgeInsets.fromLTRB(32, 20, 32, 40), child: ActivityList())
                : _people(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text('Everyone who has registered, and what they have done', style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
            ],
          ),
          SegmentedButton<_View>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: _View.people, label: Text('People'), icon: Icon(Icons.people_alt_outlined, size: 16)),
              ButtonSegment(value: _View.activity, label: Text('Activity feed'), icon: Icon(Icons.history_rounded, size: 16)),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ],
      ),
    );
  }

  Widget _people() {
    final o = _overview;
    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (o != null) _stats(o),
            const SizedBox(height: 18),
            _toolbar(),
            const SizedBox(height: 12),
            if (_error != null)
              _Notice(icon: Icons.error_outline_rounded, color: AppTheme.danger, text: _error!, action: 'Retry', onTap: _reload)
            else if (_loading && _users == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (_users != null) ...[
              if (_users!.users.isNotEmpty && MediaQuery.sizeOf(context).width > 1000) const _ColumnHeads(),
              if (_users!.users.isEmpty)
                const _Notice(icon: Icons.search_off_rounded, color: Color(0xFF64748B), text: 'No users match that search and filter.')
              else
                for (final u in _users!.users) _UserRow(user: u, onTap: () => showUserDetail(context, u.userId)),
              _pager(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stats(UsersOverview o) {
    Widget card(String label, int value, IconData icon, Color color, {String? filter}) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: filter == null
              ? null
              : () {
                  _filter = filter;
                  _page = 0;
                  _reload();
                },
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _filter == filter && filter != null ? AppTheme.brandTeal : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                      Text(label, style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        card('Registered users', o.total, Icons.people_alt_rounded, AppTheme.statusBlue, filter: 'all'),
        card('New this week', o.new7d, Icons.person_add_alt_1_rounded, AppTheme.brandTeal, filter: 'new_7d'),
        card('Active this week', o.active7d, Icons.bolt_rounded, AppTheme.statusGreen, filter: 'active_7d'),
        card('Never signed in', o.neverSignedIn, Icons.person_off_outlined, const Color(0xFF64748B), filter: 'never_signed_in'),
        card('Email not confirmed', o.unconfirmed, Icons.mark_email_unread_outlined, AppTheme.statusAmber, filter: 'unconfirmed'),
        card('Actions in 24 h', o.actions24h, Icons.history_rounded, AppTheme.statusPurple),
      ],
    );
  }

  Widget _toolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, username, phone or company',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _exporting || _users == null ? null : _export,
              icon: _exporting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            ),
            IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.$2, style: TextStyle(fontSize: 12.5, color: _filter == f.$1 ? AppTheme.brandTeal : const Color(0xFF334155))),
                    selected: _filter == f.$1,
                    selectedColor: const Color(0xFFEFF8F7),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _filter == f.$1 ? AppTheme.brandTeal : Colors.grey.shade300),
                    showCheckmark: false,
                    onSelected: (_) {
                      _filter = f.$1;
                      _page = 0;
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pager() {
    final total = _users!.total;
    if (total <= _pageSize) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('$total ${total == 1 ? 'user' : 'users'}', style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)),
      );
    }
    final from = _page * _pageSize + 1;
    final to = (from + _users!.users.length - 1).clamp(from, total);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Text('Showing $from–$to of $total', style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: _page == 0 || _loading ? null : () {
              _page--;
              _reload();
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: to >= total || _loading ? null : () {
              _page++;
              _reload();
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Labels for the wide table; the narrow layout labels each value instead.
class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads();

  @override
  Widget build(BuildContext context) {
    Widget h(int flex, String t) => Expanded(
          flex: flex,
          child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          h(26, 'User'),
          h(22, 'Companies'),
          h(11, 'Joined'),
          h(12, 'Last sign-in'),
          h(8, 'Actions 30d'),
          h(18, 'Status'),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});

  final UserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final wide = MediaQuery.sizeOf(context).width > 1000;

    final identity = Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFEFF8F7),
          child: Text(u.initials, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brandTeal, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B))),
              Text(
                u.hasRealEmail ? u.email : (u.username.isNotEmpty ? '@${u.username}' : '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
              ),
            ],
          ),
        ),
      ],
    );

    final companies = u.orgs.isEmpty
        ? Text('—', style: TextStyle(color: AppTheme.adminTextMuted))
        : Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final o in u.orgs.take(2))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                  child: Text('${o.name} · ${o.role}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                ),
              if (u.orgs.length > 2) Text('+${u.orgs.length - 2}', style: TextStyle(fontSize: 11.5, color: AppTheme.adminTextMuted)),
            ],
          );

    Widget cell(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!wide) Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
            Text(value, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
          ],
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: wide
                ? Row(
                    children: [
                      Expanded(flex: 26, child: identity),
                      Expanded(flex: 22, child: companies),
                      Expanded(flex: 11, child: cell('Joined', shortDate(u.createdAt))),
                      Expanded(flex: 12, child: cell('Last sign-in', relativeTime(u.lastSignInAt))),
                      Expanded(flex: 8, child: cell('Actions (30d)', '${u.activity30d}')),
                      Expanded(flex: 18, child: Wrap(spacing: 4, runSpacing: 4, children: statusChips(u))),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 10),
                      companies,
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          cell('Joined', shortDate(u.createdAt)),
                          cell('Last sign-in', relativeTime(u.lastSignInAt)),
                          cell('Actions (30d)', '${u.activity30d}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 4, runSpacing: 4, children: statusChips(u)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text, this.action, this.onTap});

  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(icon, size: 38, color: color),
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
