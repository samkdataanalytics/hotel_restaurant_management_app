import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../services/plan_service.dart';

class SuperadminPlansScreen extends StatefulWidget {
  const SuperadminPlansScreen({super.key});

  @override
  State<SuperadminPlansScreen> createState() => _SuperadminPlansScreenState();
}

class _SuperadminPlansScreenState extends State<SuperadminPlansScreen> {
  late Future<List<PlanModel>> _future;
  final _service = PlanService();

  @override
  void initState() {
    super.initState();
    _future = _service.getAllPlans();
  }

  void _reload() => setState(() { _future = _service.getAllPlans(); });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pageBg,
      child: FutureBuilder<List<PlanModel>>(
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
                  Text('Failed to load plans',
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

          final plans = snapshot.data ?? [];
          return _PlansContent(plans: plans, service: _service, onSaved: _reload);
        },
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _PlansContent extends StatelessWidget {
  final List<PlanModel> plans;
  final PlanService service;
  final VoidCallback onSaved;

  const _PlansContent({
    required this.plans,
    required this.service,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Pricing Plans',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure up to 4 pricing tiers. Changes reflect immediately on the landing page.',
            style: TextStyle(fontSize: 14, color: AppTheme.adminTextMuted),
          ),
          const SizedBox(height: 28),

          // Plan cards
          LayoutBuilder(builder: (_, constraints) {
            final wide = constraints.maxWidth > 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: plans
                    .map((p) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: p == plans.last ? 0 : 16),
                            child: _PlanEditorCard(
                                plan: p, service: service, onSaved: onSaved),
                          ),
                        ))
                    .toList(),
              );
            }
            return Column(
              children: plans
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PlanEditorCard(
                            plan: p, service: service, onSaved: onSaved),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Plan editor card ─────────────────────────────────────────────────────────

class _PlanEditorCard extends StatefulWidget {
  final PlanModel plan;
  final PlanService service;
  final VoidCallback onSaved;

  const _PlanEditorCard({
    required this.plan,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_PlanEditorCard> createState() => _PlanEditorCardState();
}

class _PlanEditorCardState extends State<_PlanEditorCard> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _maxProps;
  late TextEditingController _maxUsers;
  late TextEditingController _maxRooms;
  late TextEditingController _maxTables;
  late bool _isCustomPrice;
  late bool _isHighlighted;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name        = TextEditingController(text: p.name);
    _price       = TextEditingController(text: p.priceMonthly == 0 ? '0' : p.priceMonthly.toStringAsFixed(0));
    _maxProps    = TextEditingController(text: p.maxProperties.toString());
    _maxUsers    = TextEditingController(text: p.maxUsers.toString());
    _maxRooms    = TextEditingController(text: p.maxRooms.toString());
    _maxTables   = TextEditingController(text: p.maxTables.toString());
    _isCustomPrice = p.isCustomPrice;
    _isHighlighted = p.isHighlighted;
    _isActive      = p.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _maxProps.dispose();
    _maxUsers.dispose();
    _maxRooms.dispose();
    _maxTables.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = widget.plan.copyWith(
        name:          _name.text.trim(),
        priceMonthly:  double.tryParse(_price.text) ?? 0,
        isCustomPrice: _isCustomPrice,
        maxProperties: int.tryParse(_maxProps.text) ?? 1,
        maxUsers:      int.tryParse(_maxUsers.text) ?? 5,
        maxRooms:      int.tryParse(_maxRooms.text) ?? 20,
        maxTables:     int.tryParse(_maxTables.text) ?? 5,
        isHighlighted: _isHighlighted,
        isActive:      _isActive,
      );
      await widget.service.savePlan(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updated.name} plan saved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.plan.slug == 'free';
    final accentColor = _isHighlighted ? AppTheme.goldPrimary : AppTheme.adminPrimary;

    final borderColor = _isHighlighted ? AppTheme.goldPrimary : const Color(0xFFE8EDF3);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    isFree ? 'FREE TIER' : 'PLAN ${widget.plan.sortOrder}',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                // Active toggle
                Row(
                  children: [
                    Text('Active', style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                    const SizedBox(width: 6),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeThumbColor: AppTheme.success,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Plan name
            _label('Plan Name'),
            _field(_name, hint: 'e.g. Starter', validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),

            // Price row
            _label('Monthly Price (\$)'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _price,
                    hint: '0',
                    numeric: true,
                    enabled: !_isCustomPrice,
                    validator: (v) {
                      if (_isCustomPrice) return null;
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text('Custom', style: TextStyle(fontSize: 11, color: AppTheme.adminTextMuted)),
                    Switch(
                      value: _isCustomPrice,
                      onChanged: (v) => setState(() => _isCustomPrice = v),
                      activeThumbColor: accentColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Limits
            _label('Limits  (-1 = Unlimited)'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _limitField(_maxProps, 'Properties', Icons.apartment_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _limitField(_maxUsers, 'Users', Icons.people_rounded)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _limitField(_maxRooms, 'Rooms', Icons.king_bed_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _limitField(_maxTables, 'Tables', Icons.table_restaurant_rounded)),
            ]),
            const SizedBox(height: 16),

            // Highlighted toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: AppTheme.goldPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"Most Popular" badge',
                      style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Switch(
                    value: _isHighlighted,
                    onChanged: (v) => setState(() => _isHighlighted = v),
                    activeThumbColor: AppTheme.goldPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
      ),
    ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.adminTextMuted)),
      );

  Widget _field(
    TextEditingController ctrl, {
    required String hint,
    bool numeric = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13),
          filled: true,
          fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF0F0F0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.adminPrimary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.danger),
          ),
        ),
      );

  Widget _limitField(TextEditingController ctrl, String label, IconData icon) => TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]'))],
        validator: (v) {
          if (v == null || v.isEmpty || v == '-') return 'Required';
          if (int.tryParse(v) == null) return 'Invalid';
          return null;
        },
        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
          prefixIcon: Icon(icon, size: 16, color: AppTheme.adminTextMuted),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.adminPrimary),
          ),
        ),
      );
}
