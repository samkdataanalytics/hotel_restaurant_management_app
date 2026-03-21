import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../models/staff_permission.dart';
import '../providers/app_auth_provider.dart';
import '../services/staff_service.dart';

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

  Future<void> _addMember() async {
    final property = ref.read(activePropertyProvider);
    final authState = ref.read(authProvider).valueOrNull;
    if (property == null || authState?.organization == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStaffDialog(
        propertyId: property.id,
        orgId: authState!.organization!.id,
        isHotel: _isHotel,
        isRestaurant: _isRestaurant,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
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

                    if (_staff.isEmpty)
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
                      ..._staff.map((m) => _buildMemberRow(m)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(PropertyStaffMember member) {
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

          // Actions
          SizedBox(
            width: 48,
            child: member.isManager
                ? const SizedBox()
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 20, color: Color(0xFF94A3B8)),
                    tooltip: 'Actions',
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(-120, 8),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editPermissions(member);
                          break;
                        case 'reset':
                          _resetPassword(member);
                          break;
                        case 'revoke':
                          _revokeAllAccess(member);
                          break;
                        case 'remove':
                          _removeMember(member);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
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
                        value: 'reset',
                        child: Row(children: [
                          Icon(Icons.lock_reset_rounded,
                              size: 17, color: AppTheme.adminPrimary),
                          const SizedBox(width: 10),
                          const Text('Reset Password'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'revoke',
                        child: Row(children: [
                          Icon(Icons.block_rounded,
                              size: 17, color: AppTheme.warning),
                          const SizedBox(width: 10),
                          Text('Revoke All Access',
                              style:
                                  TextStyle(color: AppTheme.warning)),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          Icon(Icons.person_remove_outlined,
                              size: 17, color: AppTheme.danger),
                          const SizedBox(width: 10),
                          Text('Remove from Property',
                              style:
                                  TextStyle(color: AppTheme.danger)),
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

// ─── Add staff dialog (username + password) ───────────────────────────────────

class _AddStaffDialog extends StatefulWidget {
  final String propertyId;
  final String orgId;
  final bool isHotel;
  final bool isRestaurant;

  const _AddStaffDialog({
    required this.propertyId,
    required this.orgId,
    required this.isHotel,
    required this.isRestaurant,
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
  final Map<String, PrivilegeLevel> _permissions = {};
  bool _saving         = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _success        = false;
  String? _createdUsername;

  // ── Username preview ──────────────────────────────────────────────────────
  Timer?  _debounce;
  String? _previewUsername;   // what the system will actually assign
  bool    _previewing = false; // spinner while RPC is in-flight

  @override
  void initState() {
    super.initState();
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
      final allKeys = [
        if (widget.isHotel) ...kHotelSectionKeys,
        if (widget.isRestaurant) ...kRestaurantSectionKeys,
      ];
      final fullPerms = {
        for (final k in allKeys) k: _permissions[k] ?? PrivilegeLevel.none,
      };

      await _staffService.createStaffAccount(
        username:   _usernameCtrl.text.trim(),
        password:   _passCtrl.text,
        propertyId: widget.propertyId,
        orgId:      widget.orgId,
        permissions: fullPerms,
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
            maxWidth: 640, maxHeight: _success ? 340 : 680),
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
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
                        _PrivilegeMatrix(
                          permissions:  _permissions,
                          isHotel:      widget.isHotel,
                          isRestaurant: widget.isRestaurant,
                          onChanged:    (key, val) =>
                              setState(() => _permissions[key] = val),
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
          const Text(
            'Staff account created successfully!',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
        const Text('Password Reset',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
