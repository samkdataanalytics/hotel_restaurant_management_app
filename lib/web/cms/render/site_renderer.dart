import 'package:flutter/widgets.dart';

import '../../brand_kit.dart';
import '../model/site_document.dart';
import '../model/site_theme.dart';
import '../registry/section_registry.dart';
import 'anchor_keys.dart';
import 'section_frame.dart';

/// Called around each built section, so the editor can add selection outlines
/// and tap handlers without the sections knowing it exists.
typedef SectionWrapper = Widget Function(BuildContext context, SectionNode node, Widget built);

/// Turns a [SiteDocument] into the ordered widgets of a page.
///
/// Rules that live here rather than in each section, so every page behaves the
/// same way: disabled sections and sections hidden on the current device are
/// left out entirely (no empty gap); the standard gap goes *before* a section
/// that asks for it, so hiding one never leaves two gaps stacked; and a section
/// whose builder throws is replaced by its bundled default instead of taking the
/// page down.
///
/// The cascade is resolved here too: the global [theme], then the document's own
/// typography and layout, then each section's.
class SiteRenderer {
  const SiteRenderer({
    required this.registry,
    this.fallback,
    this.anchors,
    this.theme = SiteTheme.none,
    this.wrap,
  });

  final SectionRegistry registry;

  /// The bundled default document, used per section when a node fails to build.
  final SiteDocument? fallback;

  final AnchorKeys? anchors;

  /// The global theme (`global:theme`). Page-level settings are layered on top.
  final SiteTheme theme;

  /// Editor hook; null on the public site.
  final SectionWrapper? wrap;

  Device deviceOf(BuildContext context) => LK.isMobile(context)
      ? Device.mobile
      : (LK.isTablet(context) ? Device.tablet : Device.desktop);

  List<Widget> build(BuildContext context, SiteDocument doc) {
    final device = deviceOf(context);
    final effective = theme.merge(SiteTheme.fromJson(doc.typography, doc.layout));
    final gap = effective.sectionGap?.resolve(device) ?? LK.sectionGap(context);
    final out = <Widget>[];

    for (final node in doc.sections) {
      if (!node.enabled || !node.visibility.visibleOn(device)) continue;
      var built = _buildNode(context, node, effective);
      if (built == null) continue;
      if (wrap != null) built = wrap!(context, node, built);

      if (node.spaceBefore) out.add(SizedBox(height: gap));
      out.add(built);
    }
    return out;
  }

  Widget? _buildNode(BuildContext context, SectionNode node, SiteTheme effective) {
    final def = registry[node.type];
    if (def == null) return null; // unknown type: skip, don't break the page

    Widget? body;
    try {
      body = def.builder(context, node);
    } catch (_) {
      final fb = fallback?.byId(node.id);
      if (fb != null && fb.type == node.type) {
        try {
          body = def.builder(context, fb);
        } catch (_) {
          body = null;
        }
      }
    }
    if (body == null) return null;

    body = SectionFrame.wrap(
      context,
      node,
      body,
      inheritedType: effective.type,
      inheritedLayout: effective.layout,
    );

    final anchor = node.anchor;
    if (anchor != null && anchors != null) {
      body = KeyedSubtree(key: anchors!.keyFor(anchor), child: body);
    }
    return node.reveal ? Reveal(child: body) : body;
  }
}
