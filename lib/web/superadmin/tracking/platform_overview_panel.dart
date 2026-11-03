import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/platform_tracking_service.dart';
import '../users/users_format.dart';
import 'tracking_links.dart';
import 'tracking_widgets.dart';

/// The platform's pulse, for the dashboard: how much is happening, where, and
/// what needs attention. Loads on its own and never breaks the dashboard: if the
/// functions are missing it says so in one line.
class PlatformOverviewPanel extends ConsumerStatefulWidget {
  const PlatformOverviewPanel({super.key});

  @override
  ConsumerState<PlatformOverviewPanel> createState() => _PlatformOverviewPanelState();
}

class _PlatformOverviewPanelState extends ConsumerState<PlatformOverviewPanel> {
  late Future<PlatformOverview> _future = ref.read(platformTrackingServiceProvider).overview();

  void _reload() => setState(() => _future = ref.read(platformTrackingServiceProvider).overview());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformOverview>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          final s = snap.error.toString();
          final missing = s.contains('superadmin_platform_overview') || s.contains('PGRST202') || s.contains('42883');
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missing
                      ? 'Platform activity needs supabase/migrations/20261023000004_superadmin_companies_properties.sql applied to this database.'
                      : 'Could not load platform activity: $s',
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ]),
          );
        }
        return _Body(o: snap.data!, onRefresh: _reload);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.o, required this.onRefresh});

  final PlatformOverview o;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Platform activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const Spacer(),
          IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, size: 20)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          TStat(label: 'Registered users', value: '${o.users}', sub: '${o.usersActive7d} active this week', icon: Icons.people_alt_rounded, color: AppTheme.statusBlue),
          TStat(label: 'Actions today', value: '${o.actions24h}', sub: '${o.actions7d} this week', icon: Icons.bolt_rounded, color: AppTheme.brandTeal),
          TStat(label: 'Bookings (30d)', value: '${o.bookings30d}', sub: '${o.bookings} in total', icon: Icons.event_available_rounded, color: AppTheme.statusGreen),
          TStat(label: 'Orders (30d)', value: '${o.orders30d}', sub: '${o.orders} in total', icon: Icons.restaurant_rounded, color: const Color(0xFFF97316)),
          TStat(label: 'Paid bookings (30d)', value: money(o.paidValue30d), icon: Icons.payments_rounded, color: AppTheme.statusPurple),
          TStat(label: 'Subscriptions (30d)', value: money(o.paid30d), sub: '${o.paidCount} paid, ${o.pendingPayments} pending', icon: Icons.credit_score_rounded, color: const Color(0xFF0891B2)),
          TStat(label: 'Companies with no activity', value: '${o.dormant30d}', sub: 'in the last 30 days', icon: Icons.bedtime_outlined, color: o.dormant30d > 0 ? AppTheme.statusAmber : const Color(0xFF64748B)),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
          TCard(title: 'Last 14 days', width: 460, children: [
            DailyBars(points: o.daily),
            const SizedBox(height: 10),
            const Row(children: [
              _Legend(color: Color(0xFF0A7D77), label: 'Actions'),
              SizedBox(width: 16),
              _Legend(color: Color(0xFF2563EB), label: 'Sign-ins'),
              SizedBox(width: 16),
              _Legend(color: Color(0xFFF59E0B), label: 'Sign-ups'),
            ]),
          ]),
          TCard(title: 'Busiest companies (30 days)', width: 340, children: [
            if (o.busiest.isEmpty) const TMuted('No recorded actions yet.'),
            for (final b in o.busiest)
              InkWell(
                onTap: () => openCompany(context, b.orgId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(b.name, style: TextStyle(fontSize: 13, color: AppTheme.brandTeal, fontWeight: FontWeight.w700))),
                    Text('${b.value} actions', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                ),
              ),
          ]),
          TCard(title: 'Trials ending within 7 days', width: 340, children: [
            if (o.trialsEnding.isEmpty) const TMuted('None.'),
            for (final t in o.trialsEnding)
              InkWell(
                onTap: () => openCompany(context, t.orgId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(t.name, style: TextStyle(fontSize: 13, color: AppTheme.brandTeal, fontWeight: FontWeight.w700))),
                    Text(t.at == null ? '' : shortDate(t.at), style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
          TCard(title: 'Companies', width: 460, children: [
            const Text('By status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            const SizedBox(height: 6),
            CountChips(o.companiesByStatus),
            const SizedBox(height: 12),
            const Text('By plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final e in o.companiesByPlan.entries) TPill('${e.key}  ${e.value}')]),
            const SizedBox(height: 12),
            Text('${o.companiesNew30d} new in 30 days  ·  ${o.companiesDeleted} deleted', style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
          ]),
          TCard(title: 'Properties', width: 340, children: [
            Text('${o.properties} in total, ${o.propertiesActive} active', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            CountChips(o.propertiesByType),
            const SizedBox(height: 10),
            Text('${o.rooms} rooms and ${o.tables} restaurant tables', style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
          ]),
        ]),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
      ]);
}

/// Three small bars per day, scaled together so a quiet day looks quiet.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.points});

  final List<DayPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const TMuted('No data yet.');
    final max = points.fold<int>(1, (m, p) {
      final v = [p.actions, p.signIns, p.signups].reduce((a, b) => a > b ? a : b);
      return v > m ? v : m;
    });
    const h = 96.0;

    return SizedBox(
      height: h + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Tooltip(
                message: '${shortDate(p.day)}\n${p.actions} actions · ${p.signIns} sign-ins · ${p.signups} sign-ups',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: h,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Bar(value: p.actions, max: max, height: h, color: const Color(0xFF0A7D77)),
                          _Bar(value: p.signIns, max: max, height: h, color: const Color(0xFF2563EB)),
                          _Bar(value: p.signups, max: max, height: h, color: const Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${p.day.day}', style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.height, required this.color});

  final int value;
  final int max;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        height: value == 0 ? 1.5 : (value / max * height).clamp(3.0, height),
        decoration: BoxDecoration(color: value == 0 ? const Color(0xFFE2E8F0) : color, borderRadius: BorderRadius.circular(2)),
      );
}
