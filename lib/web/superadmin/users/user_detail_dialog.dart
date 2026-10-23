import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/user_tracking_service.dart';
import 'activity_list.dart';
import 'users_format.dart';

Future<void> showUserDetail(BuildContext context, String userId) => showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
          child: UserDetailView(userId: userId),
        ),
      ),
    );

/// Everything about one registered user: who they are, how they got here, which
/// companies they belong to, what they have paid, and what they have done.
class UserDetailView extends ConsumerStatefulWidget {
  const UserDetailView({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends ConsumerState<UserDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<UserDetail> _future = ref.read(userTrackingServiceProvider).userDetail(widget.userId);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserDetail>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.danger),
                const SizedBox(height: 10),
                Text('Could not load this user: ${snap.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _future = ref.read(userTrackingServiceProvider).userDetail(widget.userId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final d = snap.data!;
        return Column(
          children: [
            _Header(detail: d),
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.brandTeal,
              unselectedLabelColor: AppTheme.adminTextMuted,
              indicatorColor: AppTheme.brandTeal,
              tabs: [
                const Tab(text: 'Overview'),
                Tab(text: 'Activity (${d.activityTotal})'),
                Tab(text: 'Sessions (${d.sessions.length})'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _Overview(detail: d),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ActivityList(userId: widget.userId, showActor: false),
                  ),
                  _Sessions(detail: d),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    final u = detail.summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEFF8F7),
            child: Text(u.initials, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brandTeal, fontSize: 17)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.displayName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(
                  [if (u.hasRealEmail) u.email, if (u.username.isNotEmpty) '@${u.username}', if (u.jobTitle.isNotEmpty) u.jobTitle].join('  ·  '),
                  style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
                ),
              ],
            ),
          ),
          Wrap(spacing: 6, children: statusChips(u)),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

/// Small status pills shared by the list and the detail.
List<Widget> statusChips(UserSummary u, {DateTime? now}) {
  final n = now ?? DateTime.now();
  Widget chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );
  return [
    if (u.isSuperadmin) chip('Superadmin', AppTheme.brandTeal),
    if (u.isDeleted) chip('Deleted', const Color(0xFF64748B)),
    if (u.banned) chip('Suspended', AppTheme.statusRed),
    if (!u.emailConfirmed && u.hasRealEmail) chip('Email not confirmed', AppTheme.statusAmber),
    if (u.lastSignInAt == null) chip('Never signed in', const Color(0xFF64748B)),
    if (u.createdAt != null && n.difference(u.createdAt!).inDays < 7) chip('New', AppTheme.statusBlue),
  ];
}

class _Overview extends StatelessWidget {
  const _Overview({required this.detail});

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    final u = detail.summary;
    final maxCount = detail.activityCounts.fold<int>(1, (m, c) => c.count > m ? c.count : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _Card(title: 'Account', width: 430, children: [
            _Fact('Registered', fullTime(u.createdAt)),
            _Fact('Last signed in', u.lastSignInAt == null ? 'Never' : '${fullTime(u.lastSignInAt)}  (${relativeTime(u.lastSignInAt)})'),
            _Fact('Email', u.hasRealEmail ? '${u.email}${detail.emailConfirmedAt == null ? '  (not confirmed)' : ''}' : 'Signs in with a username'),
            if (u.phone.isNotEmpty) _Fact('Phone', u.phone),
            _Fact('Sign-in methods', detail.providers.isEmpty ? '—' : detail.providers.join(', ')),
            _Fact('Open sessions', '${detail.sessionsOpen}'),
            if (detail.bannedUntil != null && detail.bannedUntil!.isAfter(DateTime.now()))
              _Fact('Suspended until', fullTime(detail.bannedUntil)),
            _Fact('Invites sent', '${detail.invitesSent}'),
            _Fact('User id', u.userId, mono: true),
          ]),
          _Card(title: 'Companies', width: 430, children: [
            if (u.orgs.isEmpty) const _Muted('Not a member of any company.'),
            for (final o in u.orgs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(
                            [if (o.plan.isNotEmpty) '${o.plan} plan', if (o.status.isNotEmpty) o.status, 'joined ${shortDate(detail.joinedOrgs[o.orgId])}'].join(' · '),
                            style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
                          ),
                        ],
                      ),
                    ),
                    _Pill(o.role),
                  ],
                ),
              ),
            if (detail.properties.isNotEmpty) ...[
              const Divider(height: 22),
              const Text('Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
              const SizedBox(height: 8),
              for (final p in detail.properties)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                    _Pill(p.role),
                  ]),
                ),
            ],
          ]),
          _Card(title: 'What they did in the last 30 days', width: 430, children: [
            if (detail.activityCounts.isEmpty) const _Muted('No recorded actions in the last 30 days.'),
            for (final c in detail.activityCounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 170, child: Text(ActivityLabels.label(c.action), style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.count / maxCount,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: AppTheme.brandTeal,
                        ),
                      ),
                    ),
                    SizedBox(width: 40, child: Text('${c.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            if (detail.firstActivityAt != null) ...[
              const Divider(height: 22),
              _Fact('First recorded', fullTime(detail.firstActivityAt)),
              _Fact('Last action', detail.lastActivityAt == null ? '—' : relativeTime(detail.lastActivityAt)),
            ],
          ]),
          _Card(title: 'Payments', width: 430, children: [
            if (detail.payments.isEmpty) const _Muted('No payments started by this user.'),
            for (final p in detail.payments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${p.plan}${p.cycle.isEmpty ? '' : ' · ${p.cycle}'}\n${shortDate(p.createdAt)}', style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    ),
                    Text('${p.currency} ${p.amount == p.amount.roundToDouble() ? p.amount.round() : p.amount}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    _Pill(p.status),
                  ],
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _Sessions extends StatelessWidget {
  const _Sessions({required this.detail});

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.sessions.isEmpty) {
      return const Center(child: _Muted('No open sessions. A session ends when the user signs out.'));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _Muted('Sessions that are still open. The device and address come from the sign-in request. '
            'A user who signed out has no entry here, but the sign-in is still in the activity log.'),
        const SizedBox(height: 14),
        for (final s in detail.sessions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                const Icon(Icons.devices_rounded, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text('Started ${fullTime(s.started)}${s.refreshed == null ? '' : '  ·  last active ${relativeTime(s.refreshed)}'}',
                          style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                    ],
                  ),
                ),
                if (s.ip.isNotEmpty) Text(s.ip, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.width, required this.children});

  final String title;
  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted))),
            Expanded(
              child: SelectableText(value, style: TextStyle(fontSize: 12.5, color: const Color(0xFF1E293B), fontFamily: mono ? 'monospace' : null)),
            ),
          ],
        ),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted, height: 1.5));
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      );
}
