import 'dart:convert';
import 'dart:ui' show Color;

import '../cms/model/color_ref.dart';
import '../cms/model/json_reader.dart';
import '../cms/model/link_target.dart';
import '../cms/registry/icon_registry.dart';
import '../cms/sections/image_text_section.dart' show isLibraryImageUrl;
import 'specs/field_spec.dart';
import 'specs/section_specs.dart';
import 'studio_state.dart';

/// Placeholders the site understands in copy. Anything else in braces is a typo
/// that would otherwise show up literally on the page.
const kKnownTokens = {'trialDays', 'annualDiscountPct', 'starterPrice', 'year', 'supportEmail'};

/// JSON size above which the database would refuse the save (it caps at 256 KB).
const kMaxDocumentBytes = 200 * 1024;

final _tokenPattern = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');
final _literalTrial = RegExp(r'\b45[\s-]?days?\b', caseSensitive: false);
final _literalDiscount = RegExp(r'\b20\s?%');

/// Scripts the bundled fonts do not cover. The engine would fetch a fallback font
/// from fonts.gstatic.com at runtime, which the site does not otherwise do.
final _uncoveredScripts = RegExp(r'[඀-෿஀-௿]'); // Sinhala, Tamil
final _missingGlyphs = RegExp(r'[★●₨≤≥→✓✔]');

/// A claim the owner has not confirmed, found in the current content.
class UnverifiedClaim {
  const UnverifiedClaim({required this.sectionId, required this.sectionLabel, required this.field, required this.message});

  final String sectionId;
  final String sectionLabel;
  final String field;
  final String message;
}

/// Checks a page document. Errors block publishing; warnings are shown but do not.
///
/// This is the strict write path. The public renderer is tolerant of anything, so
/// none of this is a safety net for visitors — it exists so the admin finds out
/// *here*, with a clear message, instead of by seeing a section quietly
/// degrade to its default on the live site.
List<ValidationIssue> validateSiteDocument(String key, Map<String, dynamic> doc) {
  final out = <ValidationIssue>[];

  if (utf8.encode(jsonEncode(doc)).length > kMaxDocumentBytes) {
    out.add(const ValidationIssue(
      severity: IssueSeverity.error,
      message: 'This page is too large to save. Remove some content or split it up.',
    ));
  }

  if (!key.startsWith('page:')) return out;

  final sections = doc['sections'];
  if (sections is! List) {
    out.add(const ValidationIssue(severity: IssueSeverity.error, message: 'The page has no section list.'));
    return out;
  }
  if (sections.isEmpty) {
    out.add(const ValidationIssue(
      severity: IssueSeverity.warning,
      message: 'This page has no sections, so it will show nothing.',
    ));
  }
  if (sections.length > 80) {
    out.add(const ValidationIssue(severity: IssueSeverity.error, message: 'A page can have at most 80 sections.'));
  }

  final ids = <String>{};
  final anchors = <String>{};
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    if (s is! Map) {
      out.add(ValidationIssue(severity: IssueSeverity.error, message: 'Section ${i + 1} is not valid.'));
      continue;
    }
    final node = J.of(s);
    final id = node.str('id');
    final type = node.str('type');
    final spec = kSectionSpecByType[type];
    final label = spec?.label ?? type;

    if (id.isEmpty) {
      out.add(ValidationIssue(severity: IssueSeverity.error, message: 'Section ${i + 1} has no id.'));
    } else if (!ids.add(id)) {
      out.add(ValidationIssue(
          severity: IssueSeverity.error, message: 'Two sections share the id "$id".', sectionId: id));
    }
    if (spec == null) {
      out.add(ValidationIssue(
        severity: IssueSeverity.warning,
        message: 'Section "$id" has an unknown type "$type" and will not be shown.',
        sectionId: id,
      ));
      continue;
    }

    final anchor = node.strOrNull('anchor');
    if (anchor != null) {
      if (!LinkTarget.isValidAnchor(anchor)) {
        out.add(ValidationIssue(
          severity: IssueSeverity.error,
          message: '$label: the anchor "$anchor" must be lowercase letters, numbers and dashes.',
          sectionId: id,
          path: ['sections', i, 'anchor'],
        ));
      } else if (!anchors.add(anchor)) {
        out.add(ValidationIssue(
          severity: IssueSeverity.error,
          message: '$label: the anchor "$anchor" is used by another section.',
          sectionId: id,
          path: ['sections', i, 'anchor'],
        ));
      }
    }

    _fields(out, spec.fields, node.obj('content'), ['sections', i, 'content'], id, label);
    _fields(out, kLayoutFields, node.obj('layout'), ['sections', i, 'layout'], id, label);
    _fields(out, kStyleFields, node.obj('style'), ['sections', i, 'style'], id, label);
    _fields(out, kTypographyFields, node.obj('typography'), ['sections', i, 'typography'], id, label);
    _contrast(out, node, i, id, label);
  }

  return out;
}

