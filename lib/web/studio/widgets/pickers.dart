import 'package:flutter/material.dart';

import '../../cms/model/color_ref.dart';
import '../../cms/model/json_reader.dart';
import '../../cms/model/link_target.dart';
import '../../cms/registry/icon_registry.dart';
import '../studio_theme.dart';
import 'synced_field.dart';

// ── Icon ─────────────────────────────────────────────────────────────────────

class IconPickerField extends StatelessWidget {
  const IconPickerField({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = IconRegistry.isKnown(value);
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDialog<String>(
              context: context,
              builder: (_) => _IconDialog(current: value),
            );
            if (picked != null) onChanged(picked.isEmpty ? null : picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SC.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(known ? IconRegistry.resolve(value) : Icons.add_reaction_outlined,
                    size: 20, color: known ? SC.accent : SC.faint),
                const SizedBox(width: 10),
                Text(known ? _pretty(value) : (value.isEmpty ? 'Choose icon' : 'Unknown: $value'),
                    style: SC.body.copyWith(color: known || value.isEmpty ? SC.text : SC.danger)),
                const SizedBox(width: 6),
                const Icon(Icons.unfold_more_rounded, size: 16, color: SC.faint),
              ],
            ),
          ),
        ),
        if (value.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close_rounded, size: 16, color: SC.faint),
          ),
      ],
    );
  }

  static String _pretty(String n) =>
      n.replaceAll('_rounded', '').replaceAll('_outline', '').replaceAll('_', ' ');
}

class _IconDialog extends StatefulWidget {
  const _IconDialog({required this.current});

  final String current;

  @override
  State<_IconDialog> createState() => _IconDialogState();
}

