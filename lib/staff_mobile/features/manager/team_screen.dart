import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/staff_permission.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

final _teamProvider =
    FutureProvider.autoDispose<List<PropertyStaffMember>>((ref) async {
  final propertyId = ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));
  if (propertyId == null) return const [];
  return ref.watch(staffServiceProvider).getPropertyStaff(propertyId);
});

/// Who works here and what they can see.
///
/// Owner-only, matching the web: a manager runs the floor, an owner decides
/// who gets access. Changing someone's permissions from a phone is the point —
/// a new starter should not have to wait for somebody to reach a desktop.
///
/// Creating accounts is NOT here. `createStaffAccount` goes through a
/// service-role edge function and sets an initial password, which is a
/// credential-handling flow that deserves a considered screen rather than a
/// phone form. Inviting by email is offered instead, which is the same outcome
/// without anyone typing someone else's password.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_teamProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final isOwner = session?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'Invite someone',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: _invite,
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!isOwner)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — only an owner can change who has access.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(_teamProvider.future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Could not load the team.\n\n$e',
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                data: (members) => members.isEmpty
                    ? ListView(children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Text('Nobody assigned to this property yet.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _MemberCard(
                          member: members[i],
                          editable: isOwner && !members[i].isPropertyOwner,
                          busy: _busy.contains(members[i].userId),
                          onEditPermissions: () => _editPermissions(members[i]),
                          onToggleRole: () => _toggleRole(members[i]),
                          onRemove: () => _remove(members[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite a team member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'They get a link to create their own account. Set their '
              'permissions once they have accepted.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || email.isEmpty || !mounted) return;
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('That does not look like an email.')));
      return;
    }

    final session = ref.read(staffSessionProvider).valueOrNull;
    final property = session?.activeProperty;
    if (property == null) return;

    try {
      // No sections granted up front. A new starter with blanket access is how
      // permissions quietly stop meaning anything; the owner grants what is
      // needed once they have accepted.
      await ref.read(staffServiceProvider).createInvite(
            propertyId: property.id,
            orgId: property.orgId,
            email: email,
            permissions: const {},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Invite sent to $email')));
    } catch (e) {
      if (!mounted) return;
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Inviting $email',
      );
    }
  }

  Future<void> _editPermissions(PropertyStaffMember member) async {
    final updated = await showModalBottomSheet<Map<String, PrivilegeLevel>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PermissionSheet(member: member),
    );
    if (updated == null || !mounted) return;

    final propertyId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;
    if (propertyId == null) return;

    setState(() => _busy.add(member.userId));
    try {
      await ref
          .read(staffServiceProvider)
          .updateStaffPermissions(propertyId, member.userId, updated);
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      ref.invalidate(_teamProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Updating ${member.fullName}',
      );
    }
  }

  Future<void> _toggleRole(PropertyStaffMember member) async {
    final makeManager = !member.isManager;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(makeManager ? 'Make manager?' : 'Make staff?'),
        content: Text(
          makeManager
              ? '${member.fullName} will get full operational access to every '
                  'section, ignoring the per-section permissions below.'
              : '${member.fullName} will be limited to the sections you grant '
                  'them individually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(makeManager ? 'Make manager' : 'Make staff'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final propertyId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;
    if (propertyId == null) return;

    setState(() => _busy.add(member.userId));
    try {
      await ref.read(staffServiceProvider).setStaffRole(
            propertyId,
            member.userId,
            makeManager ? 'manager' : 'staff',
          );
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      ref.invalidate(_teamProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Changing ${member.fullName}\'s role',
      );
    }
  }

  Future<void> _remove(PropertyStaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.fullName}?'),
        content: const Text(
          'They lose access to this property immediately. Their account and '
          'any other properties they work at are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final propertyId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;
    if (propertyId == null) return;

    setState(() => _busy.add(member.userId));
    try {
      await ref
          .read(staffServiceProvider)
          .removeStaffMember(propertyId, member.userId);
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      ref.invalidate(_teamProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(member.userId));
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Removing ${member.fullName}',
      );
    }
  }
}

class _MemberCard extends StatelessWidget {
  final PropertyStaffMember member;
  final bool editable;
  final bool busy;
  final VoidCallback onEditPermissions;
  final VoidCallback onToggleRole;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.editable,
    required this.busy,
    required this.onEditPermissions,
    required this.onToggleRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.secondaryContainer,
              child: Text(member.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  )),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName.trim().isEmpty
                        ? member.email
                        : member.fullName,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.isPropertyOwner
                        ? 'Owner'
                        : member.isManager
                            ? 'Manager · every section'
                            : '${member.accessCount} of 13 sections'
                                '${member.editCount > 0 ? ', ${member.editCount} editable' : ''}',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2)),
              )
            else if (editable)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  switch (v) {
                    case 'permissions':
                      onEditPermissions();
                    case 'role':
                      onToggleRole();
                    case 'remove':
                      onRemove();
                  }
                },
                itemBuilder: (_) => [
                  // A manager bypasses the section map entirely, so offering to
                  // edit it for them would imply a control that does nothing.
                  if (!member.isManager)
                    const PopupMenuItem(
                      value: 'permissions',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tune_rounded),
                        title: Text('Permissions'),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'role',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.swap_vert_rounded),
                      title: Text(member.isManager
                          ? 'Make staff'
                          : 'Make manager'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_remove_outlined,
                          color: scheme.error),
                      title: Text('Remove',
                          style: TextStyle(color: scheme.error)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-section privileges for one staff member.
class _PermissionSheet extends StatefulWidget {
  final PropertyStaffMember member;
  const _PermissionSheet({required this.member});

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  late final Map<String, PrivilegeLevel> _permissions =
      Map.of(widget.member.permissions);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(widget.member.fullName,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'View lets them see a section. Edit lets them change things in '
                'it.',
                style:
                    TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _group(context, 'HOTEL', kHotelSectionKeys),
                  _group(context, 'RESTAURANT', kRestaurantSectionKeys),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_permissions),
                child: const Text('Save permissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String label, List<String> keys) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Text(label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              )),
        ),
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                Expanded(child: Text(kSectionLabel[key] ?? key)),
                SegmentedButton<PrivilegeLevel>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                        value: PrivilegeLevel.none, label: Text('None')),
                    ButtonSegment(
                        value: PrivilegeLevel.view, label: Text('View')),
                    ButtonSegment(
                        value: PrivilegeLevel.edit, label: Text('Edit')),
                  ],
                  selected: {_permissions[key] ?? PrivilegeLevel.none},
                  onSelectionChanged: (s) =>
                      setState(() => _permissions[key] = s.first),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
