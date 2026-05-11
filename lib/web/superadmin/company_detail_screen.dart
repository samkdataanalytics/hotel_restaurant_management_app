import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/organization_service.dart';

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({super.key, required this.org});

  final Organization org;

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<OrgProperty>> _propertiesFuture;
  late Future<List<OrgMember>> _membersFuture;

  late String _currentStatus;
  bool _isUpdating  = false;
  bool _isDeleting  = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentStatus = widget.org.status;
    _loadData();
  }

  void _loadData() {
    final svc = OrganizationService();
    _propertiesFuture = svc.getOrgProperties(widget.org.id);
    _membersFuture = svc.getOrganizationMembers(widget.org.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Status action ─────────────────────────────────────────────────────────

  Future<void> _toggleStatus() async {
    final targetStatus =
        _currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
    final action =
        targetStatus == 'suspended' ? 'Suspend' : 'Activate';
    final actionColor =
        targetStatus == 'suspended' ? AppTheme.danger : AppTheme.success;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action Company?'),
        content: Text(
          targetStatus == 'suspended'
              ? 'Suspending "${widget.org.name}" will prevent its users from accessing the platform. You can reactivate it at any time.'
              : 'This will restore access to "${widget.org.name}" and allow its users to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: actionColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await OrganizationService()
          .updateOrgStatus(widget.org.id, targetStatus);
      if (!mounted) return;
      setState(() {
        _currentStatus = targetStatus;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Company ${targetStatus == 'active' ? 'activated' : 'suspended'} successfully'),
          backgroundColor:
              targetStatus == 'active' ? AppTheme.success : AppTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // ─── Delete action ─────────────────────────────────────────────────────────

  Future<void> _deleteCompany() async {
    final confirmCtrl = TextEditingController();
    final orgName     = widget.org.name;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 10),
            const Text('Delete Company Permanently?'),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will permanently delete:',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.danger)),
                      const SizedBox(height: 6),
                      const Text('• All properties (hotels)\n• All rooms, bookings, check-ins\n• All restaurant data (orders, menus, tables)\n• All staff accounts & schedules\n• All expenses, guests & financial records\n• The organisation and all its members',
                          style: TextStyle(fontSize: 12, height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Type  "$orgName"  to confirm:',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  onChanged: (_) => setS(() {}),
                  decoration: InputDecoration(
                    hintText: orgName,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: confirmCtrl.text.trim() == orgName
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    confirmCtrl.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await OrganizationService().deleteOrganization(widget.org.id);
      if (!mounted) return;
      Navigator.of(context).pop(true); // close dialog, signal list to refresh
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.org.name}" and all its data have been deleted.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, minWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Flexible(
              child: _buildTabViews(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final created =
        '${widget.org.createdAt.day.toString().padLeft(2, '0')}/'
        '${widget.org.createdAt.month.toString().padLeft(2, '0')}/'
        '${widget.org.createdAt.year}';

    final isActive = _currentStatus.toLowerCase() == 'active';
    final statusColor = isActive ? AppTheme.success : AppTheme.danger;

    Color planColor;
    switch (widget.org.plan.toLowerCase()) {
      case 'enterprise':
        planColor = AppTheme.goldPrimary;
        break;
      case 'pro':
        planColor = AppTheme.adminPrimary;
        break;
      default:
        planColor = Colors.grey.shade500;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.sidebarDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.adminPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.adminPrimary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                widget.org.name.isNotEmpty
                    ? widget.org.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.adminPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.org.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _HeaderChip(
                        label: widget.org.plan.toUpperCase(),
                        color: planColor),
                    const SizedBox(width: 8),
                    _HeaderChip(
                        label: _currentStatus,
                        color: statusColor),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      'Since $created',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.public_rounded,
                        size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      widget.org.country,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.adminPrimary,
        unselectedLabelColor: AppTheme.adminTextMuted,
        indicatorColor: AppTheme.adminPrimary,
        indicatorWeight: 2,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment_rounded, size: 16),
                SizedBox(width: 8),
                Text('Properties'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_rounded, size: 16),
                SizedBox(width: 8),
                Text('Members'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab views ────────────────────────────────────────────────────────────

  Widget _buildTabViews() {
    return SizedBox(
      height: 420,
      child: TabBarView(
        controller: _tabController,
        children: [
          _PropertiesTab(future: _propertiesFuture),
          _MembersTab(future: _membersFuture),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final isActive = _currentStatus.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            'ID: ${widget.org.id}',
            style: TextStyle(fontSize: 11, color: AppTheme.adminTextMuted),
          ),
          const Spacer(),
          // Delete — separated on the left of the action cluster
          OutlinedButton.icon(
            onPressed: (_isDeleting || _isUpdating) ? null : _deleteCompany,
            icon: _isDeleting
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_rounded, size: 15),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: AppTheme.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppTheme.danger : AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: _isUpdating ? null : _toggleStatus,
            icon: _isUpdating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
            label: Text(isActive ? 'Suspend Company' : 'Activate Company'),
          ),
        ],
      ),
    );
  }
}

// ─── Properties Tab ───────────────────────────────────────────────────────────

class _PropertiesTab extends StatelessWidget {
  const _PropertiesTab({required this.future});

  final Future<List<OrgProperty>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrgProperty>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading properties: ${snapshot.error}',
              style: TextStyle(color: AppTheme.danger),
            ),
          );
        }
        final props = snapshot.data ?? [];
        if (props.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No properties registered',
                  style: TextStyle(
                      color: AppTheme.adminTextMuted, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: props.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PropertyCard(property: props[i]),
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final OrgProperty property;

  @override
  Widget build(BuildContext context) {
    final isActive = property.status.toLowerCase() == 'active';
    final statusColor = isActive ? AppTheme.success : AppTheme.danger;

    Color typeColor;
    switch (property.type.toLowerCase()) {
      case 'hotel':
        typeColor = AppTheme.adminPrimary;
        break;
      case 'resort':
        typeColor = AppTheme.goldPrimary;
        break;
      case 'hostel':
        typeColor = AppTheme.warning;
        break;
      default:
        typeColor = Colors.grey.shade500;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.apartment_rounded, color: typeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${property.city}, ${property.country}',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.adminTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TypeChip(label: property.type, color: typeColor),
          const SizedBox(width: 8),
          _MiniStatusChip(
              label: property.status, color: statusColor),
        ],
      ),
    );
  }
}

// ─── Members Tab ─────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.future});

  final Future<List<OrgMember>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrgMember>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading members: ${snapshot.error}',
              style: TextStyle(color: AppTheme.danger),
            ),
          );
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No members found',
                  style: TextStyle(
                      color: AppTheme.adminTextMuted, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: members.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.grey.shade100,
          ),
          itemBuilder: (_, i) => _MemberRow(member: members[i]),
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final OrgMember member;

  @override
  Widget build(BuildContext context) {
    Color roleColor;
    switch (member.role.toLowerCase()) {
      case 'owner':
        roleColor = AppTheme.goldPrimary;
        break;
      case 'admin':
        roleColor = AppTheme.adminPrimary;
        break;
      case 'manager':
        roleColor = AppTheme.warning;
        break;
      default:
        roleColor = Colors.grey.shade500;
    }

    final initials = _initials(member.fullName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.adminTextMuted),
                ),
              ],
            ),
          ),
          _RoleChip(role: member.role, color: roleColor),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

// ─── Small shared widgets ─────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
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
