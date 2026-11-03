import 'package:flutter/widgets.dart';

import '../model/color_ref.dart';
import '../model/responsive.dart';
import '../model/site_document.dart';
import 'type_scope.dart';

/// Applies a section's own layout and style around whatever it draws:
/// background colour, extra padding, content width, and type overrides.
///
/// Sections stay unaware of all this. They keep reading `LK` styles and using
/// `Shell`; the scopes below the frame change what those return. A section with
/// no overrides gets no wrapper at all, so an unedited page builds exactly the
/// same widgets as before the CMS existed.
class SectionFrame {
  const SectionFrame._();

  static const paddingRange = (min: 0.0, max: 400.0);

  static Widget wrap(
    BuildContext context,
    SectionNode node,
    Widget body, {
    required TypeOverrides inheritedType,
    required LayoutOverrides inheritedLayout,
  }) {
    final type = inheritedType.merge(TypeOverrides.fromJson(node.typography));
    final layout = inheritedLayout.merge(LayoutOverrides.fromJson(node.layout));
    final device = _device(context);

    final background = parseHexColor(node.style.strOrNull('background'));
    final padTop = Responsive.number(node.layout.obj('paddingTop'),
        min: paddingRange.min, max: paddingRange.max);
    final padBottom = Responsive.number(node.layout.obj('paddingBottom'),
        min: paddingRange.min, max: paddingRange.max);

    Widget out = body;

    if (padTop != null || padBottom != null) {
      out = Padding(
        padding: EdgeInsets.only(
          top: padTop?.resolve(device) ?? 0,
          bottom: padBottom?.resolve(device) ?? 0,
        ),
        child: out,
      );
    }
    if (background != null) {
      out = ColoredBox(color: background, child: SizedBox(width: double.infinity, child: out));
    }
    // Scopes are skipped when empty so an untouched section builds the same
    // widget tree it always did.
    if (layout.maxWidth != null) out = LayoutScope(overrides: layout, child: out);
    if (!type.isEmpty) out = TypeScope(overrides: type, child: out);
    return out;
  }

  static Device _device(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w < 768 ? Device.mobile : (w < 1100 ? Device.tablet : Device.desktop);
  }
}
