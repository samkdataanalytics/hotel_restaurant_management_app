import 'package:flutter/material.dart';

import '../field_env.dart';
import '../json_path.dart';
import '../specs/field_spec.dart';
import '../studio_theme.dart';
import 'pickers.dart';
import 'synced_field.dart';

/// The property panel's body: one editor per [FieldSpec], reading from and writing
/// to a JSON object at [basePath].
class FieldForm extends StatelessWidget {
  const FieldForm({
    super.key,
    required this.fields,
    required this.values,
    required this.basePath,
    required this.env,
  });

  final List<FieldSpec> fields;
  final Map<String, dynamic> values;
  final JsonPath basePath;
  final FieldEnv env;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          FieldTile(spec: fields[i], values: values, basePath: basePath, env: env),
        ],
      ],
    );
  }
}

String _s(Object? v) => v is String ? v : '';

/// The part of an issue message after "Section — Field: ", for showing under the
/// field it belongs to.
String? _inline(FieldEnv env, JsonPath path) {
  final hits = env.issuesAt(path).where((i) => i.isError).toList();
  if (hits.isEmpty) return null;
  final m = hits.first.message;
  final i = m.indexOf(': ');
  return i < 0 ? m : m.substring(i + 2);
}

bool _holds(Object? v) => switch (v) {
      null => false,
      String s => s.trim().isNotEmpty,
      List l => l.isNotEmpty,
      Map m => m.isNotEmpty,
      _ => true,
    };

class FieldTile extends StatelessWidget {
  const FieldTile({super.key, required this.spec, required this.values, required this.basePath, required this.env});

  final FieldSpec spec;
  final Map<String, dynamic> values;
  final JsonPath basePath;
  final FieldEnv env;

  JsonPath get _path => [...basePath, spec.key];
  Object? get _value => values[spec.key];

  void _set(Object? v) => env.edit(_path, v);

  @override
  Widget build(BuildContext context) {
    return switch (spec.kind) {
      FieldKind.group => _GroupEditor(spec: spec, values: values, basePath: basePath, env: env),
      FieldKind.list => _ListEditor(spec: spec, values: values, basePath: basePath, env: env),
      FieldKind.toggle => _toggle(),
      FieldKind.divider => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(spec.label.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: SC.faint)),
        ),
      _ => _labelled(context, _control(context)),
    };
  }

  Widget _labelled(BuildContext context, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabelRow(spec: spec, holds: _holds(_value)),
          const SizedBox(height: 6),
          child,
        ],
      );

  Widget _toggle() {
    final on = _value is bool ? _value as bool : (spec.defaultValue as bool? ?? false);
    return Row(
      children: [
        Expanded(child: _LabelRow(spec: spec, holds: false)),
        Switch(
          value: on,
          // Stored only when it differs from the default: an untouched section
          // carries no flag, like every section that predates the editor.
          onChanged: (v) => _set(v == (spec.defaultValue as bool? ?? false) ? null : v),
        ),
      ],
    );
  }

  Widget _control(BuildContext context) {
    final err = _inline(env, _path);
    switch (spec.kind) {
      case FieldKind.text:
        return SyncedTextField(
          value: _s(_value),
          hint: spec.placeholder,
          maxLength: spec.maxLength,
          error: err,
          onChanged: (v) => _set(v.isEmpty ? null : v),
        );
      case FieldKind.textarea:
        return SyncedTextField(
          value: _s(_value),
          hint: spec.placeholder,
          maxLength: spec.maxLength,
          minLines: 3,
          maxLines: 9,
          error: err,
          onChanged: (v) => _set(v.isEmpty ? null : v),
        );
      case FieldKind.number:
        return _NumberField(spec: spec, value: _value, error: err, onChanged: _set);
      case FieldKind.choice:
        return _ChoiceEditor(spec: spec, value: _s(_value), onChanged: _set, error: err);
      case FieldKind.icon:
        return Align(
          alignment: Alignment.centerLeft,
          child: IconPickerField(value: _s(_value), onChanged: _set),
        );
      case FieldKind.link:
        return LinkField(value: _value, anchors: env.anchors, error: err, onChanged: _set);
      case FieldKind.color:
        return ColorField(value: _s(_value), error: err, onChanged: _set);
      case FieldKind.image:
        return _ImageEditor(value: _value, env: env, onChanged: _set);
      case FieldKind.stringList:
        return _StringListEditor(spec: spec, value: _value, onChanged: _set, error: err);
      case FieldKind.numberList:
        return _NumberListEditor(spec: spec, value: _value, onChanged: _set, error: err);
      case FieldKind.cells:
        return _CellsEditor(spec: spec, value: _value, env: env, onChanged: _set);
      case FieldKind.responsiveNumber:
        return _ResponsiveEditor(spec: spec, value: _value, onChanged: _set, error: err);
      case FieldKind.toggle:
      case FieldKind.group:
      case FieldKind.list:
      case FieldKind.divider:
        return const SizedBox.shrink();
    }
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.spec, required this.holds});

  final FieldSpec spec;
  final bool holds;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(spec.label, style: SC.label)),
        if (spec.required) const Text(' *', style: TextStyle(color: SC.danger, fontWeight: FontWeight.w800)),
        if (spec.help != null) ...[
          const SizedBox(width: 5),
          Tooltip(
            message: spec.help!,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            child: const Icon(Icons.info_outline_rounded, size: 14, color: SC.faint),
          ),
        ],
        if (spec.verify != null && holds) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: spec.verify!,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 8),
            child: const Chip2('Unverified claim', color: SC.warn, icon: Icons.flag_rounded),
          ),
        ],
      ],
    );
  }
}

