import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';
import '../../services/lead_service.dart';
import '../brand_kit.dart';
import '../cms/chrome/dialog_content.dart';
import '../cms/data/site_providers.dart';
import '../cms/defaults/site_defaults.dart';
import '../cms/model/json_reader.dart';
import '../cms/render/link_action.dart';
import '../cms/platform/open_external.dart';

/// "Watch Demo" — a tabbed tour of what ships on day one. Its wording comes from
/// the `global:dialogs` document; [content] overrides that (the studio previews a
/// draft this way).
class DemoDialog extends ConsumerStatefulWidget {
  const DemoDialog({super.key, this.content});

  final DemoContent? content;

  @override
  ConsumerState<DemoDialog> createState() => _DemoDialogState();
}

class _DemoDialogState extends ConsumerState<DemoDialog> {
  int _tab = 0;

  DemoContent _content() {
    if (widget.content != null) return widget.content!;
    final raw = J.of(ref.watch(siteRawProvider('global:dialogs'))).obj('demo');
    final c = DemoContent.fromJson(raw);
    // A published document that parses to no tabs would show an empty dialog.
    return c.tabs.isEmpty ? DemoContent.fromJson(J.of(siteDefaultJson('global:dialogs')).obj('demo')) : c;
  }

  @override
  Widget build(BuildContext context) {
    final c = _content();
    final narrow = MediaQuery.sizeOf(context).width < 620;
    final tab = _tab.clamp(0, c.tabs.length - 1);
    final items = c.tabs[tab].items;

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
                        Text(c.title, style: LK.h3(context).copyWith(fontSize: 22)),
                        if (c.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(c.subtitle, style: LK.small),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: LK.muted),
                    tooltip: c.closeLabel,
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
                  children: List.generate(c.tabs.length, (i) {
                    final on = tab == i;
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
                            c.tabs[i].name,
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
              if (c.ctaLabel.isNotEmpty && !c.ctaLink.isNone)
                CtaButton(
                  label: c.ctaLabel,
                  icon: Icons.arrow_forward_rounded,
                  expand: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    runLink(context, c.ctaLink);
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
  final DemoHighlight item;
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
  const EnterpriseContactDialog({super.key, this.content, this.preview = false});

  /// Overrides the wording from the `global:dialogs` document (studio preview).
  final ContactContent? content;

  /// In the studio preview, submitting shows the success step and sends nothing.
  final bool preview;

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

  ContactContent _content() {
    if (widget.content != null) return widget.content!;
    return ContactContent.fromJson(J.of(ref.watch(siteRawProvider('global:dialogs'))).obj('contact'));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.preview) {
      setState(() => _submitted = true);
      return;
    }
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
          child: _submitted ? _success(_content()) : _form(_content()),
        ),
      ),
    );
  }

  Widget _success(ContactContent c) => Column(
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
          Text(c.successTitle, style: LK.h3(context).copyWith(fontSize: 22)),
          const SizedBox(height: 10),
          Text(
            c.successBody,
            textAlign: TextAlign.center,
            style: LK.small,
          ),
          const SizedBox(height: 26),
          CtaButton(
            label: c.successClose,
            expand: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );

  Widget _form(ContactContent c) => Form(
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
                        Text(c.title, style: LK.h3(context)),
                        if (c.subtitle.isNotEmpty) Text(c.subtitle, style: LK.micro),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: LK.muted),
                    tooltip: c.closeLabel,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _field(_name, c.nameLabel, required: true),
              _field(_company, c.companyLabel, required: true),
              _field(_email, c.emailLabel, required: true, email: true),
              _field(_phone, c.phoneLabel),
              _field(_propCount, c.propertiesLabel, number: true),
              _field(_message, c.messageLabel, maxLines: 3),
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
                  : CtaButton(label: c.submitLabel, expand: true, onTap: _submit),
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
