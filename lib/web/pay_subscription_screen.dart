import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_auth_provider.dart';
import '../services/payhere_service.dart';

/// Payment screen shown to enterprise customers who have a custom price
/// configured by the superadmin. Reads `customPriceMonthly/Annually` from the
/// org and submits to PayHere with `planSlug = 'enterprise'`.
class PaySubscriptionScreen extends ConsumerStatefulWidget {
  const PaySubscriptionScreen({super.key});

  @override
  ConsumerState<PaySubscriptionScreen> createState() =>
      _PaySubscriptionScreenState();
}

class _PaySubscriptionScreenState
    extends ConsumerState<PaySubscriptionScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _phone     = TextEditingController();
  bool _paying = false;

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pay(String orgId, double amount, String cycle) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _paying = true);

    final messenger = ScaffoldMessenger.of(context);
    final isAnnual  = cycle == 'annually';
    // For enterprise renewals the amount IS the total billed amount (not per-month).
    // PayHereService.checkout multiplies by 12 when isAnnual is true, so we pass
    // the effective monthly equivalent so the total comes out correct.
    final monthlyEquivalent = isAnnual ? (amount / 12).round() : amount.round();

    try {
      await PayHereService.checkout(
        planName:  'Enterprise',
        planSlug:  'enterprise',
        amount:    monthlyEquivalent,
        isAnnual:  isAnnual,
        firstName: _firstName.text.trim(),
        lastName:  _lastName.text.trim(),
        email:     _email,
        phone:     _phone.text.trim(),
        orgId:     orgId,
      );
    } catch (e) {
      if (mounted) setState(() => _paying = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Payment initiation failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final org  = auth?.organization;

    // Guard: non-enterprise or no custom price → back to dashboard
    if (org == null || !org.hasCustomSubscription) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.block_rounded, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            const Text('No subscription payment required.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/app/dashboard'),
              child: const Text('Back to Dashboard'),
            ),
          ]),
        ),
      );
    }

    final amount = org.effectiveCustomPrice!;
    final cycle  = org.billingCycle ?? 'monthly';
    final label  = cycle == 'annually' ? 'Annual' : 'Monthly';
    final amountStr = amount.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  GestureDetector(
                    onTap: () => context.go('/app/dashboard'),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.black54),
                  ),
                  const SizedBox(width: 16),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pay Subscription',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    Text('Complete your Enterprise plan payment securely via PayHere.',
                        style: TextStyle(fontSize: 13, color: Colors.black45)),
                  ]),
                ]),
                const SizedBox(height: 32),

                // Plan summary card
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ENTERPRISE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: Color(0xFF8B5CF6), letterSpacing: 0.6)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Custom Plan',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981))),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LKR $amountStr',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A))),
                      Text('Billed $label · ${org.name}',
                          style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    ])),
                    const Icon(Icons.verified_user_rounded, size: 36, color: Color(0xFF8B5CF6)),
                  ]),
                ])),
                const SizedBox(height: 20),

                // Payment form
                _card(child: Form(
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

                    // Email (read-only)
                    TextFormField(
                      initialValue: _email,
                      readOnly: true,
                      decoration: _inputDeco('Email', readOnly: true),
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
                          Text('Enterprise · $label',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('Custom plan · ${org.name}',
                              style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        ])),
                        Text('LKR $amountStr',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _paying ? null : () => _pay(org.id, amount, cycle),
                        icon: _paying
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.payment_rounded, size: 18),
                        label: Text(
                          _paying ? 'Redirecting to PayHere…' : 'Pay LKR $amountStr',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text("After payment you'll be returned to your dashboard.",
                          style: TextStyle(fontSize: 11, color: Colors.black38)),
                    ),
                  ]),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.04), blurRadius: 8,
        offset: const Offset(0, 2),
      )],
    ),
    child: child,
  );

  InputDecoration _inputDeco(String label, {bool readOnly = false}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 13, color: Colors.black45),
    filled: readOnly,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
  );

  Widget _formField(TextEditingController ctrl, String label, {bool phone = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        decoration: _inputDeco(label),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      );
}