// ── Number ──────────────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  const _NumberField({required this.spec, required this.value, required this.error, required this.onChanged});

  final FieldSpec spec;
  final Object? value;
  final String? error;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value is num ? _fmt(value as num) : '';
    return SyncedTextField(
      value: text,
      suffix: spec.unit,
      error: error,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (v) {
        final t = v.trim();
        if (t.isEmpty) return onChanged(null);
        final n = num.tryParse(t);
        // Half-typed input ("-", "1.") is left alone until it parses.
        if (n != null) onChanged(n == n.roundToDouble() ? n.round() : n);
      },
    );
  }

  static String _fmt(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();
}

// ── Choice ──────────────────────────────────────────────────────────────────

class _ChoiceEditor extends StatelessWidget {
  const _ChoiceEditor({required this.spec, required this.value, required this.onChanged, this.error});

  final FieldSpec spec;
  final String value;
  final ValueChanged<Object?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final def = spec.defaultValue as String?;
    final current = value.isEmpty ? def : value;
    final entries = spec.options.entries.toList();

    // Short lists read best as chips; long ones (fonts) as a menu.
    if (entries.length <= 3) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in entries)
            ChoiceChip(
              label: Text(e.value, style: TextStyle(fontSize: 12.5, color: current == e.key ? SC.accent : SC.text)),
              selected: current == e.key,
              selectedColor: SC.accentBg,
              backgroundColor: Colors.white,
              side: BorderSide(color: current == e.key ? SC.accent : SC.border),
              showCheckmark: false,
              // The default is stored as "no value", so a reset really resets.
              onSelected: (_) => onChanged(e.key == def ? null : e.key),
            ),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(spec.options.containsKey(current) ? current : null),
      initialValue: spec.options.containsKey(current) ? current : null,
      isExpanded: true,
      style: SC.body,
      decoration: SC.input(hint: def == null ? 'Site default' : null, error: error),
      items: [for (final e in entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => onChanged(v == def ? null : v),
    );
  }
}

// ── Responsive number ────────────────────────────────────────────────────────

