import 'json_reader.dart';

/// The three layouts the site distinguishes. Matches the breakpoints in
/// `brand_kit.dart` (`LK.isMobile` < 768, `LK.isTablet` < 1100).
enum Device { mobile, tablet, desktop }

/// Per-device visibility of a section.
class DeviceVisibility {
  const DeviceVisibility({this.desktop = true, this.tablet = true, this.mobile = true});

  factory DeviceVisibility.fromJson(J j) => DeviceVisibility(
        desktop: j.flag('desktop', true),
        tablet: j.flag('tablet', true),
        mobile: j.flag('mobile', true),
      );

  final bool desktop;
  final bool tablet;
  final bool mobile;

  bool visibleOn(Device d) => switch (d) {
        Device.desktop => desktop,
        Device.tablet => tablet,
        Device.mobile => mobile,
      };
}

/// One section of a page: what it is, whether it shows, and its settings.
///
/// [content], [layout] and [style] stay as readers over the raw JSON. The
/// editor works on JSON and the section builders parse what they need, so
/// there is one source of truth and no second typed copy to drift.
class SectionNode {
  const SectionNode({
    required this.id,
    required this.type,
    this.enabled = true,
    this.visibility = const DeviceVisibility(),
    this.anchor,
    this.content = const J({}),
    this.layout = const J({}),
    this.style = const J({}),
  });

  /// Throws [FormatException] without an id and type — a section the registry
  /// cannot identify is not something to guess at. [SiteDocument.fromJson]
  /// catches it and drops just that section.
  factory SectionNode.fromJson(J j) {
    final id = j.str('id');
    final type = j.str('type');
    if (id.isEmpty || type.isEmpty) {
      throw const FormatException('section needs an id and a type');
    }
    return SectionNode(
      id: id,
      type: type,
      enabled: j.flag('enabled', true),
      visibility: DeviceVisibility.fromJson(j.obj('visibility')),
      anchor: j.strOrNull('anchor'),
      content: j.obj('content'),
      layout: j.obj('layout'),
      style: j.obj('style'),
    );
  }

  final String id;
  final String type;
  final bool enabled;
  final DeviceVisibility visibility;

  /// Target for in-page links ("features", "pricing"). Independent of [id] so
  /// renaming a section never breaks a link.
  final String? anchor;

  final J content;
  final J layout;
  final J style;

  /// Whether the section takes the standard gap before it. Hero and the stats
  /// strip sit flush; everything else is separated.
  bool get spaceBefore => layout.str('spaceBefore', 'section') == 'section';

  /// Whether the section fades in on scroll.
  bool get reveal => style.flag('reveal', true);
}

/// A page's ordered list of sections.
class SiteDocument {
  const SiteDocument({this.schema = 1, this.sections = const [], this.seo = const J({})});

  /// Tolerant: a malformed section is dropped, not fatal.
  factory SiteDocument.fromJson(Object? v) {
    final j = J.of(v);
    return SiteDocument(
      schema: j.integer('schema', 1),
      seo: j.obj('seo'),
      sections: j.list('sections', SectionNode.fromJson),
    );
  }

  final int schema;
  final List<SectionNode> sections;
  final J seo;

  SectionNode? byId(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}
