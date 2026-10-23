import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../services/lead_service.dart';
import '../brand_kit.dart';
import '../cms/data/site_providers.dart';
import '../cms/model/json_reader.dart';
import '../cms/platform/open_external.dart';

typedef _Highlight = ({IconData icon, Color color, String title, String desc});

/// "Watch Demo" — a tabbed tour of what ships on day one.
///
/// Content is unchanged from the previous landing page; only the styling moved
/// onto the new kit.
class DemoDialog extends StatefulWidget {
  const DemoDialog({super.key});
  @override
  State<DemoDialog> createState() => _DemoDialogState();
}

class _DemoDialogState extends State<DemoDialog> {
  int _tab = 0;

  static const _tabs = ['Hotel', 'Restaurant', 'Guest Portal'];

  static const List<List<_Highlight>> _highlights = [
    [
      (icon: Icons.how_to_reg_rounded, color: Color(0xFF2563EB), title: 'One-click check-in', desc: 'Front desk checks in a guest in under 10 seconds — folio auto-generated, room assigned, key ready.'),
      (icon: Icons.king_bed_rounded, color: Color(0xFF16A34A), title: 'Live room availability', desc: 'Colour-coded room grid shows occupied, available and maintenance rooms in real time.'),
      (icon: Icons.receipt_long_rounded, color: LK.teal, title: 'Instant folio billing', desc: 'Auto-calculates room charges, extras and taxes — export to PDF with one click.'),
      (icon: Icons.people_alt_rounded, color: Color(0xFF7C3AED), title: 'Staff shift management', desc: 'Assign and track shifts, clock-ins and attendance — no third-party HR tool needed.'),
    ],
    [
      (icon: Icons.point_of_sale_rounded, color: LK.teal, title: 'Table-side ordering', desc: 'Waiters take orders on any device — sent instantly to the kitchen display, no paper tickets.'),
      (icon: Icons.kitchen_rounded, color: Color(0xFFE5484D), title: 'Kitchen display system', desc: 'KDS shows orders in real time, with timers and priority flags so chefs never miss a ticket.'),
      (icon: Icons.splitscreen_rounded, color: Color(0xFF16A34A), title: 'Split bills & payments', desc: 'Split any bill by item or equally across guests — supports cash, card and mixed payments.'),
      (icon: Icons.analytics_rounded, color: Color(0xFF0891B2), title: 'Sales analytics', desc: 'See your top-selling dishes, peak hours and daily revenue at a glance.'),
    ],
    [
      (icon: Icons.qr_code_2_rounded, color: Color(0xFF16A34A), title: 'QR self check-in', desc: 'Guests scan a QR at reception, fill in details on their phone and check in — no queue, no paperwork.'),
      (icon: Icons.room_service_rounded, color: LK.teal, title: 'Room service on phone', desc: 'Guests order food from their room by scanning a QR — the order goes straight to the kitchen.'),
      (icon: Icons.restaurant_menu_rounded, color: Color(0xFF2563EB), title: 'Digital table menu', desc: 'Diners scan a table QR, browse the menu and order — no app download required.'),
      (icon: Icons.no_accounts_rounded, color: Color(0xFF7C3AED), title: 'No app needed', desc: 'Everything runs in the mobile browser. Guests do not install anything.'),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 620;
    final items = _highlights[_tab];

    return Dialog(
      backgroundColor: LK.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('See HotRest in action', style: LK.h3(context).copyWith(fontSize: 22)),
                        const SizedBox(height: 4),
                        const Text('What you get — out of the box, day one.', style: LK.small),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: LK.muted),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: LK.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LK.line),
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final on = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 170),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? LK.navy : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            _tabs[i],
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: on ? Colors.white : LK.body,
                              fontSize: 13.5,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              // A wrapping flow rather than a fixed-ratio grid: the old grid
              // clipped the longer descriptions with an overflow fade.
              LayoutBuilder(builder: (_, c) {
                final w = narrow ? c.maxWidth : (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final it in items)
                      SizedBox(width: w, child: _HighlightTile(item: it)),
                  ],
                );
              }),
              const SizedBox(height: 22),
              CtaButton(
                label: 'Start 45-day free trial — no credit card',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/signup');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final _Highlight item;
  const _HighlightTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LK.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: LK.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.desc, style: LK.micro.copyWith(color: LK.body, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Enterprise "Contact Sales" form.
///
/// Submission path is unchanged: [LeadService.submitLead] with the same six
/// fields, same validation, same success state.
class EnterpriseContactDialog extends ConsumerStatefulWidget {
  const EnterpriseContactDialog({super.key});
  @override
  ConsumerState<EnterpriseContactDialog> createState() =>
      _EnterpriseContactDialogState();
}

class _EnterpriseContactDialogState
    extends ConsumerState<EnterpriseContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  final _propCount = TextEditingController();

  LeadService get _service => ref.read(leadServiceProvider);
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    _propCount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _service.submitLead(
        name: _name.text.trim(),
        company: _company.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        propertyCount: int.tryParse(_propCount.text.trim()),
        message: _message.text.trim(),
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send that: $e'), backgroundColor: LK.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LK.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: _submitted ? _success() : _form(),
        ),
      ),
    );
  }

  Widget _success() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: LK.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: LK.teal, size: 32),
          ),
          const SizedBox(height: 20),
          Text('Request received', style: LK.h3(context).copyWith(fontSize: 22)),
          const SizedBox(height: 10),
          const Text(
            'Thank you for reaching out. Our team will contact you within 1–2 '
            'business days to discuss your requirements.',
            textAlign: TextAlign.center,
            style: LK.small,
          ),
          const SizedBox(height: 26),
          CtaButton(
            label: 'Close',
            expand: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );

  Widget _form() => Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LK.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: LK.navy, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contact sales', style: LK.h3(context)),
                        const Text("We'll get back to you within 24 hours.", style: LK.micro),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: LK.muted),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _field(_name, 'Full name', required: true),
              _field(_company, 'Company / hotel group', required: true),
              _field(_email, 'Work email', required: true, email: true),
              _field(_phone, 'Phone number'),
              _field(_propCount, 'Number of properties', number: true),
              _field(_message, 'Tell us about your needs', maxLines: 3),
              const SizedBox(height: 8),
              _submitting
                  ? const SizedBox(
                      height: 52,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: LK.navy),
                        ),
                      ),
                    )
                  : CtaButton(label: 'Send request', expand: true, onTap: _submit),
            ],
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    bool email = false,
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14.5, color: LK.ink),
        keyboardType: number
            ? TextInputType.number
            : email
                ? TextInputType.emailAddress
                : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Outfit', color: LK.muted, fontSize: 14),
          floatingLabelStyle: const TextStyle(fontFamily: 'Outfit', color: LK.teal),
          filled: true,
          fillColor: LK.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: LK.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: LK.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: LK.teal, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (email && !v.contains('@')) return 'Enter a valid email';
                return null;
              }
            : null,
      ),
    );
  }
}

