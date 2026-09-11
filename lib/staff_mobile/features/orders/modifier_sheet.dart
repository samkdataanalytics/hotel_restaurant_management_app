import 'package:flutter/material.dart';

import '../../../domain/entities/menu_item.dart';

/// What the waiter chose for one item before it goes in the cart.
class ModifierSelection {
  final Map<String, List<String>> modifiers;
  final String notes;
  final int quantity;

  const ModifierSelection({
    this.modifiers = const {},
    this.notes = '',
    this.quantity = 1,
  });
}

/// Bottom sheet for choosing modifiers, a kitchen note and a quantity.
///
/// Shown only when an item actually has modifiers or the waiter long-presses
/// for a note — a tap on a plain item goes straight into the cart, because
/// making someone confirm a Coke is how a POS becomes slower than paper.
Future<ModifierSelection?> showModifierSheet(
  BuildContext context, {
  required MenuItem item,
}) {
  return showModalBottomSheet<ModifierSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ModifierSheet(item: item),
  );
}

class _ModifierSheet extends StatefulWidget {
  final MenuItem item;
  const _ModifierSheet({required this.item});

  @override
  State<_ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<_ModifierSheet> {
  final _selected = <String, List<String>>{};
  final _notes = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Pre-select the first option of each required single-choice group, so the
    // common case is one tap on "Add" rather than a hunt for what is missing.
    for (final mod in widget.item.modifiers) {
      if (mod.isRequired && !mod.allowMultiple && mod.options.isNotEmpty) {
        _selected[mod.name] = [mod.options.first.name];
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Required groups must have at least one option chosen.
  List<String> get _missingRequired => widget.item.modifiers
      .where((m) => m.isRequired && (_selected[m.name] ?? []).isEmpty)
      .map((m) => m.name)
      .toList();

  /// Mirrors OrderItem.unitPrice so the sheet shows the price the order will
  /// actually carry, including the extra-unit rule for multi-select groups.
  double get _unitPrice {
    var extraUnits = 0;
    var adjustments = 0.0;
    for (final mod in widget.item.modifiers) {
      final chosen = _selected[mod.name] ?? [];
      if (chosen.length > 1) extraUnits += chosen.length - 1;
      for (final name in chosen) {
        final opt = mod.options.firstWhere(
          (o) => o.name == name,
          orElse: () => MenuModifierOption(name: name),
        );
        adjustments += opt.priceAdjustment;
      }
    }
    return widget.item.price * (1 + extraUnits) + adjustments;
  }

  void _toggle(MenuModifier mod, String optionName) {
    setState(() {
      final chosen = [...?_selected[mod.name]];
      if (mod.allowMultiple) {
        chosen.contains(optionName)
            ? chosen.remove(optionName)
            : chosen.add(optionName);
      } else {
        // Single-choice: tapping the chosen option clears it, unless the group
        // is required — there it stays, since empty would be invalid anyway.
        if (chosen.contains(optionName)) {
          if (mod.isRequired) return;
          chosen.clear();
        } else {
          chosen
            ..clear()
            ..add(optionName);
        }
      }
      _selected[mod.name] = chosen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = _missingRequired;

    return Padding(
      // Lift above the keyboard when the note field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  for (final mod in widget.item.modifiers) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            mod.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mod.isRequired
                                ? 'Required'
                                : mod.allowMultiple
                                    ? 'Choose any'
                                    : 'Optional',
                            style: TextStyle(
                              fontSize: 12,
                              color: mod.isRequired &&
                                      (_selected[mod.name] ?? []).isEmpty
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in mod.options)
                          FilterChip(
                            selected:
                                (_selected[mod.name] ?? []).contains(opt.name),
                            onSelected: (_) => _toggle(mod, opt.name),
                            label: Text(
                              opt.priceAdjustment == 0
                                  ? opt.name
                                  : '${opt.name}  '
                                      '${opt.priceAdjustment > 0 ? '+' : '−'}'
                                      '${opt.priceAdjustment.abs().toStringAsFixed(2)}',
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note for the kitchen',
                      hintText: 'e.g. no onions, allergy — nuts',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    _QtyStepper(
                      quantity: _quantity,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: missing.isEmpty
                            ? () => Navigator.of(context).pop(
                                  ModifierSelection(
                                    modifiers: Map.of(_selected)
                                      ..removeWhere((_, v) => v.isEmpty),
                                    notes: _notes.text.trim(),
                                    quantity: _quantity,
                                  ),
                                )
                            : null,
                        child: Text(
                          missing.isEmpty
                              ? 'Add  ·  ${(_unitPrice * _quantity).toStringAsFixed(2)}'
                              : 'Choose ${missing.first}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantity stepper sized for a thumb.
class _QtyStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'One fewer',
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'One more',
          ),
        ],
      ),
    );
  }
}