/// Validates page-level settings (SEO, typography, layout) and the global theme.
List<ValidationIssue> validateSettings(
  List<FieldSpec> fields,
  Map<String, dynamic> values, {
  List<Object> basePath = const [],
}) {
  final out = <ValidationIssue>[];
  _fields(out, fields, J.of(values), basePath, null, 'Settings');
  return out;
}

void _fields(
  List<ValidationIssue> out,
  List<FieldSpec> fields,
  J values,
  List<Object> base,
  String? sectionId,
  String label,
) {
  for (final f in fields) {
    final path = [...base, f.key];
    void add(IssueSeverity sev, String msg) => out.add(ValidationIssue(
          severity: sev,
          message: '$label — ${f.label}: $msg',
          sectionId: sectionId,
          path: path,
        ));

    final v = values.raw[f.key];

    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.textarea:
        final s = v is String ? v : '';
        if (v != null && v is! String) add(IssueSeverity.error, 'must be text.');
        if (f.required && s.trim().isEmpty) add(IssueSeverity.error, 'is required.');
        if (f.maxLength != null && s.length > f.maxLength!) {
          add(IssueSeverity.error, 'is ${s.length} characters; the limit is ${f.maxLength}.');
        }
        _text(s, f, add);

      case FieldKind.stringList:
        if (v == null) break;
        if (v is! List) {
          add(IssueSeverity.error, 'must be a list.');
          break;
        }
        if (f.maxItems != null && v.length > f.maxItems!) {
          add(IssueSeverity.error, 'has ${v.length} items; the limit is ${f.maxItems}.');
        }
        for (final item in v) {
          if (item is! String) {
            add(IssueSeverity.error, 'contains something that is not text.');
            continue;
          }
          if (f.maxLength != null && item.length > f.maxLength!) {
            add(IssueSeverity.error, '"${_clip(item)}" is over ${f.maxLength} characters.');
          }
          _text(item, f, add);
        }

      case FieldKind.number:
        if (v == null) break;
        if (v is! num || !v.isFinite) {
          add(IssueSeverity.error, 'must be a number.');
        } else if ((f.min != null && v < f.min!) || (f.max != null && v > f.max!)) {
          add(IssueSeverity.error, 'must be between ${_n(f.min)} and ${_n(f.max)}.');
        }

      case FieldKind.numberList:
        if (v == null) break;
        if (v is! List) {
          add(IssueSeverity.error, 'must be a list of numbers.');
          break;
        }
        for (final n in v) {
          if (n is! num || !n.isFinite || (f.min != null && n < f.min!) || (f.max != null && n > f.max!)) {
            add(IssueSeverity.error, 'values must be between ${_n(f.min)} and ${_n(f.max)}.');
            break;
          }
        }

      case FieldKind.responsiveNumber:
        if (v == null) break;
        if (v is! Map) {
          add(IssueSeverity.error, 'must be a size per device.');
          break;
        }
        for (final d in const ['desktop', 'tablet', 'mobile']) {
          final n = v[d];
          if (n == null) continue;
          if (n is! num || !n.isFinite || (f.min != null && n < f.min!) || (f.max != null && n > f.max!)) {
            add(IssueSeverity.error, '$d must be between ${_n(f.min)} and ${_n(f.max)}.');
          }
        }

      case FieldKind.color:
        final s = v is String ? v.trim() : '';
        if (s.isNotEmpty && parseHexColor(s) == null) {
          add(IssueSeverity.error, '"$s" is not a colour. Use a hex value like #0A7D77.');
        }

      case FieldKind.icon:
        final s = v is String ? v : '';
        if (s.isNotEmpty && !IconRegistry.isKnown(s)) {
          add(IssueSeverity.error, 'the icon "$s" does not exist.');
        }

      case FieldKind.choice:
        final s = v is String ? v : null;
        if (s != null && s.isNotEmpty && !f.options.containsKey(s)) {
          add(IssueSeverity.error, '"$s" is not one of the choices.');
        }

      case FieldKind.link:
        _link(out, v, f, path, sectionId, label);

      case FieldKind.image:
        final img = J.of(v);
        final url = img.str('url');
        if (url.isNotEmpty && !isLibraryImageUrl(url)) {
          add(IssueSeverity.error, 'must come from the media library.');
        } else if (url.isNotEmpty && img.str('alt').trim().isEmpty) {
          add(IssueSeverity.warning, 'has no alt text. Add a short description, or leave it '
              'if the picture is purely decorative.');
        }

      case FieldKind.group:
        final g = v is Map ? J.of(v) : const J({});
        _fields(out, f.fields, g, path, sectionId, label);
        _buttonHasLink(out, f, g, path, sectionId, label);

      case FieldKind.list:
        if (v == null) {
          if (f.minItems > 0) add(IssueSeverity.error, 'needs at least ${f.minItems}.');
          break;
        }
        if (v is! List) {
          add(IssueSeverity.error, 'must be a list.');
          break;
        }
        if (v.length < f.minItems) add(IssueSeverity.error, 'needs at least ${f.minItems}.');
        if (f.maxItems != null && v.length > f.maxItems!) {
          add(IssueSeverity.error, 'has ${v.length} items; the limit is ${f.maxItems}.');
        }
        for (var i = 0; i < v.length; i++) {
          if (v[i] is! Map) {
            add(IssueSeverity.error, 'item ${i + 1} is not valid.');
            continue;
          }
          _fields(out, f.fields, J.of(v[i]), [...path, i], sectionId, '$label — ${f.itemLabel ?? 'item'} ${i + 1}');
        }

      case FieldKind.cells:
      case FieldKind.toggle:
        break;
    }
  }
}

