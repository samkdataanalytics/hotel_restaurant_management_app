import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/platform_tracking_service.dart';
import '../../../services/user_tracking_service.dart';
import '../users/activity_list.dart';
import '../users/users_format.dart';
import 'tracking_links.dart';
import 'tracking_widgets.dart';

Future<void> showPropertyDetail(BuildContext context, String propertyId) => showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 780),
          child: PropertyDetailView(propertyId: propertyId),
        ),
      ),
    );

/// One property: its details, its people, what it holds, what happens in it.
class PropertyDetailView extends ConsumerStatefulWidget {
  const PropertyDetailView({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<PropertyDetailView> createState() => _PropertyDetailViewState();
}

class _PropertyDetailViewState extends ConsumerState<PropertyDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  late Future<PropertyInsight> _future = ref.read(platformTrackingServiceProvider).propertyDetail(widget.propertyId);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PropertyInsight>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          final s = snap.error.toString();
          final missing = s.contains('superadmin_property_detail') || s.contains('PGRST202') || s.contains('42883');
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.danger),
                const SizedBox(height: 10),
                Text(
                  missing
                      ? 'The property insight functions are not installed on this database yet. Apply '
                          'supabase/migrations/20261023000004_superadmin_companies_properties.sql, then retry.'
                      : 'Could not load this property: $s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _future = ref.read(platformTrackingServiceProvider).propertyDetail(widget.propertyId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final p = snap.data!;
        return Column(
          children: [
            _Header(p: p),
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.brandTeal,
              unselectedLabelColor: AppTheme.adminTextMuted,
              indicatorColor: AppTheme.brandTeal,
              tabs: [
                const Tab(text: 'Overview'),
                Tab(text: 'People (${p.staff.length + p.companyAccess.length})'),
                const Tab(text: 'Bookings & orders'),
                Tab(text: 'Activity (${p.activityTotal})'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _Overview(p: p),
                  _People(p: p),
                  _Operations(p: p),
                  SingleChildScrollView(padding: const EdgeInsets.all(20), child: ActivityList(propertyId: widget.propertyId)),
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
  const _Header({required this.p});

  final PropertyInsight p;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEFF8F7), borderRadius: BorderRadius.circular(12)),
              child: Icon(p.type == 'restaurant' ? Icons.restaurant_rounded : Icons.apartment_rounded, color: AppTheme.brandTeal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('${p.type.isEmpty ? 'Property' : p.type[0].toUpperCase() + p.type.substring(1)} of ', style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
                      InkWell(
                        onTap: () => openCompany(context, p.orgId),
                        child: Text(p.orgName, style: TextStyle(fontSize: 13, color: AppTheme.brandTeal, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Wrap(spacing: 6, children: [
              StatusPill(p.isDeleted ? 'deleted' : p.status),
              if (p.orgStatus.isNotEmpty) TPill('company ${StatusPill.labelOf(p.orgStatus)}', color: StatusPill.colorOf(p.orgStatus)),
            ]),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
          ],
        ),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.p});

  final PropertyInsight p;

  @override
  Widget build(BuildContext context) {
    final cur = p.currency;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            TStat(label: 'Bookings (30d)', value: '${p.total('bookings_30d')}', sub: '${p.total('bookings')} in total', icon: Icons.event_available_rounded, color: AppTheme.brandTeal, width: 190),
            TStat(label: 'Orders (30d)', value: '${p.total('orders_30d')}', sub: '${p.total('orders')} in total', icon: Icons.restaurant_rounded, color: const Color(0xFFF97316), width: 190),
            TStat(label: 'Paid bookings (30d)', value: money(p.total('paid_value_30d'), cur), icon: Icons.payments_rounded, color: AppTheme.statusGreen, width: 210),
            TStat(label: 'Expenses (30d)', value: money(p.total('expenses_30d'), cur), icon: Icons.receipt_long_rounded, color: const Color(0xFF64748B), width: 210),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
            TCard(title: 'Details', width: 430, children: [
              TFact('Company', p.orgName, onTap: () => openCompany(context, p.orgId)),
              TFact('Type', p.type),
              TFact('Address', [p.address, p.city, p.country].where((x) => x.isNotEmpty).join(', ')),
              TFact('Phone', p.phone),
              TFact('Email', p.email),
              TFact('Time zone', p.timezone),
              TFact('Currency', p.currency),
              TFact('Booking channels', p.bookingChannels.join(', ')),
              TFact('Created', fullTime(p.createdAt)),
              TFact('Property id', p.propertyId, mono: true),
            ]),
            TCard(title: 'Settings', width: 430, children: [
              if (p.settings.isEmpty) const TMuted('No settings row.'),
              if (p.settings.isNotEmpty) ...[
                TFact('Tax rate', '${p.settings['tax_rate'] ?? '—'}'),
                TFact('Service charge', '${p.settings['service_charge_rate'] ?? '—'}'),
                TFact('Currency symbol', '${p.settings['currency_symbol'] ?? '—'}'),
              ],
              const Divider(height: 22),
              const Text('Rooms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
              const SizedBox(height: 6),
              CountChips(p.roomsByStatus, empty: 'No rooms'),
              const SizedBox(height: 12),
              const Text('Restaurant tables', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
              const SizedBox(height: 6),
              CountChips(p.tablesByStatus, empty: 'No tables'),
              const SizedBox(height: 12),
              TFact('Menu items', '${p.total('menu_items')}'),
            ]),
            TCard(title: 'What happens here (30 days)', width: 430, children: [
              TallyBars(rows: [for (final a in p.activityCounts) (ActivityLabels.label(a.action), a.count)]),
              if (p.firstActivityAt != null) ...[
                const Divider(height: 22),
                TFact('First recorded', fullTime(p.firstActivityAt)),
                TFact('Last action', p.lastActivityAt == null ? '—' : relativeTime(p.lastActivityAt)),
              ],
            ]),
            if (p.expensesByCategory.isNotEmpty)
              TCard(title: 'Expenses by category (30 days)', width: 430, children: [
                for (final e in p.expensesByCategory.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12.5))),
                      Text(money(e.value, cur), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
              ]),
          ]),
        ],
      ),
    );
  }
}