/// Floating WhatsApp contact pill.
///
/// Renders only when a real number has been set in the site settings. The first
/// version shipped the placeholder `94XXXXXXXXX`, so the button opened a dead
/// wa.me link — worse on a sales page than no button at all. A number that is not
/// 8 to 15 digits is treated as not set.
class WhatsAppFab extends ConsumerStatefulWidget {
  const WhatsAppFab({super.key});

  /// International format, digits only, no '+' or spaces.
  static bool isValidNumber(String n) => RegExp(r'^[0-9]{8,15}$').hasMatch(n);

  @override
  ConsumerState<WhatsAppFab> createState() => _WhatsAppFabState();
}

class _WhatsAppFabState extends ConsumerState<WhatsAppFab> {
  bool _hover = false;

  void _open(String number, String message) {
    final uri = Uri.encodeFull('https://wa.me/$number?text=$message');
    openExternal(uri);
  }

  @override
  Widget build(BuildContext context) {
    final site = J.of(ref.watch(siteRawProvider('global:site')));
    final number = site.str('whatsappNumber').trim();
    if (!WhatsAppFab.isValidNumber(number)) return const SizedBox.shrink();
    final message = site.str('whatsappMessage');
    final label = site.str('whatsappLabel', 'Chat with us');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _open(number, message),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1FAD54),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1FAD54).withValues(alpha: _hover ? 0.42 : 0.26),
                blurRadius: _hover ? 26 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 19),
              AnimatedSize(
                duration: const Duration(milliseconds: 190),
                child: _hover && label.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
