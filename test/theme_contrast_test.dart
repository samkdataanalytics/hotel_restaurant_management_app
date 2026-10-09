import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/app_theme.dart';
import 'package:hotel_checkin/web/semantic_palette.dart';

/// Guards the colour language against the two failures that actually happened.
///
/// When the brand moved from burnt orange to teal, a hardcoded teal meaning
/// "in kitchen" ended up 9.9 dE from the brand accent sitting beside it, and
/// navy ended up at 1.28:1 on the superadmin sidebar. Both were invisible to
/// `flutter analyze` and to a glance at the diff. These assertions are cheap
/// and would have failed on that commit.

// ─── Colour maths ────────────────────────────────────────────────────────────

double _linear(int c) {
  final s = c / 255;
  return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG relative luminance.
double _luminance(Color c) {
  final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
  return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE L*a*b*, D65.
List<double> _lab(Color c) {
  final r = _linear((c.r * 255).round());
  final g = _linear((c.g * 255).round());
  final b = _linear((c.b * 255).round());
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.0;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// CIE76 colour difference. Under ~10 is confusable at a glance.
double deltaE(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(math.pow(la[0] - lb[0], 2) +
      math.pow(la[1] - lb[1], 2) +
      math.pow(la[2] - lb[2], 2));
}

void main() {
  // The two grounds the dark chrome is drawn on.
  const sidebarDark = Color(0xFF0F172A);
  const sidebarTop = Color(0xFF1A2540);

  group('brand separation from the operational language', () {
    // Every colour that carries operational meaning. If a brand colour drifts
    // close to one of these, staff lose a distinction they rely on.
    const semantic = <String, Color>{
      'green / ready': AppTheme.statusGreen,
      'amber / preparing-warning': AppTheme.statusAmber,
      'red / late-danger': AppTheme.statusRed,
      'blue / in-kitchen': AppTheme.statusBlue,
      'purple / payment due': AppTheme.statusPurple,
      'slate / add-on': AppTheme.statusAddOn,
    };

    // 20 is well clear of the ~10 where two colours become confusable, while
    // still leaving room for a palette this size.
    const minSeparation = 20.0;

    for (final entry in semantic.entries) {
      test('restaurantAccent is distinguishable from ${entry.key}', () {
        final d = deltaE(AppTheme.restaurantAccent, entry.value);
        expect(d, greaterThan(minSeparation),
            reason: 'brand accent is only ${d.toStringAsFixed(1)} dE from '
                '${entry.key} — these would be confused at a glance');
      });

      test('adminPrimary is distinguishable from ${entry.key}', () {
        final d = deltaE(AppTheme.adminPrimary, entry.value);
        expect(d, greaterThan(minSeparation),
            reason: 'brand primary is only ${d.toStringAsFixed(1)} dE from '
                '${entry.key}');
      });
    }

    test('the operational colours are distinguishable from each other', () {
      final entries = semantic.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final d = deltaE(entries[i].value, entries[j].value);
          expect(d, greaterThan(minSeparation),
              reason: '${entries[i].key} and ${entries[j].key} are only '
                  '${d.toStringAsFixed(1)} dE apart');
        }
      }
    });
  });

  group('the categorical palettes stay readable and distinct', () {
    // Tier, role and type chips all render as text on a ~12% tint of
    // themselves. The palettes these replaced mostly failed that: the old gold
    // managed 2.20:1.
    Color tintOf(Color c) => Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white);

    const tiers = <String, Color>{
      'free': SemanticPalette.tierFree,
      'starter': SemanticPalette.tierStarter,
      'growth': SemanticPalette.tierGrowth,
      'pro': SemanticPalette.tierPro,
      'enterprise': SemanticPalette.tierEnterprise,
    };

    for (final e in tiers.entries) {
      test('${e.key} tier chip is legible on its own tint', () {
        expect(contrast(e.value, tintOf(e.value)), greaterThan(4.5));
      });
    }

    test('tiers are distinguishable from each other', () {
      final list = tiers.entries.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final d = deltaE(list[i].value, list[j].value);
          expect(d, greaterThan(20.0),
              reason: '${list[i].key} and ${list[j].key} are only '
                  '${d.toStringAsFixed(1)} dE apart');
        }
      }
    });

    test('an unknown plan slug does not fall back to a brand colour', () {
      final unknown = SemanticPalette.tier('something-new');
      expect(unknown, isNot(AppTheme.adminPrimary));
      expect(unknown, isNot(AppTheme.restaurantAccent));
    });

    test('booking sources keep their owners\' exact brand hexes', () {
      // These belong to Booking.com, Airbnb and Expedia. Re-theming them would
      // be wrong, so they are pinned rather than merely checked for contrast.
      expect(SemanticPalette.sourceBookingCom, const Color(0xFF003580));
      expect(SemanticPalette.sourceAirbnb, const Color(0xFFFF5A5F));
      expect(SemanticPalette.sourceExpedia, const Color(0xFF00355F));
    });
  });

  group('contrast on the grounds each token is actually used on', () {
    test('brandOnDark carries the superadmin sidebar', () {
      expect(contrast(AppTheme.brandOnDark, sidebarDark), greaterThan(4.5));
      expect(contrast(AppTheme.brandOnDark, sidebarTop), greaterThan(4.5));
    });

    test('adminPrimary would NOT carry a dark ground', () {
      // Documents why brandOnDark exists. If this ever starts passing the
      // brand has changed enough that the dark-surface rule needs revisiting.
      expect(contrast(AppTheme.adminPrimary, sidebarDark), lessThan(3.0));
    });

    test('adminPrimary carries the light surfaces', () {
      expect(contrast(AppTheme.adminPrimary, Colors.white), greaterThan(4.5));
      expect(contrast(AppTheme.adminPrimary, AppTheme.pageBg), greaterThan(4.5));
    });

    test('restaurantAccent carries body text on white and on its own tint', () {
      expect(contrast(AppTheme.restaurantAccent, Colors.white), greaterThan(4.5));
      expect(contrast(AppTheme.restaurantAccent, AppTheme.restaurantAccentBg),
          greaterThan(4.5));
    });

    test('statusAddOn carries chip text on white', () {
      expect(contrast(AppTheme.statusAddOn, Colors.white), greaterThan(4.5));
    });

    test('white labels are legible on the primary fill', () {
      expect(contrast(Colors.white, AppTheme.adminPrimary), greaterThan(4.5));
    });

    test('onBrandOnDark is legible on brandOnDark', () {
      // White on the lifted teal is only ~2.3:1, which is why the dark-screen
      // buttons take navy labels.
      expect(contrast(AppTheme.onBrandOnDark, AppTheme.brandOnDark),
          greaterThan(4.5));
    });
  });
}
