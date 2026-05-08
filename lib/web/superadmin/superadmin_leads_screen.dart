import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../../services/lead_service.dart';
import '../../services/organization_service.dart';

class SuperadminLeadsScreen extends StatefulWidget {
  const SuperadminLeadsScreen({super.key});

  @override
  State<SuperadminLeadsScreen> createState() => _SuperadminLeadsScreenState();
}

class _SuperadminLeadsScreenState extends State<SuperadminLeadsScreen> {
  late Future<List<EnterpriseLead>> _future;
  final _service = LeadService();

  @override
  void initState() {
    super.initState();
    _future = _service.getAllLeads();
  }

  void _reload() => setState(() { _future = _service.getAllLeads(); });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: FutureBuilder<List<EnterpriseLead>>(
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
                  Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                  const SizedBox(height: 12),
                  Text('Failed to load leads',
                      style: TextStyle(color: AppTheme.danger, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(snapshot.error.toString(),
                      style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final leads = snapshot.data ?? [];
          return _LeadsContent(leads: leads, service: _service, onReload: _reload);
        },
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _LeadsContent extends StatelessWidget {
  final List<EnterpriseLead> leads;
  final LeadService service;
  final VoidCallback onReload;

  const _LeadsContent({
    required this.leads,
    required this.service,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Enterprise Leads',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                SizedBox(height: 4),
                Text('Incoming enquiries from the Enterprise plan contact form.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              ]),
            ),
            // Status legend
            _StatusBadge(LeadStatus.newLead),
            SizedBox(width: 8),
            _StatusBadge(LeadStatus.contacted),
            SizedBox(width: 8),
            _StatusBadge(LeadStatus.converted),
            SizedBox(width: 8),
            _StatusBadge(LeadStatus.declined),
          ]),
          const SizedBox(height: 28),

          if (leads.isEmpty)
            _buildEmpty()
          else
            ...leads.map((lead) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LeadCard(lead: lead, service: service, onReload: onReload),
            )),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 64),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8EDF3)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_rounded, size: 48, color: AppTheme.adminTextMuted),
      const SizedBox(height: 12),
      Text('No leads yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.adminTextMuted)),
      const SizedBox(height: 6),
      Text('When someone submits the Enterprise contact form it will appear here.',
          style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
    ]),
  );
}

