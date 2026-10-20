import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../services/plan_service.dart';
import '../services/organization_service.dart';
import '../providers/service_providers.dart';
import 'semantic_palette.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  bool _loadingProfile = true;
  bool _saving = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jobTitleCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(organizationServiceProvider).getMyProfile();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text     = profile?['full_name']  as String? ?? '';
      _jobTitleCtrl.text = profile?['job_title']  as String? ?? '';
      _phoneCtrl.text    = profile?['phone']       as String? ?? '';
      _email             = profile?['email']        as String? ?? '';
      _loadingProfile    = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(organizationServiceProvider).updateProfile(
        fullName: _nameCtrl.text.trim(),
        jobTitle: _jobTitleCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    // Step 1: warn dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            const SizedBox(width: 10),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Your profile will be deactivated', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• If you are the sole owner, your organisation and all properties will also be deactivated', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• Historical data (bookings, financials) is preserved for records', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• This action can be reversed by contacting support', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, delete my account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Step 2: type email to confirm
    final typedEmail = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Confirm Account Deletion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type your email address to confirm:',
                  style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  onChanged: (_) => setS(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: ctrl.text.trim().toLowerCase() == _email.trim().toLowerCase()
                    ? () => Navigator.of(ctx).pop(ctrl.text.trim())
                    : null,
                child: const Text('Delete Account'),
              ),
            ],
          );
        });
      },
    );

    if (typedEmail == null || !mounted) return;

    // Step 3: perform soft delete + sign out
    try {
      await ref.read(organizationServiceProvider).softDeleteMyAccount();
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: SingleChildScrollView(
        padding: AppTheme.screenPad(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header
            Text('Account Settings', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 4),
            Text(
              'Manage your personal profile and account preferences.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // ─── Profile card
            _SectionCard(
              title: 'Profile Information',
              icon: Icons.person_rounded,
              child: _loadingProfile
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email (read-only)
                          _ReadOnlyField(
                            label: 'Email Address',
                            value: _email,
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _jobTitleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Job Title',
                                    prefixIcon: Icon(Icons.work_outline_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveProfile,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded, size: 16),
                              label: Text(_saving ? 'Saving…' : 'Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.adminPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // ─── Plan & Billing card
            _PlanBillingCard(),

            const SizedBox(height: 24),

            // ─── Danger zone card
            _SectionCard(
              title: 'Danger Zone',
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.danger,
              borderColor: AppTheme.danger.withOpacity(0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delete Account',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Deactivates your account and, if you are the sole owner, '
                              'your organisation and all its properties. Your historical '
                              'data is preserved and the action can be reversed by support.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.adminTextMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      OutlinedButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(Icons.delete_forever_rounded, size: 16),
                        label: const Text('Delete Account'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ─── Plan & Billing card ──────────────────────────────────────────────────────

class _PlanBillingCard extends ConsumerStatefulWidget {
  const _PlanBillingCard();

  @override
  ConsumerState<_PlanBillingCard> createState() => _PlanBillingCardState();
}

class _PlanBillingCardState extends ConsumerState<_PlanBillingCard> {
  // Was a fourth, contradicting copy of the tier palette.

  List<OrgMember> _members = [];
  bool _loadingMembers = false;
  final _orgService = OrganizationService();

  @override
  void initState() {
    super.initState();
    // Best-effort: load immediately if auth is already settled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    final auth = ref.read(authProvider).valueOrNull;
    // Auth still loading or user is not an owner — skip.
    if (auth == null || auth.organization == null || !auth.isOrgOwner) return;
    setState(() => _loadingMembers = true);
    try {
      final members = await _orgService.getOrganizationMembers(auth.organization!.id);
      if (mounted) setState(() => _members = members);
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _toggleBilling(OrgMember member, bool value) async {
    try {
      await _orgService.setMemberBillingPermission(member.id, value);
      await _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update billing permission: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Widget _limitChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.black38),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    // If auth was still loading during initState, load members once it settles.
    ref.listen<AsyncValue<AppAuthState>>(authProvider, (prev, next) {
      if ((prev?.isLoading ?? true) && !next.isLoading) {
        _loadMembers();
      }
    });

    final auth     = ref.watch(authProvider).valueOrNull;
    final org      = auth?.organization;
    final planSlug = org?.plan ?? 'starter';
    final accent   = SemanticPalette.tier(planSlug);
    final isOwner  = auth?.isOrgOwner ?? false;

    // Members who can be granted billing access (exclude owners — they always have it)
    final grantableMembers = _members.where((m) => m.role != 'owner').toList();

    return _SectionCard(
      title: 'Plan & Billing',
      icon: Icons.workspace_premium_rounded,
      child: FutureBuilder<List<PlanModel>>(
        future: org != null
            ? ref.read(planServiceProvider).getActivePlansForOrg(org.id)
            : ref.read(planServiceProvider).getActivePlans(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final plans   = snap.data ?? [];
          final current = plans.firstWhere(
            (p) => p.slug == planSlug,
            orElse: () => PlanModel(
              id: '',
              name: planSlug.isEmpty
                  ? planSlug
                  : planSlug[0].toUpperCase() + planSlug.substring(1),
              slug: planSlug, priceMonthly: 0, isCustomPrice: false,
              maxProperties: 1, maxUsers: 3, maxRooms: 10, maxTables: 5,
              isHighlighted: false, isActive: true, sortOrder: 0,
            ),
          );

          final canUpgrade   = (auth?.canUpgradePlan ?? false) &&
              plans.any((p) => p.sortOrder > current.sortOrder && !p.isCustomPrice);
          final isEnterprise = current.isCustomPrice;

          String lim(int v) => v == -1 ? 'Unlimited' : '$v';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current plan badge row
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(current.name,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                  ]),
                ),
                if (!isEnterprise && current.priceMonthly > 0) ...[
                  const SizedBox(width: 10),
                  Text('LKR ${current.priceMonthly.toInt()} / month',
                      style: const TextStyle(fontSize: 13, color: Colors.black45)),
                ],
                if (current.priceMonthly == 0 && !isEnterprise)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text('Free forever',
                        style: const TextStyle(fontSize: 13, color: Colors.black45)),
                  ),
              ]),
              const SizedBox(height: 16),

              // Limits row
              Wrap(spacing: 10, runSpacing: 8, children: [
                _limitChip(Icons.domain_rounded,   '${lim(current.maxProperties)} ${current.maxProperties == 1 ? "property" : "properties"}'),
                _limitChip(Icons.bed_rounded,       '${lim(current.maxRooms)} rooms'),
                _limitChip(Icons.people_rounded,    '${lim(current.maxUsers)} staff'),
                _limitChip(Icons.table_bar_rounded, '${lim(current.maxTables)} tables'),
              ]),
              const SizedBox(height: 20),

              // Upgrade action row — visible only to owners & billing-permitted members
              if (isEnterprise)
                const Text(
                  'You\'re on an Enterprise plan. Contact support to make changes.',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                )
              else if (canUpgrade)
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go('/app/upgrade'),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                    label: const Text('Upgrade Plan'),
                    style: ElevatedButton.styleFrom(
                      // Brand, not `accent`. This is the screen's primary
                      // action; colouring it by the customer's current tier
                      // meant the main CTA changed colour per account and was
                      // never the brand.
                      backgroundColor: AppTheme.adminPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Unlock more properties, rooms & staff.',
                      style: TextStyle(fontSize: 12, color: Colors.black38)),
                ])
              else if (auth?.canUpgradePlan ?? false)
                const Text(
                  'You\'re on the highest available plan.',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),

              // ── Billing Access section (owners only) ──────────────────────
              if (isOwner) ...[
                const SizedBox(height: 28),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.credit_card_rounded, size: 16, color: Colors.black45),
                  const SizedBox(width: 8),
                  Text('Billing Access',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Choose who can upgrade the plan. Only you (owner) have access by default.',
                  style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
                ),
                const SizedBox(height: 14),
                if (_loadingMembers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (grantableMembers.isEmpty)
                  Text(
                    'No other members in your organisation yet.',
                    style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
                  )
                else
                  ...grantableMembers.map((m) => _BillingMemberRow(
                        member: m,
                        onToggle: (v) => _toggleBilling(m, v),
                      )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BillingMemberRow extends StatelessWidget {
  final OrgMember member;
  final ValueChanged<bool> onToggle;

  const _BillingMemberRow({required this.member, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final initials = member.fullName.isNotEmpty
        ? member.fullName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.adminPrimary.withValues(alpha: 0.12),
            child: Text(initials,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.adminPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName.isNotEmpty ? member.fullName : member.email,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(_roleLabel(member.role),
                    style: TextStyle(fontSize: 11, color: AppTheme.adminTextMuted)),
              ],
            ),
          ),
          Switch(
            value: member.canManageBilling,
            onChanged: onToggle,
            activeColor: AppTheme.adminPrimary,
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
    'admin'  => 'Admin',
    'member' => 'Member',
    _        => role,
  };
}

// ─── Reusable section card ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Color? borderColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.adminPrimary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderColor ?? AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: borderColor ?? Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Read-only field ──────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Cannot change',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
