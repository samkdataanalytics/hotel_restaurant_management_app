import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/organization_service.dart';

class SuperadminDashboard extends StatefulWidget {
  const SuperadminDashboard({super.key});

  @override
  State<SuperadminDashboard> createState() => _SuperadminDashboardState();
}

class _SuperadminDashboardState extends State<SuperadminDashboard> {
  late Future<List<Organization>> _future;

  @override
  void initState() {
    super.initState();
    _future = OrganizationService().getAllOrganizations();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: FutureBuilder<List<Organization>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: AppTheme.danger),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load data',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                        color: AppTheme.adminTextMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() {
                          _future =
                              OrganizationService().getAllOrganizations();
                        }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final orgs = snapshot.data ?? [];
          return _DashboardContent(orgs: orgs);
        },
      ),
    );
  }
}

// ─── Content (extracted to avoid rebuilds) ───────────────────────────────────

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.orgs});

  final List<Organization> orgs;

  @override
  Widget build(BuildContext context) {
    final totalCompanies = orgs.length;
    final totalProperties =
        orgs.fold<int>(0, (sum, o) => sum + o.propertyCount);
    final totalMembers = orgs.fold<int>(0, (sum, o) => sum + o.memberCount);

    final planCounts = <String, int>{};
    for (final org in orgs) {
      planCounts[org.plan] = (planCounts[org.plan] ?? 0) + 1;
    }
    final growthPlan = planCounts['growth'] ?? 0;
    final proPlan = planCounts['pro'] ?? 0;
    final enterprisePlan = planCounts['enterprise'] ?? 0;

    // Trial breakdown derived from trial_ends_at, NOT the stored status column:
    // an idle org keeps a stale 'trialing' value until its owner next logs in
    // (lazy/on-access flip), so we count from the effective state instead.
    final trialActive = orgs.where((o) => o.isTrialing).length;
    final trialExpired =
        orgs.where((o) => o.effectiveStatus == 'trial_expired').length;

    final recentOrgs = [...orgs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent5 = recentOrgs.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Superadmin Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Platform-wide overview across all companies and properties',
            style: TextStyle(fontSize: 14, color: AppTheme.adminTextMuted),
          ),
          const SizedBox(height: 28),

          // KPI Cards
          _KpiRow(
            totalCompanies: totalCompanies,
            totalProperties: totalProperties,
            totalMembers: totalMembers,
            planCounts: planCounts,
          ),
          const SizedBox(height: 28),

          // Plan breakdown + recent companies
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan breakdown card
              SizedBox(
                width: 280,
                child: _PlanBreakdownCard(
                  growthPlan: growthPlan,
                  proPlan: proPlan,
                  enterprisePlan: enterprisePlan,
                  trialActive: trialActive,
                  trialExpired: trialExpired,
                  total: totalCompanies,
                ),
              ),
              const SizedBox(width: 24),
              // Recent companies table
              Expanded(
                child: _RecentCompaniesCard(orgs: recent5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalCompanies,
    required this.totalProperties,
    required this.totalMembers,
    required this.planCounts,
  });

  final int totalCompanies;
  final int totalProperties;
  final int totalMembers;
  final Map<String, int> planCounts;

  @override
  Widget build(BuildContext context) {
    final enterprise = planCounts['enterprise'] ?? 0;
    final pro = planCounts['pro'] ?? 0;
    final revenueLabel = enterprise > 0 || pro > 0
        ? '${enterprise}E + ${pro}P plans'
        : 'No paid plans yet';

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Total Companies',
            value: totalCompanies.toString(),
            icon: Icons.business_rounded,
            accent: AppTheme.adminPrimary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Total Properties',
            value: totalProperties.toString(),
            icon: Icons.apartment_rounded,
            accent: AppTheme.goldPrimary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Total Users',
            value: totalMembers.toString(),
            icon: Icons.people_rounded,
            accent: AppTheme.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Revenue / Plan',
            value: revenueLabel,
            icon: Icons.monetization_on_rounded,
            accent: AppTheme.warning,
            isText: true,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.isText = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isText;

  @override
  Widget build(BuildContext context) {
    return AppTheme.kpiCard(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.adminTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isText ? 14 : 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan Breakdown Card ──────────────────────────────────────────────────────

class _PlanBreakdownCard extends StatelessWidget {
  const _PlanBreakdownCard({
    required this.growthPlan,
    required this.proPlan,
    required this.enterprisePlan,
    required this.trialActive,
    required this.trialExpired,
    required this.total,
  });

  final int growthPlan;
  final int proPlan;
  final int enterprisePlan;
  final int trialActive;
  final int trialExpired;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Companies by Plan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          _PlanRow(
            label: 'Growth',
            count: growthPlan,
            total: total,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          _PlanRow(
            label: 'Pro',
            count: proPlan,
            total: total,
            color: AppTheme.adminPrimary,
          ),
          const SizedBox(height: 12),
          _PlanRow(
            label: 'Enterprise',
            count: enterprisePlan,
            total: total,
            color: AppTheme.goldPrimary,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Trial state — computed from trial_ends_at, not the raw status column.
          _PlanRow(
            label: 'Trials active',
            count: trialActive,
            total: total,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _PlanRow(
            label: 'Trials expired',
            count: trialExpired,
            total: total,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.adminTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.adminTextMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─── Recent Companies Card ────────────────────────────────────────────────────

class _RecentCompaniesCard extends StatelessWidget {
  const _RecentCompaniesCard({required this.orgs});

  final List<Organization> orgs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Companies',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          if (orgs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No companies yet',
                  style: TextStyle(
                      color: AppTheme.adminTextMuted, fontSize: 14),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(2),
                5: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  children: [
                    _tableHeader('Company'),
                    _tableHeader('Country'),
                    _tableHeader('Props'),
                    _tableHeader('Members'),
                    _tableHeader('Plan'),
                    _tableHeader('Status'),
                  ],
                ),
                ...orgs.map((org) => TableRow(
                      children: [
                        _tableCell(org.name, bold: true),
                        _tableCell(org.country),
                        _tableCell(org.propertyCount.toString()),
                        _tableCell(org.memberCount.toString()),
                        _tablePlanCell(org.plan),
                        _tableStatusCell(org.effectiveStatus),
                      ],
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.adminTextMuted,
          ),
        ),
      );

  Widget _tableCell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF1E293B),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _tablePlanCell(String plan) {
    Color color;
    switch (plan.toLowerCase()) {
      case 'enterprise':
        color = AppTheme.goldPrimary;
        break;
      case 'pro':
        color = AppTheme.adminPrimary;
        break;
      default:
        color = Colors.grey.shade500;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: _PlanChip(label: plan, color: color),
    );
  }

  Widget _tableStatusCell(String status) {
    final Color color;
    final String label;
    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.success;
        label = 'Active';
        break;
      case 'trialing':
        color = const Color(0xFFF59E0B);
        label = 'Trialing';
        break;
      case 'trial_expired':
        color = const Color(0xFFEF4444);
        label = 'Trial expired';
        break;
      default: // suspended
        color = AppTheme.danger;
        label = status;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: _StatusChip(label: label, color: color),
    );
  }
}

// ─── Shared chip widgets ──────────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
