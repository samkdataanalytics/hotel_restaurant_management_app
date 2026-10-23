import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/platform_tracking_service.dart';
import '../users/users_format.dart';
import 'property_detail_dialog.dart';
import 'tracking_links.dart';
import 'tracking_widgets.dart';

/// Every property on the platform, whichever company owns it.
class SuperadminPropertiesScreen extends ConsumerStatefulWidget {
  const SuperadminPropertiesScreen({super.key});

  @override
  ConsumerState<SuperadminPropertiesScreen> createState() => _SuperadminPropertiesScreenState();
}

class _SuperadminPropertiesScreenState extends ConsumerState<SuperadminPropertiesScreen> {
  static const _pageSize = 25;

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('active', 'Active'),
    ('inactive', 'Inactive'),
    ('hotel', 'Hotels'),
    ('restaurant', 'Restaurants'),
    ('both', 'Hotel + restaurant'),
    ('no_activity', 'No activity in 30 days'),
    ('deleted', 'Deleted'),
  ];

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String _filter = 'all';
  int _page = 0;
  PropertyPage? _data;
  PlatformOverview? _overview;
  bool _loading = true;
  String? _error;

  PlatformTrackingService get _svc => ref.read(platformTrackingServiceProvider);

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
      final r = await Future.wait([
        _svc.overview(),
        _svc.listProperties(search: _search, filter: _filter, limit: _pageSize, offset: _page * _pageSize),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = r[0] as PlatformOverview;
        _data = r[1] as PropertyPage;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('superadmin_list_properties') || s.contains('PGRST202') || s.contains('42883')) {
      return 'The property tracking functions are not installed on this database yet. Apply '
          'supabase/migrations/20261023000004_superadmin_companies_properties.sql in the Supabase SQL editor, then reload.';
    }
    if (s.contains('42501')) return 'Only a superadmin can view properties.';
    return 'Could not load properties: $s';
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = v.trim();
      _page = 0;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    return Container(
      color: AppTheme.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Properties', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text('Every hotel and restaurant on the platform, with its company and activity', style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
                ]),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(hintText: 'Search name, company, city, country', prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.adminTextMuted)),
                ),
              ),
              IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', color: AppTheme.adminTextMuted),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (o != null)
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      TStat(label: 'Properties', value: '${o.properties}', sub: '${o.propertiesActive} active', icon: Icons.apartment_rounded, color: AppTheme.statusBlue),
                      TStat(label: 'New (30d)', value: '${o.propertiesNew30d}', icon: Icons.add_business_rounded, color: AppTheme.brandTeal),
                      TStat(label: 'Rooms', value: '${o.rooms}', icon: Icons.bed_rounded, color: AppTheme.statusPurple),
                      TStat(label: 'Restaurant tables', value: '${o.tables}', icon: Icons.table_restaurant_rounded, color: const Color(0xFFF97316)),
                      TStat(label: 'Bookings (30d)', value: '${o.bookings30d}', icon: Icons.event_available_rounded, color: AppTheme.statusGreen),
                      TStat(label: 'Orders (30d)', value: '${o.orders30d}', icon: Icons.restaurant_rounded, color: const Color(0xFFEC4899)),
                    ]),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
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
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    _Notice(icon: Icons.error_outline_rounded, color: AppTheme.danger, text: _error!, onRetry: _load)
                  else if (_loading && _data == null)
                    const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                  else if (_data != null) ...[
                    if (_data!.properties.isEmpty)
                      const _Notice(icon: Icons.apartment_outlined, color: Color(0xFF94A3B8), text: 'No properties match that search and filter.')
                    else ...[
                      if (MediaQuery.sizeOf(context).width > 1100) const _Heads(),
                      for (final p in _data!.properties) _Row(p: p),
                    ],
                    _pager(),
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    final total = _data!.total;
    if (total <= _pageSize) {
      return Padding(padding: const EdgeInsets.only(top: 10), child: Text('$total ${total == 1 ? 'property' : 'properties'}', style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted)));
    }
    final from = _page * _pageSize + 1;
    final to = (from + _data!.properties.length - 1).clamp(from, total);
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
      child: Row(children: [h(22, 'Property'), h(17, 'Company'), h(10, 'Status'), h(9, 'Rooms · tables'), h(7, 'Staff'), h(12, 'Bookings · orders 30d'), h(7, 'Actions'), h(11, 'Last action'), const SizedBox(width: 24)]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.p});

  final PropertySummary p;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1100;

    final name = Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFEFF8F7), borderRadius: BorderRadius.circular(8)),
        child: Icon(p.type == 'restaurant' ? Icons.restaurant_rounded : Icons.apartment_rounded, size: 16, color: AppTheme.brandTeal),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B))),
          Text([if (p.type.isNotEmpty) p.type, if (p.place.isNotEmpty) p.place].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: AppTheme.adminTextMuted)),
        ]),
      ),
    ]);
    final company = InkWell(
      onTap: () => openCompany(context, p.orgId),
      child: Text(p.orgName.isEmpty ? '—' : p.orgName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: AppTheme.brandTeal, fontWeight: FontWeight.w600)),
    );
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
          onTap: () => showPropertyDetail(context, p.propertyId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: wide
                ? Row(children: [
                    Expanded(flex: 22, child: name),
                    Expanded(flex: 17, child: company),
                    Expanded(flex: 10, child: Align(alignment: Alignment.centerLeft, child: StatusPill(p.status))),
                    Expanded(flex: 9, child: num('Rooms · tables', '${p.rooms} · ${p.tables}')),
                    Expanded(flex: 7, child: num('Staff', '${p.staff}')),
                    Expanded(flex: 12, child: num('Bookings · orders', '${p.bookings30d} · ${p.orders30d}')),
                    Expanded(flex: 7, child: num('Actions', '${p.actions30d}')),
                    Expanded(flex: 11, child: num('Last action', relativeTime(p.lastActivityAt))),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    name,
                    const SizedBox(height: 8),
                    Row(children: [company, const SizedBox(width: 10), StatusPill(p.status)]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 22, runSpacing: 6, children: [
                      num('Rooms · tables', '${p.rooms} · ${p.tables}'),
                      num('Staff', '${p.staff}'),
                      num('Bookings · orders 30d', '${p.bookings30d} · ${p.orders30d}'),
                      num('Last action', relativeTime(p.lastActivityAt)),
                    ]),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text, this.onRetry});

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          Icon(icon, size: 38, color: color),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, height: 1.5)),
          if (onRetry != null) ...[const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))],
        ]),
      );
}
