import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import '../../services/plan_service.dart';
import '../../services/lead_service.dart';
import '../../providers/service_providers.dart';
import '../semantic_palette.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

/// Shows the upgrade plan dialog. Pass [blockedResource] to display a context
/// message (e.g. "rooms", "tables", "team members", "properties").
Future<bool> showUpgradePlanDialog(
  BuildContext context,
  WidgetRef ref, {
  String? blockedResource,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => UpgradePlanDialog(ref: ref, blockedResource: blockedResource),
  );
  return result == true;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class UpgradePlanDialog extends StatefulWidget {
  final WidgetRef ref;
  final String? blockedResource;
  const UpgradePlanDialog({super.key, required this.ref, this.blockedResource});

  @override
  State<UpgradePlanDialog> createState() => _UpgradePlanDialogState();
}

class _UpgradePlanDialogState extends State<UpgradePlanDialog> {
  PlanService get _planService => widget.ref.read(planServiceProvider);
  List<PlanModel> _plans = [];
  bool _loading = true;
  String? _selectedSlug;
  String? _error;

  String get _currentSlug =>
      widget.ref.read(authProvider).valueOrNull?.organization?.plan ?? 'starter';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await _planService.getActivePlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  void _upgrade() {
    if (_selectedSlug == null || _selectedSlug == _currentSlug) return;
    final slug = _selectedSlug!;
    // Close the dialog first, then navigate — plan is only updated after
    // successful PayHere payment via the payhere-notify webhook.
    Navigator.of(context).pop(false);
    context.go('/app/upgrade?plan=$slug');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 6),
              if (widget.blockedResource != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'You have reached the ${widget.blockedResource} limit on your current plan. '
                    'Upgrade to unlock higher limits.',
                    style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13),
                  ),
                )
              else
                const SizedBox(height: 18),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              else
                _buildPlansRow(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 20),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.adminPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.rocket_launch_rounded, color: AppTheme.adminPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upgrade Your Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('Choose a plan that fits your needs',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildPlansRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _plans.map((p) => _PlanCard(
          plan: p,
          isCurrent: p.slug == _currentSlug,
          isSelected: p.slug == _selectedSlug,
          onTap: p.isCustomPrice || p.slug == _currentSlug
              ? null
              : () => setState(() => _selectedSlug = p.slug),
          onContactUs: p.isCustomPrice ? _showContactForm : null,
        )).toList(),
      ),
    );
  }

  void _showContactForm() {
    final authState = widget.ref.read(authProvider).valueOrNull;
    Navigator.of(context).pop(false); // close upgrade dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EnterpriseContactForm(
        prefillEmail: authState?.email,
        prefillName:  authState?.organization?.name,
      ),
    );
  }

  Widget _buildFooter() {
    final isEnterprise = _selectedSlug != null &&
        _plans.firstWhere((p) => p.slug == _selectedSlug,
            orElse: () => _plans.first).isCustomPrice;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _selectedSlug == null || _selectedSlug == _currentSlug
              ? null
              : _upgrade,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.adminPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(isEnterprise ? 'Contact Sales' : 'Continue to Payment'),
        ),
      ],
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onContactUs;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
    this.onContactUs,
  });

  static const _accentGold  = Color(0xFFD4A853);
  static const _accentBlue  = Color(0xFF3B82F6);
  static const _accentGreen = Color(0xFF10B981);
  static const _accentPurple = Color(0xFF8B5CF6);

  Color get _accent => SemanticPalette.tier(plan.slug);

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? _accent
        : isCurrent
            ? _accent.withOpacity(0.4)
            : Colors.grey.shade200;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 168,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withOpacity(0.05) : Colors.white,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: _accent.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(plan.name.toUpperCase(),
                        style: TextStyle(color: _accent, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                  const Spacer(),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Current', style: TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  if (plan.isHighlighted && !isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Popular', style: TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Price
              if (plan.isCustomPrice)
                Text('Custom', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _accent))
              else ...[
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: '\$${plan.priceMonthly.toInt()}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                              color: _accent, fontFamily: 'Roboto')),
                      const TextSpan(text: '/mo',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Roboto')),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Limits
              _limitRow(Icons.business_rounded, 'Properties', plan.maxProperties),
              _limitRow(Icons.people_rounded,   'Users',       plan.maxUsers),
              _limitRow(Icons.bed_rounded,       'Rooms',       plan.maxRooms),
              _limitRow(Icons.table_restaurant_rounded, 'Tables', plan.maxTables),
              const SizedBox(height: 12),
              // Select indicator
              if (isSelected)
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: _accent, size: 16),
                    const SizedBox(width: 6),
                    Text('Selected', style: TextStyle(color: _accent, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ],
                )
              else if (!isCurrent && onTap != null)
                Row(
                  children: [
                    Icon(Icons.radio_button_unchecked_rounded,
                        color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 6),
                    Text('Select', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                )
              else if (plan.isCustomPrice)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onContactUs,
                    icon: const Icon(Icons.mail_outline_rounded, size: 14),
                    label: const Text('Contact Us', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _limitRow(IconData icon, String label, int value) {
    final text = value == -1 ? 'Unlimited' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Text(text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: value == -1 ? _accent : Colors.black87)),
        ],
      ),
    );
  }
}

// ─── Enterprise Contact Form ──────────────────────────────────────────────────

class _EnterpriseContactForm extends ConsumerStatefulWidget {
  final String? prefillEmail;
  final String? prefillName;
  const _EnterpriseContactForm({this.prefillEmail, this.prefillName});

  @override
  ConsumerState<_EnterpriseContactForm> createState() => _EnterpriseContactFormState();
}

class _EnterpriseContactFormState extends ConsumerState<_EnterpriseContactForm> {
  final _formKey  = GlobalKey<FormState>();
  LeadService get _service => ref.read(leadServiceProvider);

  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _properties;
  late final TextEditingController _message;

  bool _submitting = false;
  bool _submitted  = false;

  static const _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _name       = TextEditingController(text: widget.prefillName ?? '');
    _company    = TextEditingController();
    _email      = TextEditingController(text: widget.prefillEmail ?? '');
    _phone      = TextEditingController();
    _properties = TextEditingController();
    _message    = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _email, _phone, _properties, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _service.submitLead(
        name:          _name.text.trim(),
        company:       _company.text.trim(),
        email:         _email.text.trim(),
        phone:         _phone.text.trim(),
        propertyCount: int.tryParse(_properties.text.trim()),
        message:       _message.text.trim(),
      );
      if (mounted) setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _submitted ? _buildSuccess() : _buildForm(),
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
              color: _purple.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: _purple, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Request Sent!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Our team will review your request and get back to you shortly with a custom quote.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
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
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.diamond_rounded, color: _purple, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Get a Custom Quote',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                Text('Tell us about your needs — we\'ll tailor a plan for you.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(child: _field(_name,    'Name *',    'Your full name')),
            const SizedBox(width: 12),
            Expanded(child: _field(_company, 'Company *', 'Company name')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_email, 'Email *', 'you@company.com',
                type: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email' : null)),
            const SizedBox(width: 12),
            Expanded(child: _field(_phone, 'Phone', '+1 234 567 8900',
                required: false, type: TextInputType.phone)),
          ]),
          const SizedBox(height: 12),
          _field(_properties, 'Number of Properties',
              'How many properties do you manage?',
              required: false, type: TextInputType.number),
          const SizedBox(height: 12),
          _field(_message, 'Message', 'Tell us about your requirements...',
              required: false, maxLines: 4),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool required = true,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _purple)),
          ),
          validator: validator ?? (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
        ),
      ],
    );
  }
}