class _ResponsiveEditor extends StatelessWidget {
  const _ResponsiveEditor({required this.spec, required this.value, required this.onChanged, this.error});

  final FieldSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final m = value is Map ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};

    void setDevice(String d, String text) {
      final t = text.trim();
      final next = Map<String, dynamic>.from(m);
      final n = num.tryParse(t);
      if (t.isEmpty) {
        next.remove(d);
      } else if (n != null) {
        next[d] = n == n.roundToDouble() ? n.round() : n;
      } else {
        return;
      }
      onChanged(next.isEmpty ? null : next);
    }

    String show(String d) => m[d] is num ? '${m[d] is double && (m[d] as double) != (m[d] as double).roundToDouble() ? m[d] : (m[d] as num).round()}' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final d in const ['desktop', 'tablet', 'mobile']) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          switch (d) {
                            'desktop' => Icons.desktop_windows_outlined,
                            'tablet' => Icons.tablet_mac_outlined,
                            _ => Icons.phone_iphone_rounded,
                          },
                          size: 13,
                          color: SC.faint,
                        ),
                        const SizedBox(width: 4),
                        Text(d, style: SC.small),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SyncedTextField(
                      value: show(d),
                      hint: d == 'desktop' ? 'default' : 'inherit',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setDevice(d, v),
                    ),
                  ],
                ),
              ),
              if (d != 'mobile') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                error ?? 'Tablet and mobile use the value above them when left empty (${spec.unit ?? ''}).',
                style: SC.small.copyWith(color: error != null ? SC.danger : SC.faint),
              ),
            ),
            if (m.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(null),
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Image ───────────────────────────────────────────────────────────────────

class _ImageEditor extends StatelessWidget {
  const _ImageEditor({required this.value, required this.env, required this.onChanged});

  final Object? value;
  final FieldEnv env;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final m = value is Map ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};
    final url = _s(m['url']);
    final alt = _s(m['alt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SC.border),
              ),
              child: url.isEmpty
                  ? const Icon(Icons.image_outlined, color: SC.faint)
                  : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: SC.faint)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: env.pickImage == null
                        ? null
                        : () async {
                            final item = await env.pickImage!(context);
                            if (item == null) return;
                            onChanged({'url': item.url, 'alt': alt.isEmpty ? item.alt : alt});
                          },
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(url.isEmpty ? 'Choose image' : 'Change'),
                  ),
                  if (url.isNotEmpty)
                    TextButton(
                      onPressed: () => onChanged(null),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Alt text', style: SC.label),
          const SizedBox(height: 6),
          SyncedTextField(
            value: alt,
            hint: 'Describe the picture for screen readers',
            maxLength: 160,
            onChanged: (v) => onChanged({...m, 'alt': v}),
          ),
        ],
      ],
    );
  }
}

// ── String list ─────────────────────────────────────────────────────────────

class _StringListEditor extends StatelessWidget {
  const _StringListEditor({required this.spec, required this.value, required this.onChanged, this.error});

  final FieldSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final items = value is List ? [for (final e in value as List) _s(e)] : <String>[];
    final max = spec.maxItems ?? 40;
    final noun = spec.itemLabel ?? 'item';

    void emit(List<String> l) => onChanged(l.isEmpty ? null : l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: SyncedTextField(
                    value: items[i],
                    maxLength: spec.maxLength,
                    onChanged: (v) => emit([...items]..[i] = v),
                  ),
                ),
                _IconBtn(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: 'Move up',
                  onTap: i == 0 ? null : () => emit([...items]..insert(i - 1, items.removeAt(i))),
                ),
                _IconBtn(
                  icon: Icons.arrow_downward_rounded,
                  tooltip: 'Move down',
                  onTap: i == items.length - 1 ? null : () => emit([...items]..insert(i + 1, items.removeAt(i))),
                ),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remove',
                  color: SC.danger,
                  onTap: () => emit([...items]..removeAt(i)),
                ),
              ],
            ),
          ),
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(error!, style: SC.small.copyWith(color: SC.danger))),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: items.length >= max ? null : () => emit([...items, '']),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add $noun'),
          ),
        ),
      ],
    );
  }
}