void _text(String s, FieldSpec f, void Function(IssueSeverity, String) add) {
  if (s.isEmpty) return;
  for (final m in _tokenPattern.allMatches(s)) {
    if (!kKnownTokens.contains(m[1])) {
      add(IssueSeverity.error, 'the placeholder {${m[1]}} is not recognised. '
          'Known: ${kKnownTokens.map((t) => '{$t}').join(', ')}.');
    }
  }
  if (f.protectedTokens) {
    if (_literalTrial.hasMatch(s)) {
      add(IssueSeverity.warning, 'mentions the trial length as a number. Use {trialDays} so it '
          'always matches what new accounts actually get.');
    }
    if (_literalDiscount.hasMatch(s)) {
      add(IssueSeverity.warning, 'mentions the annual discount as a number. Use '
          '{annualDiscountPct} so it matches the checkout.');
    }
  }
  if (_uncoveredScripts.hasMatch(s)) {
    add(IssueSeverity.warning, 'contains Sinhala or Tamil, which the site fonts do not include. '
        'The browser will fetch a fallback font, and the look is not controlled.');
  } else if (_missingGlyphs.hasMatch(s)) {
    add(IssueSeverity.warning, 'contains a symbol the site font lacks (★ ● ₨ ≤ → ✓). It may show '
        'as a box or in another font.');
  }
}

