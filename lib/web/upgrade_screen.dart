import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../providers/app_auth_provider.dart';
import '../services/plan_service.dart';
import '../providers/service_providers.dart';
import '../services/payhere_service.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  final String? plan; // slug from query param, e.g. "starter" or "pro"
  const UpgradeScreen({super.key, this.plan});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  late Future<List<PlanModel>> _plansFuture;
  PlanModel? _selected;
  bool _isAnnual = false;

  final _formKey   = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _phone     = TextEditingController();
  bool _paying = false;

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    // Use the org's rate-locked prices when available so the displayed (and
    // charged) amount matches the org's locked book; falls back to live prices.
    final orgId = ref.read(authProvider).valueOrNull?.organization?.id;
    final plansFetch = orgId != null
        ? ref.read(planServiceProvider).getActivePlansForOrg(orgId)
        : ref.read(planServiceProvider).getActivePlans();
    _plansFuture = plansFetch.then((plans) {
      // currentSlug is read here via a one-time ref.read inside initState is
      // not available — we re-filter in build() using the live auth state.
      final paid = plans
          .where((p) => p.priceMonthly > 0 && !p.isCustomPrice)
          .toList();
      _selected = paid.firstWhere(
        (p) => p.slug == widget.plan,
        orElse: () => paid.isNotEmpty ? paid.first : plans.first,
      );
      return plans;
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_selected == null) return;
    if (!_formKey.currentState!.validate()) return;

    final orgId = ref.read(authProvider).valueOrNull?.organization?.id;
    if (orgId == null) return;

    setState(() => _paying = true);

    // Capture messenger before the async gap — widget may be deactivated by the
    // time the Edge Function responds (GoRouter can redirect mid-flight).
    final messenger = ScaffoldMessenger.of(context);

    final effectiveAmount = _isAnnual
        ? (_selected!.priceMonthly * 0.8).round()
        : _selected!.priceMonthly.round();

    try {
      await PayHereService.checkout(
        planName:  _selected!.name,
        planSlug:  _selected!.slug,
        amount:    effectiveAmount,
        isAnnual:  _isAnnual,
        firstName: _firstName.text.trim(),
        lastName:  _lastName.text.trim(),
        email:     _email,
        phone:     _phone.text.trim(),
        orgId:     orgId,
      );
    } catch (e) {
      if (mounted) setState(() => _paying = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Payment initiation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: FutureBuilder<List<PlanModel>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.black26),
                const SizedBox(height: 16),
                const Text('Could not load plans. Please try again.',
                    style: TextStyle(fontSize: 15, color: Colors.black54)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _plansFuture = ref.read(planServiceProvider).getActivePlans();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ]),
            );
          }
          final allPlans    = snapshot.data ?? [];
          final currentSlug = ref.watch(authProvider).valueOrNull?.organization?.plan ?? 'starter';
          final currentPlan = allPlans.firstWhere(
            (p) => p.slug == currentSlug,
            // Fallback only if the current plan isn't in the active list
            // (e.g. a retired slug); sortOrder 0 keeps every active plan an upgrade.
            orElse: () => PlanModel(
              id: '',
              name: currentSlug.isEmpty
                  ? currentSlug
                  : currentSlug[0].toUpperCase() + currentSlug.substring(1),
              slug: currentSlug, priceMonthly: 0,
              isCustomPrice: false, maxProperties: 1, maxUsers: 3,
              maxRooms: 10, maxTables: 5, isHighlighted: false,
              isActive: true, sortOrder: 0,
            ),
          );

          // Only show plans the user can actually upgrade to
          final plans = allPlans
              .where((p) =>
                  p.priceMonthly > 0 &&
                  !p.isCustomPrice &&
                  p.sortOrder > currentPlan.sortOrder)
              .toList();

          if (plans.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF7C3AED)),
                const SizedBox(height: 16),
                Text("You're on the ${currentPlan.name} plan",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text("You're already on the highest available plan.\nContact us if you need Enterprise.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
              ]),
            );
          }
          _selected ??= plans.first;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    LayoutBuilder(builder: (_, c) {
                      if (c.maxWidth > 580) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildPlanSelector(plans)),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: _buildPaymentForm()),
                          ],
                        );
                      }
                      return Column(children: [
                        _buildPlanSelector(plans),
                        const SizedBox(height: 20),
                        _buildPaymentForm(),
                      ]);
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      GestureDetector(
        onTap: () => context.go('/app/dashboard'),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.black54),
      ),
      const SizedBox(width: 16),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Upgrade Your Plan',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        Text('Choose a plan and complete your payment securely via PayHere.',
            style: TextStyle(fontSize: 13, color: Colors.black45)),
      ]),
    ]);
  }

  Widget _buildPlanSelector(List<PlanModel> plans) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Billing toggle ──
      _card(child: Row(children: [
        const Text('Billing:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 14),
        _toggleChip('Monthly', !_isAnnual, () => setState(() => _isAnnual = false)),
        const SizedBox(width: 8),
        _toggleChip('Annual  (save 20%)', _isAnnual, () => setState(() => _isAnnual = true)),
      ])),
      const SizedBox(height: 16),

      // ── Plan cards ──
      ...plans.map((p) {
        final effective = _isAnnual
            ? (p.priceMonthly * 0.8).round()
            : p.priceMonthly.round();
        final isSelected = _selected?.slug == p.slug;
        return GestureDetector(
          onTap: () => setState(() => _selected = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.adminPrimary.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.adminPrimary : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.adminPrimary : Colors.black26,
                    width: 2,
                  ),
                  color: isSelected ? AppTheme.adminPrimary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(p.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  if (p.isHighlighted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Most Popular',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  'LKR $effective / mo${_isAnnual ? " · billed LKR ${effective * 12}/yr" : ""}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ])),
              Text('LKR $effective',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.adminPrimary : Colors.black54,
                  )),
            ]),
          ),
        );
      }),

      // ── What's included ──
      if (_selected != null) ...[
        const SizedBox(height: 4),
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("What's included",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
          const SizedBox(height: 10),
          ..._features(_selected!).map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Text(f, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          )),
        ])),
      ],
    ]);
  }

  Widget _buildPaymentForm() {
    final effective = _selected == null
        ? 0
        : _isAnnual
            ? (_selected!.priceMonthly * 0.8).round()
            : _selected!.priceMonthly.round();
    final billing = _isAnnual ? effective * 12 : effective;

    return _card(child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: Colors.black38),
          SizedBox(width: 8),
          Text('Payment Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        const Text('Secured by PayHere · 256-bit SSL',
            style: TextStyle(fontSize: 11, color: Colors.black38)),
        const SizedBox(height: 20),

        // Email (read-only, pre-filled)
        _field(
          label: 'Email',
          initialValue: _email,
          readOnly: true,
          hint: _email,
        ),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: _formField(_firstName, 'First Name')),
          const SizedBox(width: 12),
          Expanded(child: _formField(_lastName, 'Last Name')),
        ]),
        const SizedBox(height: 14),
        _formField(_phone, 'Phone (e.g. 0771234567)', phone: true),
        const SizedBox(height: 24),

        // Order summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.black38),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${_selected?.name ?? "—"} · ${_isAnnual ? "Annual" : "Monthly"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                _isAnnual ? 'Billed as LKR $billing / year' : 'Billed as LKR $billing / month',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ])),
            Text('LKR $billing',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_paying || _selected == null) ? null : _pay,
            icon: _paying
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.payment_rounded, size: 18),
            label: Text(
              _paying ? 'Redirecting to PayHere…' : 'Pay LKR $billing',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('After payment you\'ll be returned to your dashboard.',
              style: TextStyle(fontSize: 11, color: Colors.black38)),
        ),
      ]),
    ));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.adminPrimary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black45,
              )),
        ),
      );

  Widget _field({required String label, String? hint, String? initialValue, bool readOnly = false}) =>
      TextFormField(
        initialValue: initialValue,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.black45),
          filled: readOnly,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.adminPrimary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      );

  Widget _formField(TextEditingController ctrl, String label, {bool phone = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.black45),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.adminPrimary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      );

  List<String> _features(PlanModel p) {
    String lim(int v) => v == -1 ? 'Unlimited' : '$v';
    return [
      '${lim(p.maxProperties)} ${p.maxProperties == 1 ? "property" : "properties"}',
      '${lim(p.maxRooms)} rooms',
      '${lim(p.maxUsers)} staff accounts',
      '${lim(p.maxTables)} restaurant tables',
      'Hotel + Restaurant modules',
      'Guest portal (QR check-in & menu)',
      'White-label branding',
    ];
  }
}
