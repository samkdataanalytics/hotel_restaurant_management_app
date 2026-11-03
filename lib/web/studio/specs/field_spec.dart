import 'package:flutter/widgets.dart';

enum FieldKind {
  text,
  textarea,
  number,
  toggle,
  choice,
  icon,
  link,
  color,
  image,
  stringList,
  numberList,
  group,
  list,

  /// One cell per comparison column: a tick, a dash or text.
  cells,

  /// A size that can differ per device: `{desktop, tablet, mobile}`.
  responsiveNumber,

  /// A heading between fields; holds no value.
  divider,
}

/// Describes one editable value in a section's JSON. The property panel is
/// generated from these, so adding a section type never means writing a form.
@immutable
class FieldSpec {
  const FieldSpec._(
    this.kind,
    this.key,
    this.label, {
    this.help,
    this.required = false,
    this.maxLength,
    this.placeholder,
    this.min,
    this.max,
    this.step,
    this.unit,
    this.options = const {},
    this.fields = const [],
    this.itemTitleKey,
    this.itemLabel,
    this.addLabel,
    this.maxItems,
    this.minItems = 0,
    this.optional = false,
    this.verify,
    this.protectedTokens = false,
    this.template,
    this.defaultValue,
  });

  final FieldKind kind;

  /// Key in the parent object (the section's `content`, or a group's object).
  final String key;
  final String label;

  /// Shown as a tooltip next to the label: what the field does, where it appears.
  final String? help;
  final bool required;
  final int? maxLength;
  final String? placeholder;
  final double? min;
  final double? max;
  final double? step;
  final String? unit;

  /// value → label, for [FieldKind.choice].
  final Map<String, String> options;

  /// Children of a [FieldKind.group], or of each item of a [FieldKind.list].
  final List<FieldSpec> fields;

  /// Which child field names a list item in the collapsed row ("title").
  final String? itemTitleKey;

  /// Singular noun for list rows ("question", "step").
  final String? itemLabel;
  final String? addLabel;
  final int? maxItems;
  final int minItems;

  /// A group the page can do without (the hero's product window): shown with a
  /// switch, and switched off by deleting the key.
  final bool optional;

  /// Why this text is a claim the owner has not confirmed. Shown as an amber chip
  /// and listed in the publish dialog.
  final String? verify;

  /// The field is copy that may mention the trial length or discount; typing the
  /// number literally gets a warning pointing at the placeholder.
  final bool protectedTokens;

  /// For [FieldKind.list]: the JSON a new item starts as.
  final Map<String, Object?>? template;

  /// For a toggle or choice with a non-null default when the key is absent.
  final Object? defaultValue;

  // ── Constructors ──

  const FieldSpec.text(String key, String label,
      {String? help,
      bool required = false,
      int maxLength = 200,
      String? placeholder,
      String? verify,
      bool protectedTokens = false})
      : this._(FieldKind.text, key, label,
            help: help,
            required: required,
            maxLength: maxLength,
            placeholder: placeholder,
            verify: verify,
            protectedTokens: protectedTokens);

  const FieldSpec.textarea(String key, String label,
      {String? help,
      bool required = false,
      int maxLength = 4000,
      String? placeholder,
      String? verify,
      bool protectedTokens = false})
      : this._(FieldKind.textarea, key, label,
            help: help,
            required: required,
            maxLength: maxLength,
            placeholder: placeholder,
            verify: verify,
            protectedTokens: protectedTokens);

  const FieldSpec.number(String key, String label,
      {String? help, double min = 0, double max = 1000000, double step = 1, String? unit, String? verify})
      : this._(FieldKind.number, key, label,
            help: help, min: min, max: max, step: step, unit: unit, verify: verify);

  const FieldSpec.toggle(String key, String label, {String? help, bool defaultValue = false})
      : this._(FieldKind.toggle, key, label, help: help, defaultValue: defaultValue);

  const FieldSpec.choice(String key, String label, Map<String, String> options,
      {String? help, String? defaultValue})
      : this._(FieldKind.choice, key, label, help: help, options: options, defaultValue: defaultValue);

  const FieldSpec.icon(String key, String label, {String? help})
      : this._(FieldKind.icon, key, label, help: help);

  const FieldSpec.link(String key, String label, {String? help})
      : this._(FieldKind.link, key, label, help: help);

  const FieldSpec.color(String key, String label, {String? help})
      : this._(FieldKind.color, key, label, help: help);

  const FieldSpec.image(String key, String label, {String? help})
      : this._(FieldKind.image, key, label, help: help);

  const FieldSpec.stringList(String key, String label,
      {String? help,
      String itemLabel = 'item',
      int maxItems = 40,
      int maxLength = 300,
      String? verify,
      bool protectedTokens = false})
      : this._(FieldKind.stringList, key, label,
            help: help,
            itemLabel: itemLabel,
            maxItems: maxItems,
            maxLength: maxLength,
            verify: verify,
            protectedTokens: protectedTokens);

  const FieldSpec.numberList(String key, String label,
      {String? help, double min = 0, double max = 1, double step = 0.05, int maxItems = 24})
      : this._(FieldKind.numberList, key, label,
            help: help, min: min, max: max, step: step, maxItems: maxItems);

  const FieldSpec.group(String key, String label, List<FieldSpec> fields,
      {String? help, bool optional = false})
      : this._(FieldKind.group, key, label, help: help, fields: fields, optional: optional);

  const FieldSpec.list(
    String key,
    String label,
    List<FieldSpec> fields, {
    String? help,
    required String itemTitleKey,
    String itemLabel = 'item',
    String? addLabel,
    int maxItems = 40,
    int minItems = 0,
    Map<String, Object?> template = const {},
    String? verify,
  }) : this._(FieldKind.list, key, label,
            help: help,
            fields: fields,
            itemTitleKey: itemTitleKey,
            itemLabel: itemLabel,
            addLabel: addLabel,
            maxItems: maxItems,
            minItems: minItems,
            template: template,
            verify: verify);

  const FieldSpec.divider(String label) : this._(FieldKind.divider, '', label);

  const FieldSpec.cells(String key, String label, {String? help})
      : this._(FieldKind.cells, key, label, help: help);

  const FieldSpec.responsive(String key, String label,
      {String? help, double min = 0, double max = 400, double step = 1, String unit = 'px'})
      : this._(FieldKind.responsiveNumber, key, label,
            help: help, min: min, max: max, step: step, unit: unit);
}
