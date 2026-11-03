import 'dart:math' as math;
import 'dart:ui' show Color;

/// Parses `#RGB` or `#RRGGBB`. Anything else is null, so a half-typed value in
/// the editor, or junk in a hand-edited document, is ignored rather than throwing.
Color? parseHexColor(String? s) {
  if (s == null) return null;
  var v = s.trim();
  if (!v.startsWith('#')) return null;
  v = v.substring(1);
  if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
  if (v.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) return null;
  return Color(0xFF000000 | int.parse(v, radix: 16));
}

String colorToHex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}

/// WCAG relative luminance.
double _luminance(Color c) {
  double chan(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}

/// WCAG contrast ratio, 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
