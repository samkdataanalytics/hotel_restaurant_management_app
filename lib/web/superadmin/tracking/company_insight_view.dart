import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../../../providers/service_providers.dart';
import '../../../services/platform_tracking_service.dart';
import '../../../services/user_tracking_service.dart';
import '../users/users_format.dart';
import 'tracking_links.dart';
import 'tracking_widgets.dart';

/// Everything about a company in one scrollable view: how it is doing against its
/// plan, who is in it, what it runs, what it has paid, and what its people do.
class CompanyInsightView extends ConsumerStatefulWidget {
  const CompanyInsightView({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<CompanyInsightView> createState() => _CompanyInsightViewState();
}

class _CompanyInsightViewState extends ConsumerState<CompanyInsightView> {
  late Future<CompanyInsight> _future = ref.read(platformTrackingServiceProvider).companyDetail(widget.orgId);

  void _retry() => setState(() => _future = ref.read(platformTrackingServiceProvider).companyDetail(widget.orgId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyInsight>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) return _Failed(error: snap.error!, onRetry: _retry);
        return _Body(c: snap.data!);
      },
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = error.toString();
    final missing = s.contains('superadmin_company_detail') || s.contains('PGRST202') || s.contains('42883');
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 36, color: AppTheme.danger),
          const SizedBox(height: 10),
          Text(
            missing
                ? 'The company insight functions are not installed on this database yet. Apply '
                    'supabase/migrations/20261023000004_superadmin_companies_properties.sql, then retry.'
                : 'Could not load this company: $s',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.c});

  final CompanyInsight c;

  @override
  Widget build(BuildContext context) {
    final trialLeft = c.trialEndsAt == null ? null : c.trialEndsAt!.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TStat(label: 'Properties', value: '${c.properties.length}', icon: Icons.apartment_rounded, color: AppTheme.statusBlue, width: 170),
              TStat(label: 'Members', value: '${c.members.length}', icon: Icons.groups_rounded, color: AppTheme.statusPurple, width: 170),
              TStat(label: 'Bookings (30d)', value: '${c.total('bookings_30d')}', sub: '${c.total('bookings')} in total', icon: Icons.event_available_rounded, color: AppTheme.brandTeal, width: 190),
              TStat(label: 'Orders (30d)', value: '${c.total('orders_30d')}', sub: '${c.total('orders')} in total', icon: Icons.restaurant_rounded, color: const Color(0xFFF97316), width: 190),
              TStat(label: 'Paid bookings', value: money(c.total('paid_bookings_value')), icon: Icons.payments_rounded, color: AppTheme.statusGreen, width: 190),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              TCard(title: 'Plan and usage', width: 400, children: [
                Row(children: [
                  Text(c.plan.isEmpty ? 'No plan' : '${c.plan[0].toUpperCase()}${c.plan.substring(1)} plan', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 8),
                  StatusPill(c.status),
                ]),
                const SizedBox(height: 12),
                LimitMeter(label: 'Properties', limit: c.limits['properties']!),
                LimitMeter(label: 'Team members', limit: c.limits['users']!),
                LimitMeter(label: 'Rooms', limit: c.limits['rooms']!),
                LimitMeter(label: 'Restaurant tables', limit: c.limits['tables']!),
              ]),
              TCard(title: 'Account', width: 400, children: [
                TFact('Created', fullTime(c.createdAt)),
                if (c.createdByName.isNotEmpty || c.createdByEmail.isNotEmpty) TFact('Created by', c.createdByName.isNotEmpty ? c.createdByName : c.createdByEmail),
                if (c.status == 'trialing' && trialLeft != null) TFact('Trial ends', '${shortDate(c.trialEndsAt)}  ($trialLeft days left)'),
                if (c.status == 'trial_expired') TFact('Trial ended', shortDate(c.trialEndsAt)),
                TFact('Billing', c.billingCycle.isEmpty ? '—' : c.billingCycle),
                TFact('Subscription paid', c.subscriptionPaidAt == null ? 'No' : shortDate(c.subscriptionPaidAt)),
                TFact('Email', c.email),
                TFact('Phone', c.phone),
                TFact('Country', c.country),
                TFact('Pending invites', '${c.total('pending_invites')}'),
                TFact('Expenses recorded', money(c.total('expenses_value'))),
                TFact('Company id', c.orgId, mono: true),
              ]),
              TCard(title: 'Properties (${c.properties.length})', width: 400, children: [
                if (c.properties.isEmpty) const TMuted('No properties yet.'),
                for (final p in c.properties)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => openProperty(context, p.propertyId),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(
                                    '${p.type} · ${p.rooms} rooms · ${p.tables} tables · ${p.bookings30d} bookings · ${p.orders30d} orders (30d)\nlast action ${relativeTime(p.lastActivityAt)}',
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.adminTextMuted, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(p.status),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ]),
              TCard(title: 'Members (${c.members.length})', width: 400, children: [
                if (c.members.isEmpty) const TMuted('No members.'),
                for (final m in c.members) PersonRow(person: m, onTap: () => openUser(context, m.userId)),
              ]),
              TCard(title: 'Payments', width: 400, children: [
                if (c.payments.isEmpty) const TMuted('No payment attempts.'),
                for (final p in c.payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${p.plan}${p.cycle.isEmpty ? '' : ' · ${p.cycle}'}\n${shortDate(p.createdAt)}${p.payer.isEmpty ? '' : ' · ${p.payer}'}',
                              style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        ),
                        Text(money(p.amount, p.currency), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 8),
                        StatusPill(p.status),
                      ],
                    ),
                  ),
              ]),
              TCard(title: 'What its people did (30 days)', width: 400, children: [
                TallyBars(rows: [for (final a in c.activityCounts) (ActivityLabels.label(a.action), a.count)]),
                if (c.firstActivityAt != null) ...[
                  const Divider(height: 22),
                  TFact('First recorded', fullTime(c.firstActivityAt)),
                  TFact('Last action', c.lastActivityAt == null ? '—' : relativeTime(c.lastActivityAt)),
                  TFact('All time', '${c.activityTotal} entries'),
                ],
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