void _link(List<ValidationIssue> out, Object? v, FieldSpec f, List<Object> path, String? sectionId,
    String label) {
  if (v == null) return;
  void add(String msg) => out.add(ValidationIssue(
        severity: IssueSeverity.error,
        message: '$label — ${f.label}: $msg',
        sectionId: sectionId,
        path: path,
      ));
  if (v is! Map) {
    add('is not a valid link.');
    return;
  }
  final j = J.of(v);
  final type = j.str('type');
  if (type.isEmpty || type == 'none') return;
  if (!LinkTarget.fromJson(j).isNone) return;

  final value = j.str('value');
  add(switch (type) {
    'internal' => '"$value" is not a page on this site. Choose one from the list.',
    'external' => '"$value" is not allowed. Use an https:// address, mailto: or tel:.',
    'anchor' => '"$value" is not a valid anchor.',
    'action' => 'that action is not available.',
    _ => 'the link type "$type" is not recognised.',
  });
}

/// A button with text but nowhere to go is a dead end for the visitor.
void _buttonHasLink(List<ValidationIssue> out, FieldSpec group, J g, List<Object> path,
    String? sectionId, String label) {
  final hasLabelField = group.fields.any((x) => x.key == 'label');
  final hasLinkField = group.fields.any((x) => x.kind == FieldKind.link);
  if (!hasLabelField || !hasLinkField) return;
  final labelText = g.str('label').trim();
  final link = LinkTarget.fromJson(g.obj('link'));
  if (labelText.isNotEmpty && link.isNone) {
    out.add(ValidationIssue(
      severity: IssueSeverity.warning,
      message: '$label — ${group.label}: the button "$labelText" has no destination, so it will '
          'do nothing when clicked.',
      sectionId: sectionId,
      path: path,
    ));
  }
}

/// Large text needs 3:1 (WCAG AA). Only checked when both colours are the admin's:
/// the built-in pairings are already covered by the theme contrast test.
void _contrast(List<ValidationIssue> out, J node, int i, String id, String label) {
  final bg = parseHexColor(node.obj('style').strOrNull('background'));
  if (bg == null) return;
  final fg = parseHexColor(node.obj('typography').strOrNull('headingColor'));
  // With no heading colour set the heading is the default near-black ink.
  final heading = fg ?? const Color(0xFF0A1424); // LK.ink
  final ratio = contrastRatio(heading, bg);
  if (ratio < 3.0) {
    out.add(ValidationIssue(
      severity: IssueSeverity.warning,
      message: '$label: the heading is hard to read on this background '
          '(contrast ${ratio.toStringAsFixed(1)}:1, 3:1 is the minimum for large text).',
      sectionId: id,
      path: ['sections', i, 'style', 'background'],
    ));
  }
}

String _clip(String s) => s.length <= 30 ? s : '${s.substring(0, 30)}…';

String _n(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

/// Claims in the current content that the owner has not confirmed, for the
/// publish dialog. A field carries a `verify` note in its spec; it is listed here
/// whenever it holds something.
List<UnverifiedClaim> collectUnverifiedClaims(Map<String, dynamic> doc) {
  final out = <UnverifiedClaim>[];
  final sections = doc['sections'];
  if (sections is! List) return out;

  for (final s in sections) {
    if (s is! Map) continue;
    final node = J.of(s);
    if (!node.flag('enabled', true)) continue; // a hidden section makes no claims
    final spec = kSectionSpecByType[node.str('type')];
    if (spec == null) continue;
    _claims(out, spec.fields, node.obj('content'), node.str('id'), spec.label);
  }
  return out;
}

void _claims(List<UnverifiedClaim> out, List<FieldSpec> fields, J values, String id, String label) {
  for (final f in fields) {
    final v = values.raw[f.key];
    final holds = switch (v) {
      null => false,
      String s => s.trim().isNotEmpty,
      List l => l.isNotEmpty,
      Map m => m.isNotEmpty,
      _ => true,
    };
    if (f.verify != null && holds) {
      out.add(UnverifiedClaim(sectionId: id, sectionLabel: label, field: f.label, message: f.verify!));
    }
    if (f.kind == FieldKind.group && v is Map) {
      _claims(out, f.fields, J.of(v), id, label);
    }
  }
}