// ─── Lead card ────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final EnterpriseLead lead;
  final LeadService service;
  final VoidCallback onReload;

  const _LeadCard({required this.lead, required this.service, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _statusColor(lead.status), width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Avatar
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _statusColor(lead.status).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: _statusColor(lead.status),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name + company
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lead.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      Text(lead.company,
                          style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted)),
                    ]),
                  ),
                  // Date + status
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _StatusBadge(lead.status),
                    const SizedBox(height: 6),
                    Text(_formatDate(lead.createdAt),
                        style: TextStyle(fontSize: 11, color: AppTheme.adminTextMuted)),
                  ]),
                ]),
                const SizedBox(height: 14),

                // Contact info row
                Wrap(spacing: 20, runSpacing: 6, children: [
                  _info(Icons.email_rounded, lead.email),
                  if (lead.phone != null && lead.phone!.isNotEmpty)
                    _info(Icons.phone_rounded, lead.phone!),
                  if (lead.propertyCount != null)
                    _info(Icons.apartment_rounded, '${lead.propertyCount} properties'),
                ]),

                // Message
                if (lead.message != null && lead.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(lead.message!,
                        style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, height: 1.5)),
                  ),
                ],

                // Admin notes
                if (lead.adminNotes != null && lead.adminNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.2)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.sticky_note_2_rounded, size: 14, color: AppTheme.goldPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(lead.adminNotes!,
                            style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted, height: 1.4)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE8EDF3), height: 1),
                const SizedBox(height: 12),

                // Actions
                Row(children: [
                  const Text('Update status:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(width: 10),
                  ...LeadStatus.values.where((s) => s != lead.status).map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ActionChip(
                      label: s.label,
                      color: _statusColor(s),
                      onTap: () => _updateStatus(context, s),
                    ),
                  )),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showNotesDialog(context),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Notes', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.adminTextMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => _showProvisionDialog(context),
                    icon: const Icon(Icons.build_circle_rounded, size: 15),
                    label: const Text('Setup Access', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AppTheme.adminTextMuted),
    const SizedBox(width: 5),
    Text(text, style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
  ]);

  Color _statusColor(LeadStatus s) => switch (s) {
    LeadStatus.newLead   => AppTheme.adminPrimary,
    LeadStatus.contacted => AppTheme.warning,
    LeadStatus.converted => AppTheme.success,
    LeadStatus.declined  => AppTheme.danger,
  };

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _updateStatus(BuildContext context, LeadStatus newStatus) async {
    try {
      await service.updateLead(lead.id, status: newStatus.value);
      onReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showProvisionDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProvisionAccessDialog(lead: lead),
    );
    if (confirmed == true) {
      try {
        await service.updateLead(lead.id,
            status: LeadStatus.converted.value,
            adminNotes: '${lead.adminNotes ?? ''}\nAccess provisioned.'.trim());
        onReload();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access provisioned and lead marked as Converted.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _showNotesDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: lead.adminNotes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _NotesDialog(controller: ctrl),
    );
    if (saved != null) {
      try {
        await service.updateLead(lead.id, status: lead.status.value, adminNotes: saved);
        onReload();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }
}

// ─── Notes dialog ─────────────────────────────────────────────────────────────

class _NotesDialog extends StatelessWidget {
  final TextEditingController controller;
  const _NotesDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Internal notes — not visible to the lead.',
                style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Called on Monday, follow up next week...',
                hintStyle: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.adminPrimary)),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save Notes'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final LeadStatus status;
  const _StatusBadge(this.status);

  Color get _color => switch (status) {
    LeadStatus.newLead   => AppTheme.adminPrimary,
    LeadStatus.contacted => AppTheme.warning,
    LeadStatus.converted => AppTheme.success,
    LeadStatus.declined  => AppTheme.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

// ─── Provision Access Dialog ──────────────────────────────────────────────────

class _ProvisionAccessDialog extends StatefulWidget {
  final EnterpriseLead lead;
  const _ProvisionAccessDialog({required this.lead});

  @override
  State<_ProvisionAccessDialog> createState() => _ProvisionAccessDialogState();
}

class _ProvisionAccessDialogState extends State<_ProvisionAccessDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _orgService = OrganizationService();

  late final TextEditingController _emailCtrl;
  late final TextEditingController _propertiesCtrl;
  late final TextEditingController _usersCtrl;
  late final TextEditingController _roomsCtrl;
  late final TextEditingController _tablesCtrl;
  late final TextEditingController _monthlyCtrl;
  late final TextEditingController _annuallyCtrl;

  String _billingCycle = 'monthly'; // 'monthly' | 'annually'

  bool _saving = false;
  String? _error;
  bool _done = false;
  bool _invited = false; // true when we sent an invite instead of provisioning directly

  static const _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _emailCtrl      = TextEditingController(text: widget.lead.email);
    _propertiesCtrl = TextEditingController(
        text: widget.lead.propertyCount?.toString() ?? '1');
    _usersCtrl      = TextEditingController(text: '10');
    _roomsCtrl      = TextEditingController(text: '50');
    _tablesCtrl     = TextEditingController(text: '20');
    _monthlyCtrl    = TextEditingController();
    _annuallyCtrl   = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _propertiesCtrl.dispose();
    _usersCtrl.dispose();
    _roomsCtrl.dispose();
    _tablesCtrl.dispose();
    _monthlyCtrl.dispose();
    _annuallyCtrl.dispose();
    super.dispose();
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final email         = _emailCtrl.text.trim();
    final maxProperties = int.parse(_propertiesCtrl.text.trim());
    final maxUsers      = int.parse(_usersCtrl.text.trim());
    final maxRooms      = int.parse(_roomsCtrl.text.trim());
    final maxTables     = int.parse(_tablesCtrl.text.trim());
    final priceMonthly  = _monthlyCtrl.text.isNotEmpty
        ? double.tryParse(_monthlyCtrl.text.trim()) : null;
    final priceAnnually = _annuallyCtrl.text.isNotEmpty
        ? double.tryParse(_annuallyCtrl.text.trim()) : null;

    try {
      await _orgService.provisionCustomAccess(
        email:         email,
        maxProperties: maxProperties,
        maxUsers:      maxUsers,
        maxRooms:      maxRooms,
        maxTables:     maxTables,
        priceMonthly:  priceMonthly,
        priceAnnually: priceAnnually,
        billingCycle:  _billingCycle,
      );
      if (mounted) setState(() { _done = true; _saving = false; });
    } catch (e) {
      // Customer hasn't created an account yet — send them an invitation email
      // and store the provision config for auto-apply after onboarding.
      if (e.toString().contains('No account found')) {
        await _sendInvite(
          email:         email,
          maxProperties: maxProperties,
          maxUsers:      maxUsers,
          maxRooms:      maxRooms,
          maxTables:     maxTables,
          priceMonthly:  priceMonthly,
          priceAnnually: priceAnnually,
        );
      } else {
        if (mounted) setState(() { _error = e.toString(); _saving = false; });
      }
    }
  }

  Future<void> _sendInvite({
    required String email,
    required int maxProperties,
    required int maxUsers,
    required int maxRooms,
    required int maxTables,
    double? priceMonthly,
    double? priceAnnually,
  }) async {
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'invite-enterprise-user',
        body: {
          'email':         email,
          'maxProperties': maxProperties,
          'maxUsers':      maxUsers,
          'maxRooms':      maxRooms,
          'maxTables':     maxTables,
          'priceMonthly':  priceMonthly,
          'priceAnnually': priceAnnually,
          'billingCycle':  _billingCycle,
        },
      );

      if (resp.data is Map && (resp.data as Map).containsKey('error')) {
        throw Exception((resp.data as Map)['error']);
      }

      if (mounted) setState(() { _invited = true; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _done ? _buildSuccess() : _invited ? _buildInvited() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Access Provisioned!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text(
          '${_emailCtrl.text} has been upgraded to Enterprise with custom limits.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 24),
        _buildLimitSummary(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildInvited() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: _purple, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Invitation Sent!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text(
          'An invitation email has been sent to ${_emailCtrl.text}.\n'
          'Their enterprise plan will be activated automatically when they sign up.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitSummary() {
    final monthly  = _monthlyCtrl.text.isNotEmpty  ? '\$${_monthlyCtrl.text}/mo'   : null;
    final annually = _annuallyCtrl.text.isNotEmpty ? '\$${_annuallyCtrl.text}/yr'  : null;
    final billingLabel = _billingCycle == 'monthly'
        ? (monthly ?? '—')
        : (annually ?? '—');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.business_rounded,         'Properties', _propertiesCtrl.text),
          _summaryRow(Icons.people_rounded,            'Users',      _usersCtrl.text),
          _summaryRow(Icons.bed_rounded,               'Rooms',      _roomsCtrl.text),
          _summaryRow(Icons.table_restaurant_rounded,  'Tables',     _tablesCtrl.text),
          const Divider(height: 20),
          _summaryRow(Icons.payments_rounded,
              '${_billingCycle == 'monthly' ? 'Monthly' : 'Annual'} charge',
              billingLabel),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: _purple),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        const Spacer(),
        Text(value == '-1' ? 'Unlimited' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
      ]),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.build_circle_rounded, color: _purple, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Setup Custom Access',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                Text('Set limits for this customer\'s enterprise plan',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ),
            IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
          const SizedBox(height: 20),

          // Lead info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(child: Text('${widget.lead.name} · ${widget.lead.company}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B)))),
              if (widget.lead.message != null && widget.lead.message!.isNotEmpty)
                Tooltip(
                  message: widget.lead.message!,
                  child: const Icon(Icons.info_outline_rounded,
                      size: 15, color: Color(0xFF94A3B8)),
                ),
            ]),
          ),
          const SizedBox(height: 20),

          // Email field
          _fieldLabel('Customer Email', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDeco(
              hint: 'customer@example.com',
              icon: Icons.email_rounded,
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),

          // Limits grid
          _fieldLabel('Custom Limits  (use -1 for Unlimited)'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _limitField(_propertiesCtrl, Icons.business_rounded,      'Properties')),
            const SizedBox(width: 12),
            Expanded(child: _limitField(_usersCtrl,      Icons.people_rounded,         'Users')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _limitField(_roomsCtrl,  Icons.bed_rounded,             'Rooms')),
            const SizedBox(width: 12),
            Expanded(child: _limitField(_tablesCtrl, Icons.table_restaurant_rounded, 'Tables')),
          ]),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE8EDF3)),
          const SizedBox(height: 16),

          // Billing section
          _fieldLabel('Billing'),
          const SizedBox(height: 10),

          // Billing cycle toggle
          Row(children: [
            _cyclePill('monthly',   'Monthly'),
            const SizedBox(width: 8),
            _cyclePill('annually',  'Annually'),
          ]),
          const SizedBox(height: 12),

          // Price inputs — show both, highlight active
          Row(children: [
            Expanded(
              child: _priceField(
                ctrl:    _monthlyCtrl,
                label:   'Monthly Charge (LKR)',
                hint:    'e.g. 299.00',
                enabled: _billingCycle == 'monthly',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _priceField(
                ctrl:    _annuallyCtrl,
                label:   'Annual Charge (LKR)',
                hint:    'e.g. 2999.00',
                enabled: _billingCycle == 'annually',
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _billingCycle == 'monthly'
                ? 'Customer will be billed the monthly amount every month.'
                : 'Customer will be billed the annual amount once per year.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: TextStyle(fontSize: 12, color: AppTheme.danger))),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _provision,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(_saving ? 'Provisioning…' : 'Provision Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _limitField(TextEditingController ctrl, IconData icon, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569),
            fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
        style: const TextStyle(fontSize: 14),
        decoration: _inputDeco(hint: 'e.g. 10'),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          final n = int.tryParse(v);
          if (n == null) return 'Invalid';
          if (n != -1 && n < 1) return 'Min 1 or -1';
          return null;
        },
      ),
    ]);
  }

  Widget _cyclePill(String cycle, String label) {
    final selected = _billingCycle == cycle;
    return GestureDetector(
      onTap: () => setState(() => _billingCycle = cycle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _purple : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _purple : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _priceField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required bool enabled,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: enabled ? const Color(0xFF374151) : const Color(0xFFB0BAC7),
          )),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        style: TextStyle(
            fontSize: 14,
            color: enabled ? const Color(0xFF1E293B) : const Color(0xFFB0BAC7)),
        decoration: _inputDeco(hint: hint).copyWith(
          prefixIcon: null,
          prefixText: 'LKR ',
          prefixStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: enabled ? _purple.withOpacity(0.4) : const Color(0xFFE2E8F0)),
          ),
        ),
        validator: (v) {
          if (!enabled) return null;
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid amount';
          return null;
        },
      ),
    ]);
  }

  Widget _fieldLabel(String text, {bool required = false}) => Row(children: [
    Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: Color(0xFF374151))),
    if (required) ...[
      const SizedBox(width: 4),
      const Text('*', style: TextStyle(color: Colors.red, fontSize: 13)),
    ],
  ]);

  InputDecoration _inputDeco({String? hint, IconData? icon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
    prefixIcon: icon != null ? Icon(icon, size: 16, color: const Color(0xFF94A3B8)) : null,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _purple)),
    errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.danger)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.danger)),
  );
}
