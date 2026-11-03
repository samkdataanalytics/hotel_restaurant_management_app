import 'json_reader.dart';
import 'site_document.dart';

/// A value that can differ by device, with the usual fallback: mobile uses its
/// own value, else tablet's, else desktop's; tablet uses its own, else desktop's.
///
/// Mirrors how the page's breakpoints already behave (`LK.isMobile` < 768,
/// `LK.isTablet` < 1100), so a heading set to "64 / 48 / 32" changes at the same
/// widths the layout does.
class Responsive<T> {
  const Responsive(this.desktop, {this.tablet, this.mobile});

  final T desktop;
  final T? tablet;
  final T? mobile;

  T resolve(Device d) => switch (d) {
        Device.desktop => desktop,
        Device.tablet => tablet ?? desktop,
        Device.mobile => mobile ?? tablet ?? desktop,
      };

  /// Which devices have their own value (as opposed to inheriting).
  bool hasOwn(Device d) => switch (d) {
        Device.desktop => true,
        Device.tablet => tablet != null,
        Device.mobile => mobile != null,
      };

  /// Reads `{"desktop": 64, "tablet": 48, "mobile": 32}`. Any may be missing, and
  /// values are clamped to [min]..[max], so a stray "6000" cannot draw a
  /// headline taller than the page. Null when nothing usable is present.
  static Responsive<double>? number(J j, {required double min, required double max}) {
    double? read(String k) {
      final v = j.raw[k];
      return v is num && v.isFinite ? v.toDouble().clamp(min, max) : null;
    }

    final d = read('desktop');
    final t = read('tablet');
    final m = read('mobile');
    final base = d ?? t ?? m;
    if (base == null) return null;
    return Responsive<double>(d ?? base, tablet: t, mobile: m);
  }

  Map<String, Object?> toJson() => {
        'desktop': desktop,
        if (tablet != null) 'tablet': tablet,
        if (mobile != null) 'mobile': mobile,
      };
}
