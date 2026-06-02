import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/organization_service.dart';
import 'company_detail_screen.dart';

class CompaniesListScreen extends StatefulWidget {
  const CompaniesListScreen({super.key});

  @override
  State<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends State<CompaniesListScreen> {
  late Future<List<Organization>> _future;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = OrganizationService().getAllOrganizations();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = OrganizationService().getAllOrganizations();
    });
  }

  List<Organization> _filtered(List<Organization> orgs) {
    if (_searchQuery.isEmpty) return orgs;
    return orgs
        .where((o) => o.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
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
                          'Failed to load companies',
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
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final orgs = _filtered(snapshot.data ?? []);
                return _buildTable(orgs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Companies',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage all registered organizations on the platform',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.adminTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: AppTheme.adminTextMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            color: AppTheme.adminTextMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Organization> orgs) {
    if (orgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No companies found'
                  : 'No results for "$_searchQuery"',
              style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.adminTextMuted,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: AppTheme.cardDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 20,
              columnSpacing: 24,
              headingRowHeight: 48,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 72,
              columns: [
                DataColumn(
                  label: Text('Company',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                ),
                DataColumn(
                  label: Text('Plan',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                ),
                DataColumn(
                  label: Text('Properties',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('Members',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('Created',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                ),
                DataColumn(
                  label: Text('Status',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adminTextMuted)),
                ),
              ],
              rows: orgs.map((org) => _buildRow(context, org)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, Organization org) {
    final created =
        '${org.createdAt.day.toString().padLeft(2, '0')}/'
        '${org.createdAt.month.toString().padLeft(2, '0')}/'
        '${org.createdAt.year}';

    return DataRow(
      onSelectChanged: (_) => _openDetail(context, org),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.adminPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    org.name.isNotEmpty
                        ? org.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.adminPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    org.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                  ),
                  Text(
                    org.country,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.adminTextMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(_PlanChip(plan: org.plan)),
        DataCell(Text(
          org.propertyCount.toString(),
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
        )),
        DataCell(Text(
          org.memberCount.toString(),
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
        )),
        DataCell(Text(
          created,
          style:
              TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
        )),
        DataCell(_StatusChip(status: org.effectiveStatus)),
      ],
    );
  }

  void _openDetail(BuildContext context, Organization org) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => CompanyDetailScreen(org: org),
    );
    if (deleted == true) _refresh();
  }
}

// ─── Plan Chip ────────────────────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
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
        label = 'Suspended';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(width: 5),
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
