import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../providers/service_providers.dart';
import '../../services/platform_tracking_service.dart';
import '../semantic_palette.dart';
import 'company_detail_screen.dart';
import 'tracking/tracking_links.dart';
import 'tracking/tracking_widgets.dart';
import 'users/users_format.dart';

/// Every company on the platform: who owns it, what it runs, how active it is.
///
/// One server-side query per page (search, filter and counts are computed in the
/// database) instead of two queries per company, which is what the previous list
/// did and what made it slow as the platform grew.
class CompaniesListScreen extends ConsumerStatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  ConsumerState<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends ConsumerState<CompaniesListScreen> {
  static const _pageSize = 25;

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('active', 'Active'),
    ('trialing', 'Trialing'),
    ('trial_ending', 'Trial ends in 7 days'),
    ('trial_expired', 'Trial expired'),
    ('suspended', 'Suspended'),
    ('dormant', 'No activity in 30 days'),
    ('no_properties', 'No properties'),
    ('deleted', 'Deleted'),
  ];

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String _filter = 'all';
  int _page = 0;
  CompanyPage? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(platformTrackingServiceProvider).listCompanies(
            search: _search,
            filter: _filter,
            limit: _pageSize,
            offset: _page * _pageSize,
          );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('superadmin_list_companies') || s.contains('PGRST202') || s.contains('42883')) {
      return 'The company tracking functions are not installed on this database yet. Apply '
          'supabase/migrations/20261023000004_superadmin_companies_properties.sql in the Supabase SQL editor, then reload.';
    }
    if (s.contains('42501')) return 'Only a superadmin can view companies.';
    return 'Could not load companies: $s';
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = v.trim();
      _page = 0;
      _load();
    });
  }

  Future<void> _open(CompanySummary c) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => CompanyDetailScreen(org: c.toOrganization()),
    );
    // The dialog can suspend, change the plan or delete: show the result.
    if (mounted) {
      if (deleted == true) _page = 0;
      _load();
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
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _chips(),
                    const SizedBox(height: 12),
                    if (_error != null)
                      _Notice(icon: Icons.error_outline_rounded, color: AppTheme.danger, text: _error!, action: 'Retry', onTap: _load)
                    else if (_loading && _data == null)
                      const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                    else if (_data != null) ...[
                      if (_data!.companies.isEmpty)
                        const _Notice(icon: Icons.business_outlined, color: Color(0xFF94A3B8), text: 'No companies match that search and filter.')
                      else ...[
                        if (MediaQuery.sizeOf(context).width > 1100) const _Heads(),
                        for (final c in _data!.companies) _Row(company: c, onTap: () => _open(c), onOwner: () => openUser(context, c.ownerId)),
                      ],
                      _pager(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Companies', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text('Every registered organisation, its owner, usage and activity', style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search name, owner, email, phone, country',
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.adminTextMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', color: AppTheme.adminTextMuted),
        ],
      ),
    );
  }

  Widget _chips() => SingleChildScrollView(
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
                    _load();
                  },
                ),
              ),
          ],
        ),
      );

  Widget _pager() {
    final total = _data!.total;
    if (total <= _pageSize) {
      return Padding(padding: const EdgeInsets.only(top: 10), child: Text('$total ${total == 1 ? 'company' : 'companies'}', style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)));
    }
    final from = _page * _pageSize + 1;
    final to = (from + _data!.companies.length - 1).clamp(from, total);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Text('Showing $from–$to of $total', style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)),
        const Spacer(),
        IconButton(tooltip: 'Previous page', onPressed: _page == 0 || _loading ? null : () { _page--; _load(); }, icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(tooltip: 'Next page', onPressed: to >= total || _loading ? null : () { _page++; _load(); }, icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }
}

class _Heads extends StatelessWidget {
  const _Heads();

  @override
  Widget build(BuildContext context) {
    Widget h(int flex, String t) => Expanded(flex: flex, child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF94A3B8))));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(children: [h(22, 'Company'), h(14, 'Owner'), h(9, 'Plan'), h(13, 'Status'), h(7, 'Props'), h(7, 'People'), h(10, 'Bookings · orders 30d'), h(7, 'Actions'), h(11, 'Last action'), const SizedBox(width: 24)]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.company, required this.onTap, required this.onOwner});

  final CompanySummary company;
  final VoidCallback onTap;
  final VoidCallback onOwner;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final wide = MediaQuery.sizeOf(context).width > 1100;
    final planColor = SemanticPalette.tier(c.plan);
    final daysLeft = c.trialEndsAt?.difference(DateTime.now()).inDays;

    final name = Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppTheme.adminPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.adminPrimary))),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B))),
          Text('${c.country.isEmpty ? '' : '${c.country} · '}since ${shortDate(c.createdAt)}', style: TextStyle(fontSize: 11.5, color: AppTheme.adminTextMuted)),
        ]),
      ),
    ]);

    final owner = c.ownerLabel.isEmpty
        ? Text('—', style: TextStyle(color: AppTheme.adminTextMuted))
        : InkWell(onTap: onOwner, child: Text(c.ownerLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: AppTheme.brandTeal, fontWeight: FontWeight.w600)));

    final plan = TPill(c.plan.isEmpty ? '—' : c.plan.toUpperCase(), color: planColor);
    final status = Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      StatusPill(c.isDeleted ? 'deleted' : c.status),
      if (c.status == 'trialing' && daysLeft != null) Text('${daysLeft < 0 ? 0 : daysLeft}d left', style: TextStyle(fontSize: 11, color: daysLeft <= 7 ? AppTheme.statusAmber : AppTheme.adminTextMuted, fontWeight: FontWeight.w600)),
    ]);

    Widget num(String label, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!wide) Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          Text(v, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
        ]);

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
                ? Row(children: [
                    Expanded(flex: 22, child: name),
                    Expanded(flex: 14, child: owner),
                    Expanded(flex: 9, child: Align(alignment: Alignment.centerLeft, child: plan)),
                    Expanded(flex: 13, child: status),
                    Expanded(flex: 7, child: num('Properties', '${c.properties}')),
                    Expanded(flex: 7, child: num('People', '${c.members}')),
                    Expanded(flex: 10, child: num('Bookings · orders', '${c.bookings30d} · ${c.orders30d}')),
                    Expanded(flex: 7, child: num('Actions', '${c.actions30d}')),
                    Expanded(flex: 11, child: num('Last action', relativeTime(c.lastActivityAt))),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    name,
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [plan, status]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 22, runSpacing: 6, children: [
                      num('Owner', c.ownerLabel.isEmpty ? '—' : c.ownerLabel),
                      num('Properties', '${c.properties}'),
                      num('People', '${c.members}'),
                      num('Bookings · orders 30d', '${c.bookings30d} · ${c.orders30d}'),
                      num('Last action', relativeTime(c.lastActivityAt)),
                    ]),
                  ]),
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
        child: Column(children: [
          Icon(icon, size: 38, color: color),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 12), OutlinedButton(onPressed: onTap, child: Text(action!))],
        ]),
      );
}
