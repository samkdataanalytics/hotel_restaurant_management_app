import 'package:flutter/widgets.dart';

import '../model/site_document.dart';

typedef SectionBuilder = Widget Function(BuildContext context, SectionNode node);

/// One kind of section the site knows how to draw.
class SectionDefinition {
  const SectionDefinition({
    required this.type,
    required this.label,
    required this.builder,
  });

  /// Stable identifier stored in documents (`"hero"`, `"faq"`).
  final String type;

  /// What the editor calls it ("Frequently asked questions").
  final String label;

  /// Builds the widget from a node. Must parse tolerantly — it runs on content
  /// an admin typed. A throw here is caught by the renderer and the section
  /// falls back to its bundled default.
  final SectionBuilder builder;
}

/// The set of section types in play. An unknown type in a document (written by
/// a newer version of the editor, say) is skipped by the renderer rather than
/// breaking the page.
class SectionRegistry {
  const SectionRegistry(this._defs);

  final Map<String, SectionDefinition> _defs;

  SectionDefinition? operator [](String type) => _defs[type];

  bool has(String type) => _defs.containsKey(type);

  Iterable<SectionDefinition> get all => _defs.values;

  /// Builds a registry from a list, rejecting duplicate types — two definitions
  /// claiming `"faq"` would make which one wins an accident of list order.
  factory SectionRegistry.of(List<SectionDefinition> defs) {
    final map = <String, SectionDefinition>{};
    for (final d in defs) {
      if (map.containsKey(d.type)) {
        throw StateError('Duplicate section type "${d.type}"');
      }
      map[d.type] = d;
    }
    return SectionRegistry(map);
  }
}
