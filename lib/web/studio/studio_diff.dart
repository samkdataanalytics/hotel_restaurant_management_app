import 'package:collection/collection.dart';

import '../cms/model/json_reader.dart';
import 'specs/section_specs.dart';

/// A readable summary of what publishing would change, for the publish dialog.
/// Compares by section id, so reordering and editing are told apart.
List<String> summarizeChanges(Map<String, dynamic> published, Map<String, dynamic> draft) {
  const eq = DeepCollectionEquality();
  if (eq.equals(published, draft)) return const [];

  final out = <String>[];

  List<Map<String, dynamic>> sectionsOf(Map<String, dynamic> d) => [
        for (final s in (d['sections'] is List ? d['sections'] as List : const []))
          if (s is Map) Map<String, dynamic>.from(s),
      ];

  String name(Map<String, dynamic> s) {
    final type = (s['type'] as String?) ?? '';
    final label = kSectionSpecByType[type]?.label ?? type;
    final title = J.of(s['content']).strOrNull('title') ?? J.of(s['content']).strOrNull('headline');
    return title == null ? label : '$label — "${title.length > 40 ? '${title.substring(0, 40)}…' : title}"';
  }

  final before = sectionsOf(published);
  final after = sectionsOf(draft);
  final beforeById = {for (final s in before) s['id']: s};
  final afterById = {for (final s in after) s['id']: s};

  for (final s in after) {
    if (!beforeById.containsKey(s['id'])) out.add('Added: ${name(s)}');
  }
  for (final s in before) {
    if (!afterById.containsKey(s['id'])) out.add('Removed: ${name(s)}');
  }

  final edited = <String>[];
  final hidden = <String>[];
  final shown = <String>[];
  for (final s in after) {
    final old = beforeById[s['id']];
    if (old == null) continue;
    final wasOn = old['enabled'] != false;
    final isOn = s['enabled'] != false;
    if (wasOn && !isOn) hidden.add(name(s));
    if (!wasOn && isOn) shown.add(name(s));

    final a = Map<String, dynamic>.from(old)..remove('enabled');
    final b = Map<String, dynamic>.from(s)..remove('enabled');
    if (!eq.equals(a, b)) edited.add(name(s));
  }
  for (final n in hidden) {
    out.add('Hidden: $n');
  }
  for (final n in shown) {
    out.add('Shown again: $n');
  }
  for (final n in edited) {
    out.add('Edited: $n');
  }

  final keptIds = [for (final s in after) if (beforeById.containsKey(s['id'])) s['id']];
  final oldOrder = [for (final s in before) if (afterById.containsKey(s['id'])) s['id']];
  if (!const ListEquality<Object?>().equals(keptIds, oldOrder)) out.add('Sections reordered');

  final restBefore = Map<String, dynamic>.from(published)..remove('sections');
  final restAfter = Map<String, dynamic>.from(draft)..remove('sections');
  if (!eq.equals(restBefore, restAfter)) out.add('Page settings changed (title, fonts or layout)');

  if (out.isEmpty) out.add('Content changed');
  return out;
}
