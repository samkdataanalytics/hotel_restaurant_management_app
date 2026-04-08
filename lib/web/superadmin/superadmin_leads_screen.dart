import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/lead_service.dart';

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
          Row(children: [
            const Expanded(
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
            const SizedBox(width: 8),
            _StatusBadge(LeadStatus.contacted),
            const SizedBox(width: 8),
            _StatusBadge(LeadStatus.converted),
            const SizedBox(width: 8),
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