class _NumberListEditor extends StatelessWidget {
  const _NumberListEditor({required this.spec, required this.value, required this.onChanged, this.error});

  final FieldSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final items = value is List ? [for (final e in value as List) if (e is num) e] : <num>[];
    final max = spec.maxItems ?? 24;

    void emit(List<num> l) => onChanged(l.isEmpty ? null : l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: 62,
                child: SyncedTextField(
                  value: items[i] == items[i].roundToDouble() ? '${items[i].round()}' : '${items[i]}',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final n = num.tryParse(v.trim());
                    if (n != null) emit([...items]..[i] = n);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: items.length >= max ? null : () => emit([...items, spec.max ?? 1]),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
            ),
            TextButton.icon(
              onPressed: items.isEmpty ? null : () => emit([...items]..removeLast()),
              icon: const Icon(Icons.remove_rounded, size: 16),
              label: const Text('Remove last'),
            ),
          ],
        ),
        if (error != null) Text(error!, style: SC.small.copyWith(color: SC.danger)),
      ],
    );
  }
}

// ── Comparison cells ────────────────────────────────────────────────────────

class _CellsEditor extends StatelessWidget {
  const _CellsEditor({required this.spec, required this.value, required this.env, required this.onChanged});

  final FieldSpec spec;
  final Object? value;
  final FieldEnv env;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = env.columnCount;
    final raw = value is List ? value as List : const [];
    Object cell(int i) => i < raw.length && (raw[i] is bool || raw[i] is String) ? raw[i] as Object : '';

    void set(int i, Object v) {
      final next = [for (var k = 0; k < n; k++) k == i ? v : cell(k)];
      onChanged(next);
    }

    if (n == 0) {
      return const Text('Add a column first.', style: SC.small);
    }

    return Column(
      children: [
        for (var i = 0; i < n; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(i < env.columnNames.length && env.columnNames[i].isNotEmpty ? env.columnNames[i] : 'Column ${i + 1}',
                      style: SC.small, overflow: TextOverflow.ellipsis),
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: 'yes', icon: Icon(Icons.check_rounded, size: 15)),
                    ButtonSegment(value: 'no', icon: Icon(Icons.remove_rounded, size: 15)),
                    ButtonSegment(value: 'text', icon: Icon(Icons.text_fields_rounded, size: 15)),
                  ],
                  selected: {
                    switch (cell(i)) {
                      true => 'yes',
                      false => 'no',
                      _ => 'text',
                    }
                  },
                  onSelectionChanged: (s) => set(i, switch (s.first) {
                    'yes' => true,
                    'no' => false,
                    _ => cell(i) is String ? cell(i) : '',
                  }),
                ),
                const SizedBox(width: 8),
                if (cell(i) is String)
                  Expanded(
                    child: SyncedTextField(
                      value: cell(i) as String,
                      hint: 'Text',
                      maxLength: 60,
                      onChanged: (v) => set(i, v),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Group ───────────────────────────────────────────────────────────────────

class _GroupEditor extends StatelessWidget {
  const _GroupEditor({required this.spec, required this.values, required this.basePath, required this.env});

  final FieldSpec spec;
  final Map<String, dynamic> values;
  final JsonPath basePath;
  final FieldEnv env;

  @override
  Widget build(BuildContext context) {
    final path = [...basePath, spec.key];
    final raw = values[spec.key];
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final present = raw is Map;
    final hidden = spec.optional && !present;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _LabelRow(spec: spec, holds: map.isNotEmpty)),
              if (spec.optional)
                Switch(
                  value: present,
                  onChanged: (on) => env.edit(path, on ? <String, dynamic>{} : null),
                ),
            ],
          ),
          if (!hidden) ...[
            const SizedBox(height: 12),
            FieldForm(fields: spec.fields, values: map, basePath: path, env: env),
          ],
        ],
      ),
    );
  }
}

