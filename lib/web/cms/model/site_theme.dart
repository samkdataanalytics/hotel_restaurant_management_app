import '../render/type_scope.dart';
import 'json_reader.dart';
import 'responsive.dart';

/// Typography and layout at one level of the cascade (the global theme, or one
/// page). `merge` lays a narrower level over a wider one.
class SiteTheme {
  const SiteTheme({
    this.type = TypeOverrides.none,
    this.layout = LayoutOverrides.none,
    this.sectionGap,
  });

  static const none = SiteTheme();

  final TypeOverrides type;
  final LayoutOverrides layout;

  /// Vertical gap between sections, per device. Null keeps the built-in rhythm.
  final Responsive<double>? sectionGap;

  static const gapRange = (min: 0.0, max: 320.0);

  /// Reads the shape shared by `global:theme` and a page document:
  /// `{typography: {...}, layout: {maxWidth: 1180, sectionGap: {desktop, mobile}}}`.
  factory SiteTheme.fromJson(J typography, J layout) => SiteTheme(
        type: TypeOverrides.fromJson(typography),
        layout: LayoutOverrides.fromJson(layout),
        sectionGap: Responsive.number(layout.obj('sectionGap'), min: gapRange.min, max: gapRange.max),
      );

  SiteTheme merge(SiteTheme? o) => o == null
      ? this
      : SiteTheme(
          type: type.merge(o.type),
          layout: layout.merge(o.layout),
          sectionGap: o.sectionGap ?? sectionGap,
        );
}