class _IconDialogState extends State<_IconDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final names = IconRegistry.names
        .where((n) => _q.isEmpty || n.contains(_q.toLowerCase().replaceAll(' ', '_')))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 460,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Choose an icon', style: SC.title),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                style: SC.body,
                onChanged: (v) => setState(() => _q = v),
                decoration: SC.input(hint: 'Search icons').copyWith(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: names.isEmpty
                    ? const Center(child: Text('No icons match.', style: SC.small))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 64,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: names.length,
                        itemBuilder: (_, i) {
                          final n = names[i];
                          final sel = n == widget.current;
                          return Tooltip(
                            message: IconPickerField._pretty(n),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(context, n),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: sel ? SC.accentBg : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: sel ? SC.accent : SC.border),
                                ),
                                child: Icon(IconRegistry.resolve(n),
                                    size: 24, color: sel ? SC.accent : SC.text),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Colour ───────────────────────────────────────────────────────────────────

class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.value, required this.onChanged, this.error});

  final String value;
  final ValueChanged<String?> onChanged;
  final String? error;

  /// The brand palette plus black and white, one tap each.
  static const swatches = [
    '#012C58', // navy
    '#0A7D77', // teal
    '#0D9B94', // teal, as drawn in the logo
    '#3FBDB4', // teal on dark
    '#0A1424', // ink
    '#F7F9FC', // surface
    '#FFFFFF',
    '#000000',
  ];

  @override
  Widget build(BuildContext context) {
    final c = parseHexColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c ?? Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SC.border),
              ),
              child: c == null ? const Icon(Icons.format_color_reset_rounded, size: 16, color: SC.faint) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SyncedTextField(
                value: value,
                hint: '#RRGGBB',
                maxLength: 7,
                error: error,
                onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
              ),
            ),
            if (value.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 16, color: SC.faint),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final hex in swatches)
              Tooltip(
                message: hex,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onChanged(hex),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: parseHexColor(hex),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: value.toUpperCase() == hex ? SC.accent : SC.border,
                        width: value.toUpperCase() == hex ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Link ─────────────────────────────────────────────────────────────────────

const _linkTypes = {
  'none': 'No link',
  'internal': 'A page on this site',
  'external': 'A web address',
  'anchor': 'A section on this page',
  'action': 'An action',
};

const _routeLabels = {
  '/': 'Home',
  '/signup': 'Sign up',
  '/login': 'Sign in',
  '/help': 'Help centre',
  '/terms': 'Terms of service',
  '/privacy': 'Privacy policy',
  '/returns': 'Refund policy',
};

const _actionLabels = {
  'signup': 'Go to sign-up',
  'login': 'Go to sign-in',
  'openDemo': 'Open the demo request form',
  'openContactSales': 'Open the contact-sales form',
};

class LinkField extends StatelessWidget {
  const LinkField({
    super.key,
    required this.value,
    required this.onChanged,
    this.anchors = const [],
    this.error,
  });

  final Object? value;
  final ValueChanged<Map<String, Object?>?> onChanged;
  final List<String> anchors;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final j = J.of(value);
    final type = _linkTypes.containsKey(j.str('type')) ? j.str('type') : 'none';
    final val = j.str('value');
    final target = LinkTarget.fromJson(j);

    void emit(String t, String v, {bool? newTab}) {
      if (t == 'none') return onChanged(null);
      onChanged({
        'type': t,
        'value': v,
        if (t == 'external') 'newTab': newTab ?? j.flag('newTab'),
      });
    }

    String firstOf(String t) => switch (t) {
          'internal' => '/signup',
          'anchor' => anchors.isEmpty ? '' : anchors.first,
          'action' => 'signup',
          _ => '',
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(type),
          initialValue: type,
          isExpanded: true,
          decoration: SC.input(),
          style: SC.body,
          items: [
            for (final e in _linkTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (t) => t == null ? null : emit(t, t == type ? val : firstOf(t)),
        ),
        const SizedBox(height: 8),
        switch (type) {
          'internal' => DropdownButtonFormField<String>(
              key: ValueKey(_routeLabels.containsKey(val.split('?').first) ? val.split('?').first : null),
              initialValue: _routeLabels.containsKey(val.split('?').first) ? val.split('?').first : null,
              isExpanded: true,
              decoration: SC.input(hint: 'Choose a page', error: error),
              style: SC.body,
              items: [
                for (final e in _routeLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text('${e.value}  (${e.key})')),
              ],
              onChanged: (v) => v == null ? null : emit('internal', v),
            ),
          'external' => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SyncedTextField(
                  value: val,
                  hint: 'https://…  or  mailto:…  or  tel:…',
                  error: error,
                  onChanged: (v) => emit('external', v.trim()),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Switch(
                      value: j.flag('newTab'),
                      onChanged: (v) => emit('external', val, newTab: v),
                    ),
                    const SizedBox(width: 6),
                    const Text('Open in a new tab', style: SC.small),
                  ],
                ),
              ],
            ),
          'anchor' => anchors.isEmpty
              ? SyncedTextField(
                  value: val,
                  hint: 'anchor id, e.g. pricing',
                  error: error,
                  onChanged: (v) => emit('anchor', v.trim()),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(anchors.contains(val) ? val : null),
                  initialValue: anchors.contains(val) ? val : null,
                  isExpanded: true,
                  decoration: SC.input(hint: 'Choose a section', error: error),
                  style: SC.body,
                  items: [for (final a in anchors) DropdownMenuItem(value: a, child: Text('#$a'))],
                  onChanged: (v) => v == null ? null : emit('anchor', v),
                ),
          'action' => DropdownButtonFormField<String>(
              key: ValueKey(_actionLabels.containsKey(val) ? val : null),
              initialValue: _actionLabels.containsKey(val) ? val : null,
              isExpanded: true,
              decoration: SC.input(hint: 'Choose an action', error: error),
              style: SC.body,
              items: [
                for (final e in _actionLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => v == null ? null : emit('action', v),
            ),
          _ => const SizedBox.shrink(),
        },
        if (type != 'none' && target.isNone && error == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Not a valid destination yet. The button will do nothing.', style: SC.small),
          ),
      ],
    );
  }
}
