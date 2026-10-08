import 'package:flutter/material.dart';

/// The HotRest lockup, from `assets/images/hotrest_logo_new.png`.
///
/// The web panel now shares this identity, but not this file: its slots are
/// square, so it uses `hotrest_mark.png` and `hotrest_mark_light.png`, plus
/// `hotrest_logo_light.png` for the reversed lockup on its dark auth screens.
///
/// The asset is navy on a transparent ground, so it needs a light surface
/// behind it. Every placement here is on `surface` or white.
class BrandLogo extends StatelessWidget {
  /// Width in logical pixels. Height follows the lockup's 3.12:1 ratio.
  final double width;

  const BrandLogo({super.key, this.width = 200});

  /// Aspect ratio of the trimmed lockup (1961 x 629 in the source).
  static const _ratio = 1961 / 629;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/hotrest_logo_new.png',
      width: width,
      height: width / _ratio,
      fit: BoxFit.contain,
      // Decoded at display size rather than at the source's 2172px, which
      // would hold several megabytes of bitmap for a 200px logo.
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      // The lockup is the brand; if it cannot load, the wordmark in text is a
      // better fallback than a broken-image glyph.
      errorBuilder: (context, _, __) => Text(
        'HotRest',
        style: TextStyle(
          fontSize: width / 5,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
