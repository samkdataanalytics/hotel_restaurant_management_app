import 'dart:ui' show Color;

import 'package:flutter/widgets.dart';

import '../model/color_ref.dart';
import '../model/json_reader.dart';
import '../model/responsive.dart';
import '../model/site_document.dart';

/// The text roles the marketing site draws with. Each maps to an `LK` style.
enum TypeSlot { display, heading, subheading, lead }

/// Fonts the site bundles, and the weights each has. The editor offers only
/// these: a family that is not bundled would be fetched at runtime (and the site
/// does not do that), or fall back to something unintended.
class FontCatalog {
  FontCatalog._();

  static const outfit = 'Outfit';
  static const inter = 'Inter';
  static const dmSerif = 'DMSerifDisplay';

  static const families = [outfit, inter, dmSerif];

  static const labels = {
    outfit: 'Outfit (default)',
    inter: 'Inter',
    dmSerif: 'DM Serif Display',
  };

  static bool isKnown(String? f) => families.contains(f);

  /// DM Serif Display ships one weight; asking for w800 would be faux-bolded.
  static FontWeight? weightFor(String family, FontWeight requested) =>
      family == dmSerif ? FontWeight.w400 : requested;
}

/// Typography the admin has changed, at some level of the cascade.
///
/// Every field is optional: null means "inherit", so a page can change only the
/// heading size and leave everything else to the theme and the defaults.
class TypeOverrides {
  const TypeOverrides({
    this.sizes = const {},
    this.headingFont,
    this.bodyFont,
    this.headingColor,
    this.bodyColor,
  });

  static const none = TypeOverrides();

  final Map<TypeSlot, Responsive<double>> sizes;
  final String? headingFont;
  final String? bodyFont;
  final Color? headingColor;
  final Color? bodyColor;

  bool get isEmpty =>
      sizes.isEmpty &&
      headingFont == null &&
      bodyFont == null &&
      headingColor == null &&
      bodyColor == null;

  static const sizeRange = (min: 10.0, max: 120.0);

  factory TypeOverrides.fromJson(J j) {
    final sizes = <TypeSlot, Responsive<double>>{};
    for (final slot in TypeSlot.values) {
      final r = Responsive.number(j.obj(slot.name), min: sizeRange.min, max: sizeRange.max);
      if (r != null) sizes[slot] = r;
    }
    final hf = j.strOrNull('headingFont');
    final bf = j.strOrNull('bodyFont');
    return TypeOverrides(
      sizes: sizes,
      headingFont: FontCatalog.isKnown(hf) ? hf : null,
      bodyFont: FontCatalog.isKnown(bf) ? bf : null,
      headingColor: parseHexColor(j.strOrNull('headingColor')),
      bodyColor: parseHexColor(j.strOrNull('bodyColor')),
    );
  }

  /// [other] wins wherever it has a value: the cascade, narrow over wide.
  TypeOverrides merge(TypeOverrides? other) {
    if (other == null || other.isEmpty) return this;
    return TypeOverrides(
      sizes: {...sizes, ...other.sizes},
      headingFont: other.headingFont ?? headingFont,
      bodyFont: other.bodyFont ?? bodyFont,
      headingColor: other.headingColor ?? headingColor,
      bodyColor: other.bodyColor ?? bodyColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TypeOverrides &&
      other.headingFont == headingFont &&
      other.bodyFont == bodyFont &&
      other.headingColor == headingColor &&
      other.bodyColor == bodyColor &&
      other.sizes.length == sizes.length &&
      sizes.entries.every((e) {
        final o = other.sizes[e.key];
        return o != null &&
            o.desktop == e.value.desktop &&
            o.tablet == e.value.tablet &&
            o.mobile == e.value.mobile;
      });

  @override
  int get hashCode => Object.hash(headingFont, bodyFont, headingColor, bodyColor, sizes.length);
}

/// Layout the admin has changed: the content column's width.
class LayoutOverrides {
  const LayoutOverrides({this.maxWidth});

  static const none = LayoutOverrides();

  final double? maxWidth;

  static const widthRange = (min: 640.0, max: 1600.0);

  factory LayoutOverrides.fromJson(J j) {
    final w = j.raw['maxWidth'];
    return LayoutOverrides(
      maxWidth: w is num && w.isFinite ? w.toDouble().clamp(widthRange.min, widthRange.max) : null,
    );
  }

  LayoutOverrides merge(LayoutOverrides? o) =>
      o == null ? this : LayoutOverrides(maxWidth: o.maxWidth ?? maxWidth);
}

/// Hands [overrides] to every `LK` text style built below it.
class TypeScope extends InheritedWidget {
  const TypeScope({super.key, required this.overrides, required super.child});

  final TypeOverrides overrides;

  static TypeOverrides of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<TypeScope>()?.overrides ?? TypeOverrides.none;

  @override
  bool updateShouldNotify(TypeScope old) => overrides != old.overrides;

  static Device _device(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w < 768 ? Device.mobile : (w < 1100 ? Device.tablet : Device.desktop);
  }

  /// [base] with whatever applies to [slot] laid over it.
  static TextStyle style(BuildContext c, TypeSlot slot, TextStyle base) {
    final o = of(c);
    if (o.isEmpty) return base;

    final isHeading = slot != TypeSlot.lead;
    final font = isHeading ? o.headingFont : o.bodyFont;
    final size = o.sizes[slot]?.resolve(_device(c));
    final color = isHeading ? o.headingColor : o.bodyColor;

    return base.copyWith(
      fontFamily: font,
      fontWeight: font == null ? null : FontCatalog.weightFor(font, base.fontWeight ?? FontWeight.w400),
      fontSize: size,
      color: color,
    );
  }
}

/// Hands [overrides] to every [Shell] below it.
class LayoutScope extends InheritedWidget {
  const LayoutScope({super.key, required this.overrides, required super.child});

  final LayoutOverrides overrides;

  static LayoutOverrides of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<LayoutScope>()?.overrides ?? LayoutOverrides.none;

  @override
  bool updateShouldNotify(LayoutScope old) => overrides.maxWidth != old.overrides.maxWidth;
}