// ── List ────────────────────────────────────────────────────────────────────

class _ListEditor extends StatefulWidget {
  const _ListEditor({required this.spec, required this.values, required this.basePath, required this.env});

  final FieldSpec spec;
  final Map<String, dynamic> values;
  final JsonPath basePath;
  final FieldEnv env;

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  final _open = <int>{};

  FieldSpec get spec => widget.spec;
  JsonPath get _path => [...widget.basePath, spec.key];

  List<Map<String, dynamic>> get _items {
    final raw = widget.values[spec.key];
    return raw is List ? [for (final e in raw) e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}] : [];
  }

  void _emit(List<Map<String, dynamic>> l) => widget.env.edit(_path, l.isEmpty && spec.minItems == 0 ? null : l);

  Map<String, dynamic> _fresh() => deepCopy(spec.template ?? const {});

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final max = spec.maxItems ?? 40;
    final noun = spec.itemLabel ?? 'item';
    final err = _inline(widget.env, _path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelRow(spec: spec, holds: items.isNotEmpty),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          _ItemCard(
            index: i,
            title: _titleOf(items[i]),
            noun: noun,
            open: _open.contains(i),
            isFirst: i == 0,
            isLast: i == items.length - 1,
            onToggle: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
            onUp: () {
              setState(_open.clear);
              _emit([...items]..insert(i - 1, items.removeAt(i)));
            },
            onDown: () {
              setState(_open.clear);
              _emit([...items]..insert(i + 1, items.removeAt(i)));
            },
            onDuplicate: items.length >= max
                ? null
                : () {
                    setState(() {
                      _open
                        ..clear()
                        ..add(i + 1);
                    });
                    _emit([...items]..insert(i + 1, deepCopy(items[i])));
                  },
            onDelete: items.length <= spec.minItems
                ? null
                : () {
                    setState(_open.clear);
                    _emit([...items]..removeAt(i));
                  },
            child: FieldForm(
              fields: spec.fields,
              values: items[i],
              basePath: [..._path, i],
              env: widget.env,
            ),
          ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(err, style: SC.small.copyWith(color: SC.danger)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: items.length >= max
                ? null
                : () {
                    setState(() => _open
                      ..clear()
                      ..add(items.length));
                    _emit([...items, _fresh()]);
                  },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(spec.addLabel ?? 'Add $noun'),
          ),
        ),
      ],
    );
  }

  String _titleOf(Map<String, dynamic> item) {
    final v = item[spec.itemTitleKey];
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? '(untitled)' : s;
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.index,
    required this.title,
    required this.noun,
    required this.open,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
    required this.onDuplicate,
    required this.onDelete,
    required this.child,
  });

  final int index;
  final String title;
  final String noun;
  final bool open;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: open ? SC.accent.withValues(alpha: 0.5) : SC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: SC.accentBg, borderRadius: BorderRadius.circular(6)),
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: SC.accent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SC.body.copyWith(fontWeight: FontWeight.w600))),
                  _IconBtn(icon: Icons.arrow_upward_rounded, tooltip: 'Move up', onTap: isFirst ? null : onUp),
                  _IconBtn(icon: Icons.arrow_downward_rounded, tooltip: 'Move down', onTap: isLast ? null : onDown),
                  _IconBtn(icon: Icons.copy_rounded, tooltip: 'Duplicate $noun', onTap: onDuplicate),
                  _IconBtn(icon: Icons.delete_outline_rounded, tooltip: 'Remove $noun', color: SC.danger, onTap: onDelete),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: SC.faint),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 17,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        color: color ?? SC.muted,
        disabledColor: SC.border,
        icon: Icon(icon),
      );
}
