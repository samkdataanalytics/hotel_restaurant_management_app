import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../models/staff_permission.dart';
import '../providers/app_auth_provider.dart';
import '../services/staff_service.dart';
import '../services/organization_service.dart';
import 'widgets/upgrade_plan_dialog.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState
    extends ConsumerState<UsersManagementScreen> {
  final _staffService = StaffService();
  List<PropertyStaffMember> _staff = [];
  bool _isLoading = true;
  bool _isHotel = true;
  bool _isRestaurant = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final property = ref.read(activePropertyProvider);
    if (property == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isHotel = property.isHotel;
      _isRestaurant = property.isRestaurant;
    });

    final staff = await _staffService.getPropertyStaff(property.id);
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _isLoading = false;
    });
  }

  void _showPlanLimitDialog() {
    showUpgradePlanDialog(context, ref, blockedResource: 'team members');
  }

  Future<void> _addMember() async {
    final property = ref.read(activePropertyProvider);
    final authState = ref.read(authProvider).valueOrNull;
    if (property == null || authState?.organization == null) return;

    final orgId = authState!.organization!.id;
    final canAdd = await OrganizationService().canAddStaff(orgId);
    if (!canAdd && mounted) {
      _showPlanLimitDialog();
      return;
    }
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStaffDialog(
        propertyId:    property.id,
        orgId:         authState!.organization!.id,
        isHotel:       _isHotel,
        isRestaurant:  _isRestaurant,
        orgProperties: authState.properties,
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _resetPassword(PropertyStaffMember member) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ResetPasswordDialog(member: member),
    );
  }

  Future<void> _editPermissions(PropertyStaffMember member) async {
    final property = ref.read(activePropertyProvider);
    if (property == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditPermissionsDialog(
        member: member,
        propertyId: property.id,
        isHotel: _isHotel,
        isRestaurant: _isRestaurant,
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _removeMember(PropertyStaffMember member) async {
    final property = ref.read(activePropertyProvider);
    if (property == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Remove "${member.fullName}" from this property? They will lose all access.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _staffService.removeStaffMember(property.id, member.userId);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeRole(PropertyStaffMember member) async {
    final property = ref.read(activePropertyProvider);
    if (property == null) return;

    final newRole = member.isManager ? 'staff' : 'manager';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          member.isManager ? 'Demote to Staff?' : 'Promote to Manager?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          member.isManager
              ? '"${member.fullName}" will lose full access and revert to staff-level permissions.'
              : '"${member.fullName}" will get full access to all sections and team management.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: member.isManager ? AppTheme.warning : AppTheme.adminPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(member.isManager ? 'Demote' : 'Promote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _staffService.setStaffRole(property.id, member.userId, newRole);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change role: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _assignToProperty(PropertyStaffMember member) async {
    final property = ref.read(activePropertyProvider);
    final authState = ref.read(authProvider).valueOrNull;
    if (property == null) return;

    final otherProperties = (authState?.properties ?? [])
        .where((p) => p.id != property.id)
        .toList();

    if (otherProperties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other properties in your organization.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignToPropertyDialog(
        member:          member,
        currentPropertyId: property.id,
        otherProperties: otherProperties,
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _revokeAllAccess(PropertyStaffMember member) async {
    final property = ref.read(activePropertyProvider);
    if (property == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke All Access',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Set all section privileges to "None" for "${member.fullName}"?\n\n'
            'They will remain in the team but lose access to every section.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final allKeys = [
        if (_isHotel) ...kHotelSectionKeys,
        if (_isRestaurant) ...kRestaurantSectionKeys,
      ];
      final nonePerms = {
        for (final k in allKeys) k: PrivilegeLevel.none,
      };
      await _staffService.updateStaffPermissions(
          property.id, member.userId, nonePerms);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to revoke access: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const TableListSkeleton(rowCount: 7, cellCount: 4);

    final isOwner = ref.watch(isPropertyOwnerProvider);
    // Managers don't see the hotel owner in the team list
    final visibleStaff = isOwner
        ? _staff
        : _staff.where((m) => !m.isPropertyOwner).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: AppTheme.screenPad(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Team Members',
                          style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Manage staff access and per-section privileges for this property.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_rounded,
                      size: 20, color: Colors.white),
                  label: const Text('Add Member',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Staff list card ──────────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              margin: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                            bottom:
                                BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text('MEMBER', style: _headerStyle())),
                          Expanded(
                              flex: 2,
                              child: Text('ACCESS', style: _headerStyle())),
                          Expanded(
                              flex: 2,
                              child: Text('SECTIONS WITH ACCESS',
                                  style: _headerStyle())),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    if (visibleStaff.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 48,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No team members yet.',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click "Add Member" to create a staff account.',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...visibleStaff.map((m) => _buildMemberRow(m, isOwner: isOwner)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(PropertyStaffMember member, {required bool isOwner}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + name/email
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Avatar(initials: member.initials, isManager: member.isManager),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.fullName.isEmpty ? '—' : member.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.adminTextMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Role badge
          Expanded(
            flex: 2,
            child: member.isManager
                ? _Chip(
                    label: 'Full Access',
                    color: AppTheme.adminPrimary,
                    icon: Icons.shield_rounded)
                : member.accessCount == 0
                    ? _Chip(
                        label: 'No Access',
                        color: Colors.grey.shade500,
                        icon: Icons.block_rounded)
                    : _Chip(
                        label:
                            '${member.accessCount} section${member.accessCount == 1 ? '' : 's'}',
                        color: AppTheme.success,
                        icon: Icons.check_circle_rounded),
          ),

          // Sections summary
          Expanded(
            flex: 2,
            child: member.isManager
                ? Text('All sections',
                    style: TextStyle(
                        color: AppTheme.adminTextMuted, fontSize: 13))
                : member.accessCount == 0
                    ? Text('—',
                        style: TextStyle(color: AppTheme.adminTextMuted))
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: member.permissions.entries
                            .where((e) => e.value != PrivilegeLevel.none)
                            .map((e) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: e.value == PrivilegeLevel.edit
                                        ? AppTheme.warning
                                            .withValues(alpha: 0.12)
                                        : AppTheme.adminPrimary
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    kSectionLabel[e.key] ?? e.key,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          e.value == PrivilegeLevel.edit
                                              ? AppTheme.warning
                                              : AppTheme.adminPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
          ),

          // Actions — available for all members
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: Color(0xFF94A3B8)),
              tooltip: 'Actions',
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              offset: const Offset(-160, 8),
              onSelected: (value) {
                switch (value) {
                  case 'role':
                    _changeRole(member);
                    break;
                  case 'edit':
                    _editPermissions(member);
                    break;
                  case 'reset':
                    _resetPassword(member);
                    break;
                  case 'revoke':
                    _revokeAllAccess(member);
                    break;
                  case 'assign':
                    _assignToProperty(member);
                    break;
                  case 'remove':
                    _removeMember(member);
                    break;
                }
              },
              itemBuilder: (_) => [
                // Change role — owner only
                if (isOwner) ...[
                  PopupMenuItem(
                    value: 'role',
                    child: Row(children: [
                      Icon(
                        member.isManager
                            ? Icons.arrow_downward_rounded
                            : Icons.shield_rounded,
                        size: 17,
                        color: member.isManager
                            ? AppTheme.warning
                            : AppTheme.goldPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        member.isManager
                            ? 'Demote to Staff'
                            : 'Promote to Manager',
                        style: TextStyle(
                          color: member.isManager
                              ? AppTheme.warning
                              : AppTheme.goldPrimary,
                        ),
                      ),
                    ]),
                  ),
                  const PopupMenuDivider(),
                ],
                // Staff-only actions
                if (!member.isManager) ...[
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.tune_rounded,
                          size: 17, color: AppTheme.adminPrimary),
                      const SizedBox(width: 10),
                      const Text('Edit Permissions'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'revoke',
                    child: Row(children: [
                      Icon(Icons.block_rounded,
                          size: 17, color: AppTheme.warning),
                      const SizedBox(width: 10),
                      Text('Revoke All Access',
                          style: TextStyle(color: AppTheme.warning)),
                    ]),
                  ),
                ],
                PopupMenuItem(
                  value: 'reset',
                  child: Row(children: [
                    Icon(Icons.lock_reset_rounded,
                        size: 17, color: AppTheme.adminPrimary),
                    const SizedBox(width: 10),
                    const Text('Reset Password'),
                  ]),
                ),
                // Assign / Transfer to another property — owner only
                if (isOwner) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'assign',
                    child: Row(children: [
                      Icon(Icons.swap_horiz_rounded,
                          size: 17, color: AppTheme.adminPrimary),
                      const SizedBox(width: 10),
                      const Text('Assign / Transfer Property'),
                    ]),
                  ),
                ],
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.person_remove_outlined,
                        size: 17, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Text('Remove from Property',
                        style: TextStyle(color: AppTheme.danger)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.adminTextMuted,
        letterSpacing: 1.2,
      );
}

// ─── Avatar widget ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  final bool isManager;
  const _Avatar({required this.initials, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isManager
            ? AppTheme.adminPrimary.withValues(alpha: 0.15)
            : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: isManager ? AppTheme.adminPrimary : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Chip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Role chip (Staff / Manager selector) ────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String description;
  final Color accentColor;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.description,
    this.accentColor = const Color(0xFF3B82F6), // AppTheme.adminPrimary
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? accentColor : Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? accentColor : Colors.black54,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? accentColor.withValues(alpha: 0.7)
                              : Colors.black38),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 16, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add staff dialog (username + password) ───────────────────────────────────

class _AddStaffDialog extends StatefulWidget {
  final String propertyId;
  final String orgId;
  final bool isHotel;
  final bool isRestaurant;
  final List<OrgProperty> orgProperties;

  const _AddStaffDialog({
    required this.propertyId,
    required this.orgId,
    required this.isHotel,
    required this.isRestaurant,
    required this.orgProperties,
  });

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _staffService = StaffService();
  // propertyId → { sectionKey → PrivilegeLevel }
  final Map<String, Map<String, PrivilegeLevel>> _propertyPerms = {};
  bool _saving         = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _success        = false;
  String? _createdUsername;

  // ── Role ──────────────────────────────────────────────────────────────────
  String _role = 'staff'; // 'staff' | 'manager'

  // ── Property selection (multi-property) ───────────────────────────────────
  late Set<String> _selectedPropertyIds;

  // ── Username preview ──────────────────────────────────────────────────────
  Timer?  _debounce;
  String? _previewUsername;   // what the system will actually assign
  bool    _previewing = false; // spinner while RPC is in-flight

  @override
  void initState() {
    super.initState();
    // Pre-select the current (active) property; it cannot be deselected
    _selectedPropertyIds = {widget.propertyId};
    // Initialise an empty permissions map for the primary property
    _propertyPerms[widget.propertyId] = {};
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    final raw = _usernameCtrl.text.trim();

    // Clear preview immediately when field is short/empty
    if (raw.length < 3) {
      _debounce?.cancel();
      setState(() { _previewUsername = null; _previewing = false; });
      return;
    }

    // Show spinner while waiting
    setState(() => _previewing = true);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final resolved = await Supabase.instance.client.rpc(
        'resolve_staff_username',
        params: {'p_username': raw},
      ) as String?;

      if (!mounted) return;
      setState(() {
        _previewUsername = resolved;
        _previewing      = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.removeListener(_onUsernameChanged);
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Build per-property assignments list.
      // Managers get empty permissions (full access granted by role alone).
      final assignments = _selectedPropertyIds.map((id) {
        final prop = widget.orgProperties.firstWhere(
          (p) => p.id == id,
          orElse: () => widget.orgProperties.first,
        );
        Map<String, String> permsJson = {};
        if (_role == 'staff') {
          final allKeys = [
            if (prop.isHotel) ...kHotelSectionKeys,
            if (prop.isRestaurant) ...kRestaurantSectionKeys,
          ];
          final perms = _propertyPerms[id] ?? {};
          permsJson = {
            for (final k in allKeys)
              k: (perms[k] ?? PrivilegeLevel.none).value,
          };
        }
        return {'propertyId': id, 'permissions': permsJson};
      }).toList();

      await _staffService.createStaffAccount(
        username:            _usernameCtrl.text.trim(),
        password:            _passCtrl.text,
        primaryPropertyId:   widget.propertyId,
        orgId:               widget.orgId,
        role:                _role,
        propertyAssignments: assignments,
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = true;
        // Use the previewed username (already resolved); fall back to raw input
        _createdUsername = _previewUsername ?? _usernameCtrl.text.trim().toLowerCase();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 640, maxHeight: _success ? 340 : 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _success ? 'Account Created' : 'Add Team Member',
                      style: AppTheme.dmSerif(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, _success),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            if (_success)
              _buildSuccessPanel()
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.adminPrimary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.adminPrimary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 16, color: AppTheme.adminPrimary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Staff log in with their username and password — no email needed.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Role selector ─────────────────────────────────
                        const Text(
                          'Role',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _RoleChip(
                              label: 'Staff',
                              icon: Icons.badge_outlined,
                              selected: _role == 'staff',
                              onTap: () => setState(() => _role = 'staff'),
                              description: 'Per-section access control',
                            ),
                            const SizedBox(width: 10),
                            _RoleChip(
                              label: 'Manager',
                              icon: Icons.shield_rounded,
                              selected: _role == 'manager',
                              onTap: () => setState(() => _role = 'manager'),
                              description: 'Full access + team management',
                              accentColor: AppTheme.goldPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Property assignment ───────────────────────────
                        // Only shown when the org has more than one property
                        if (widget.orgProperties.length > 1) ...[
                          const Text(
                            'Assign to Properties',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.orgProperties.map((p) {
                              final isPrimary = p.id == widget.propertyId;
                              final isSelected = _selectedPropertyIds.contains(p.id);
                              return FilterChip(
                                label: Text(p.name),
                                selected: isSelected,
                                onSelected: isPrimary
                                    ? null // primary property cannot be deselected
                                    : (v) => setState(() {
                                          if (v) {
                                            _selectedPropertyIds.add(p.id);
                                            _propertyPerms[p.id] = {};
                                          } else {
                                            _selectedPropertyIds.remove(p.id);
                                            _propertyPerms.remove(p.id);
                                          }
                                        }),
                                avatar: Icon(
                                  p.isHotel && p.isRestaurant
                                      ? Icons.business_rounded
                                      : p.isRestaurant
                                          ? Icons.restaurant_rounded
                                          : Icons.hotel_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? AppTheme.adminPrimary
                                      : Colors.grey,
                                ),
                                selectedColor: AppTheme.adminPrimary.withValues(alpha: 0.1),
                                checkmarkColor: AppTheme.adminPrimary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppTheme.adminPrimary
                                      : Colors.black54,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isPrimary
                                      ? AppTheme.adminPrimary.withValues(alpha: 0.5)
                                      : isSelected
                                          ? AppTheme.adminPrimary.withValues(alpha: 0.3)
                                          : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          if (_selectedPropertyIds.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Account will have access to ${_selectedPropertyIds.length} properties.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.adminPrimary),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],

                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'e.g. john_reception',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Username is required';
                            if (v.trim().length < 3) return 'At least 3 characters';
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                              return 'Only letters, numbers and underscores';
                            }
                            return null;
                          },
                        ),
                        // ── Live username preview ─────────────────────────
                        if (_previewing)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Checking availability…',
                                    style: TextStyle(fontSize: 12, color: Colors.black45)),
                              ],
                            ),
                          )
                        else if (_previewUsername != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 15, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 6),
                                const Text('Will be assigned: ',
                                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF81C784)),
                                  ),
                                  child: Text(
                                    _previewUsername!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => v == null || v.length < 6
                              ? 'At least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => v != _passCtrl.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        if (_role == 'manager')
                          // Manager banner — no per-section config needed
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.goldPrimary.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.goldPrimary.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_rounded,
                                    size: 16, color: AppTheme.goldPrimary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Managers have full access to all sections and can manage the team.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.goldPrimary),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // ── Per-property permission matrices ──────────────
                          // Single property: no header, single matrix.
                          // Multiple properties: one header + matrix each.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: () {
                              final orderedIds = [
                                widget.propertyId,
                                ..._selectedPropertyIds.where(
                                    (id) => id != widget.propertyId),
                              ];
                              final List<Widget> sections = [];
                              for (var i = 0; i < orderedIds.length; i++) {
                                final id = orderedIds[i];
                                final prop = widget.orgProperties.firstWhere(
                                  (p) => p.id == id,
                                  orElse: () => widget.orgProperties.first,
                                );
                                final perms =
                                    _propertyPerms.putIfAbsent(id, () => {});

                                if (orderedIds.length > 1) {
                                  // Show property header when multiple selected
                                  if (i > 0) sections.add(const Divider(height: 32));
                                  sections.add(
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            prop.isHotel && prop.isRestaurant
                                                ? Icons.business_rounded
                                                : prop.isRestaurant
                                                    ? Icons.restaurant_rounded
                                                    : Icons.hotel_rounded,
                                            size: 15,
                                            color: AppTheme.adminPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            prop.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (id == widget.propertyId) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.adminPrimary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Current',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.adminPrimary,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                sections.add(_PrivilegeMatrix(
                                  permissions:  perms,
                                  isHotel:      prop.isHotel,
                                  isRestaurant: prop.isRestaurant,
                                  onChanged:    (key, val) =>
                                      setState(() => perms[key] = val),
                                ));
                              }
                              return sections;
                            }(),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: _success
                  ? ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Done',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _createAccount,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.person_add_rounded,
                                  size: 18, color: Colors.white),
                          label: Text(
                            _saving ? 'Creating...' : 'Create Account',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.adminPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 48, color: Color(0xFF22C55E)),
          const SizedBox(height: 12),
          Text(
            _role == 'manager'
                ? 'Manager account created successfully!'
                : 'Staff account created successfully!',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 8),
                Text(
                  'Username: ',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  _createdUsername ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Share the username and password with the staff member.\nThey can log in directly from the login screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Reset password dialog ────────────────────────────────────────────────────

class _ResetPasswordDialog extends StatefulWidget {
  final PropertyStaffMember member;
  const _ResetPasswordDialog({required this.member});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  final _staffService = StaffService();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _saving  = false;
  bool _success = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _staffService.resetStaffPassword(
          widget.member.userId, _passCtrl.text);
      if (!mounted) return;
      setState(() { _saving = false; _success = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: _success ? _buildDone() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_reset_rounded,
            size: 48, color: Color(0xFF22C55E)),
        const SizedBox(height: 12),
        Text('Password Reset',
            style: AppTheme.dmSerif(fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          'Password for "${widget.member.fullName}" has been updated.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock_reset_rounded, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reset Password — ${widget.member.fullName}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.length < 6
                ? 'At least 6 characters'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v != _passCtrl.text
                ? 'Passwords do not match'
                : null,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.black54)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _reset,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_reset_rounded,
                        size: 18, color: Colors.white),
                label: Text(
                  _saving ? 'Saving...' : 'Reset Password',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Edit permissions dialog ──────────────────────────────────────────────────

class _EditPermissionsDialog extends StatefulWidget {
  final PropertyStaffMember member;
  final String propertyId;
  final bool isHotel;
  final bool isRestaurant;

  const _EditPermissionsDialog({
    required this.member,
    required this.propertyId,
    required this.isHotel,
    required this.isRestaurant,
  });

  @override
  State<_EditPermissionsDialog> createState() =>
      _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<_EditPermissionsDialog> {
  final _staffService = StaffService();
  late Map<String, PrivilegeLevel> _permissions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, PrivilegeLevel>.from(widget.member.permissions);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final allKeys = [
        if (widget.isHotel) ...kHotelSectionKeys,
        if (widget.isRestaurant) ...kRestaurantSectionKeys,
      ];
      final fullPerms = {
        for (final k in allKeys) k: _permissions[k] ?? PrivilegeLevel.none,
      };

      await _staffService.updateStaffPermissions(
          widget.propertyId, widget.member.userId, fullPerms);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update permissions: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 0),
              child: Row(
                children: [
                  _Avatar(
                      initials: widget.member.initials,
                      isManager: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.member.fullName.isEmpty
                              ? widget.member.email
                              : widget.member.fullName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.member.email,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.adminTextMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: _PrivilegeMatrix(
                  permissions: _permissions,
                  isHotel: widget.isHotel,
                  isRestaurant: widget.isRestaurant,
                  onChanged: (key, val) =>
                      setState(() => _permissions[key] = val),
                ),
              ),
            ),

            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.black54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.save_rounded,
                            size: 18, color: Colors.white),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Permissions',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.adminPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
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

// ─── Privilege matrix widget ──────────────────────────────────────────────────

class _PrivilegeMatrix extends StatelessWidget {
  final Map<String, PrivilegeLevel> permissions;
  final bool isHotel;
  final bool isRestaurant;
  final void Function(String key, PrivilegeLevel level) onChanged;

  const _PrivilegeMatrix({
    required this.permissions,
    required this.isHotel,
    required this.isRestaurant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend row
        Row(
          children: [
            const Expanded(child: SizedBox()),
            _LegendLabel('None', Colors.grey.shade500),
            _LegendLabel('View', AppTheme.adminPrimary),
            _LegendLabel('Edit', AppTheme.warning),
          ],
        ),
        const SizedBox(height: 8),

        if (isHotel) ...[
          _SectionHeader(
              label: 'HOTEL', color: const Color(0xFFD4A853)),
          const SizedBox(height: 6),
          ...kHotelSectionKeys.map((key) => _SectionRow(
                sectionKey: key,
                label: kSectionLabel[key] ?? key,
                current: permissions[key] ?? PrivilegeLevel.none,
                onChanged: (val) => onChanged(key, val),
              )),
        ],

        if (isHotel && isRestaurant) const SizedBox(height: 8),

        if (isRestaurant) ...[
          _SectionHeader(
              label: 'RESTAURANT', color: AppTheme.restaurantAccent),
          const SizedBox(height: 6),
          ...kRestaurantSectionKeys.map((key) => _SectionRow(
                sectionKey: key,
                label: kSectionLabel[key] ?? key,
                current: permissions[key] ?? PrivilegeLevel.none,
                onChanged: (val) => onChanged(key, val),
              )),
        ],
      ],
    );
  }
}

class _LegendLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String sectionKey;
  final String label;
  final PrivilegeLevel current;
  final ValueChanged<PrivilegeLevel> onChanged;

  const _SectionRow({
    required this.sectionKey,
    required this.label,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: current != PrivilegeLevel.none
            ? (current == PrivilegeLevel.edit
                ? AppTheme.warning.withValues(alpha: 0.05)
                : AppTheme.adminPrimary.withValues(alpha: 0.04))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: current != PrivilegeLevel.none
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: current != PrivilegeLevel.none
                    ? Colors.black87
                    : Colors.black54,
              ),
            ),
          ),
          // None / View / Edit toggle buttons
          _PrivilegeToggle(
            level: PrivilegeLevel.none,
            current: current,
            color: Colors.grey.shade500,
            onTap: () => onChanged(PrivilegeLevel.none),
          ),
          _PrivilegeToggle(
            level: PrivilegeLevel.view,
            current: current,
            color: AppTheme.adminPrimary,
            onTap: () => onChanged(PrivilegeLevel.view),
          ),
          _PrivilegeToggle(
            level: PrivilegeLevel.edit,
            current: current,
            color: AppTheme.warning,
            onTap: () => onChanged(PrivilegeLevel.edit),
          ),
        ],
      ),
    );
  }
}

class _PrivilegeToggle extends StatelessWidget {
  final PrivilegeLevel level;
  final PrivilegeLevel current;
  final Color color;
  final VoidCallback onTap;

  const _PrivilegeToggle({
    required this.level,
    required this.current,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = level == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 66,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          level.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? color : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

// ─── Assign / Transfer to Property Dialog ─────────────────────────────────────

class _AssignToPropertyDialog extends StatefulWidget {
  final PropertyStaffMember member;
  final String              currentPropertyId;
  final List<OrgProperty>   otherProperties;

  const _AssignToPropertyDialog({
    required this.member,
    required this.currentPropertyId,
    required this.otherProperties,
  });

  @override
  State<_AssignToPropertyDialog> createState() =>
      _AssignToPropertyDialogState();
}

class _AssignToPropertyDialogState extends State<_AssignToPropertyDialog> {
  final _staffService = StaffService();

  bool          _loading         = true;
  bool          _saving          = false;
  Set<String>   _alreadyAssigned = {};   // propertyIds the member is already on

  // Selection
  String? _targetPropertyId;
  String  _role                  = 'staff'; // 'staff' | 'manager'
  bool    _revokeFromCurrent     = false;   // transfer mode

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    final ids = await _staffService.getStaffProperties(widget.member.userId);
    if (!mounted) return;
    setState(() {
      _alreadyAssigned = ids.toSet();
      _loading         = false;
    });
  }

  Future<void> _confirm() async {
    if (_targetPropertyId == null) return;
    setState(() => _saving = true);
    try {
      // 1. Assign to target property
      await _staffService.assignStaffToProperty(
        propertyId: _targetPropertyId!,
        userId:     widget.member.userId,
        role:       _role,
      );

      // 2. Optionally revoke all permissions from current property (transfer)
      if (_revokeFromCurrent) {
        await _staffService.revokeAllPermissions(
            widget.currentPropertyId, widget.member.userId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _revokeFromCurrent
                ? '${widget.member.fullName.isEmpty ? "Staff member" : widget.member.fullName} transferred successfully.'
                : '${widget.member.fullName.isEmpty ? "Staff member" : widget.member.fullName} assigned to new property.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.member.fullName.isNotEmpty
        ? widget.member.fullName
        : widget.member.email;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppTheme.adminPrimary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign / Transfer Property',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(displayName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.adminTextMuted)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : _saving
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Target property selector ─────────────────────────
                        const Text('Select target property',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54)),
                        const SizedBox(height: 8),
                        ...widget.otherProperties.map((p) {
                          final alreadyOn = _alreadyAssigned.contains(p.id);
                          final isSelected = _targetPropertyId == p.id;
                          return GestureDetector(
                            onTap: alreadyOn
                                ? null
                                : () => setState(
                                    () => _targetPropertyId = p.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: alreadyOn
                                    ? Colors.grey.shade50
                                    : isSelected
                                        ? AppTheme.adminPrimary
                                            .withOpacity(0.07)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.adminPrimary
                                      : Colors.grey.shade200,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    p.isHotel && p.isRestaurant
                                        ? Icons.business_rounded
                                        : p.isRestaurant
                                            ? Icons.restaurant_rounded
                                            : Icons.hotel_rounded,
                                    size: 18,
                                    color: alreadyOn
                                        ? Colors.grey.shade400
                                        : isSelected
                                            ? AppTheme.adminPrimary
                                            : Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: alreadyOn
                                            ? Colors.grey.shade400
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (alreadyOn)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text('Already assigned',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500)),
                                    )
                                  else if (isSelected)
                                    Icon(Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppTheme.adminPrimary),
                                ],
                              ),
                            ),
                          );
                        }),

                        if (_targetPropertyId != null) ...[
                          const SizedBox(height: 16),
                          // ── Role selector ──────────────────────────────────
                          const Text('Role in new property',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54)),
                          const SizedBox(height: 8),
                          Row(children: [
                            _roleOption(
                              label: 'Staff',
                              icon: Icons.person_rounded,
                              description: 'Limited — assign sections separately',
                              selected: _role == 'staff',
                              onTap: () => setState(() => _role = 'staff'),
                            ),
                            const SizedBox(width: 8),
                            _roleOption(
                              label: 'Manager',
                              icon: Icons.shield_rounded,
                              description: 'Full access to all sections',
                              selected: _role == 'manager',
                              onTap: () => setState(() => _role = 'manager'),
                              color: AppTheme.goldPrimary,
                            ),
                          ]),
                        ],

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // ── Transfer toggle ────────────────────────────────
                        InkWell(
                          onTap: () => setState(
                              () => _revokeFromCurrent = !_revokeFromCurrent),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _revokeFromCurrent
                                  ? AppTheme.warning.withOpacity(0.06)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _revokeFromCurrent
                                    ? AppTheme.warning.withOpacity(0.4)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _revokeFromCurrent
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: _revokeFromCurrent
                                      ? AppTheme.warning
                                      : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Transfer mode — revoke access from current property',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _revokeFromCurrent
                                              ? AppTheme.warning
                                              : Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        'All section permissions will be cleared from the current property.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton.icon(
          onPressed: (_targetPropertyId == null || _saving)
              ? null
              : _confirm,
          icon: Icon(
            _revokeFromCurrent
                ? Icons.swap_horiz_rounded
                : Icons.add_link_rounded,
            size: 16,
            color: Colors.white,
          ),
          label: Text(
            _revokeFromCurrent ? 'Transfer' : 'Assign',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _revokeFromCurrent
                ? AppTheme.warning
                : AppTheme.adminPrimary,
            disabledBackgroundColor: Colors.grey.shade200,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _roleOption({
    required String   label,
    required IconData icon,
    required String   description,
    required bool     selected,
    required VoidCallback onTap,
    Color?            color,
  }) {
    final effectiveColor = color ?? AppTheme.adminPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? effectiveColor.withOpacity(0.07) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? effectiveColor : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? effectiveColor : Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? effectiveColor : Colors.black54)),
                    Text(description,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 14, color: effectiveColor),
            ],
          ),
        ),
      ),
    );
  }
}