class _People extends StatelessWidget {
  const _People({required this.p});

  final PropertyInsight p;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
          TCard(title: 'Assigned to this property (${p.staff.length})', width: 440, children: [
            if (p.staff.isEmpty) const TMuted('Nobody is assigned directly. Company owners and managers still have access.'),
            for (final s in p.staff) PersonRow(person: s, onTap: () => openUser(context, s.userId)),
          ]),
          TCard(title: 'Company owners and managers (${p.companyAccess.length})', width: 440, children: [
            const TMuted('They can open every property in the company.'),
            const SizedBox(height: 10),
            for (final s in p.companyAccess) PersonRow(person: s, onTap: () => openUser(context, s.userId)),
          ]),
        ]),
      );
}

class _Operations extends StatelessWidget {
  const _Operations({required this.p});

  final PropertyInsight p;

  @override
  Widget build(BuildContext context) {
    final cur = p.currency;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TMuted('Guest names and contact details are not shown here; bookings are identified by reference.'),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
            TCard(title: 'Bookings by status', width: 440, children: [CountChips(p.bookingsByStatus, empty: 'No bookings')]),
            TCard(title: 'Orders by status', width: 440, children: [CountChips(p.ordersByStatus, empty: 'No orders')]),
          ]),
          const SizedBox(height: 16),
          TCard(title: 'Latest bookings', children: [
            if (p.recentBookings.isEmpty) const TMuted('No bookings yet.'),
            for (final b in p.recentBookings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 110, child: Text(b.ref, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                  StatusPill(b.status),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${shortDate(b.checkIn)} → ${shortDate(b.checkOut)}${b.source.isEmpty ? '' : '  ·  ${b.source}'}', style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted))),
                  Text(money(b.amount, cur), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  TPill(b.paid ? 'paid' : 'unpaid', color: b.paid ? AppTheme.statusGreen : AppTheme.statusAmber),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          TCard(title: 'Latest restaurant orders', children: [
            if (p.recentOrders.isEmpty) const TMuted('No orders yet.'),
            for (final o in p.recentOrders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 110, child: Text(o.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                  StatusPill(o.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${o.type}${o.room.isEmpty ? '' : ' · room ${o.room}'} · ${o.items} item${o.items == 1 ? '' : 's'} · ${relativeTime(o.createdAt)}',
                        style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                  ),
                  if (o.paymentStatus.isNotEmpty) TPill(o.paymentStatus),
                ]),
              ),
          ]),
        ],
      ),
    );
  }
}
