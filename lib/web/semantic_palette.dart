import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../domain/entities/booking.dart';

/// Categorical colour languages: plan tier, member role, property type and
/// booking source.
///
/// These are *not* brand colours. A tier badge says "Enterprise", not "HotRest",
/// so it must stay put when the brand moves — the opposite rule to
/// [AppTheme.adminPrimary].
///
/// Each of these maps previously existed in several places at once, with
/// different values: `pro` was gold in two files, violet in a third and navy in
/// three more, so the same customer appeared on three different plans depending
/// which screen you looked at. One source here, and the duplicates point at it.
///
/// Every colour is used as text on a ~12% tint of itself, so each is dark
/// enough to clear 4.5:1 against that tint. The previous values mostly were
/// not: gold `#D4A853` managed 2.20:1.
class SemanticPalette {
  SemanticPalette._();

  // ─── Plan tier ────────────────────────────────────────────────────────────
  // Hues follow whichever of the old palettes was in the majority, so no tier
  // changes character; only the lightness moved, to make the text readable.

  static const tierFree = Color(0xFF334155); // slate
  static const tierStarter = Color(0xFF047857); // emerald
  static const tierGrowth = Color(0xFF1D4ED8); // blue
  static const tierPro = Color(0xFF854D0E); // amber, the old "premium" gold
  static const tierEnterprise = Color(0xFF6D28D9); // violet

  /// Colour for a plan slug. Unknown slugs fall back to [tierFree] rather than
  /// to the brand, so an unrecognised plan never masquerades as chrome.
  static Color tier(String? slug) {
    switch ((slug ?? '').toLowerCase()) {
      case 'starter':
        return tierStarter;
      case 'growth':
        return tierGrowth;
      case 'pro':
        return tierPro;
      case 'enterprise':
        return tierEnterprise;
      default:
        return tierFree;
    }
  }

  // ─── Member role ──────────────────────────────────────────────────────────

  static const roleOwner = Color(0xFF854D0E);
  static const roleAdmin = Color(0xFF1D4ED8);
  static const roleManager = Color(0xFF6D28D9);
  static const roleStaff = Color(0xFF334155);

  static Color role(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'owner':
        return roleOwner;
      case 'admin':
        return roleAdmin;
      case 'manager':
        return roleManager;
      default:
        return roleStaff;
    }
  }

  // ─── Property type ────────────────────────────────────────────────────────

  static Color propertyType(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'hotel':
        return tierGrowth;
      case 'resort':
        return tierPro;
      case 'hostel':
        return tierEnterprise;
      default:
        return tierFree;
    }
  }

  // ─── Booking source ───────────────────────────────────────────────────────
  // These are other companies' brand colours, not ours. They are exact on
  // purpose and must not be re-themed: a Booking.com row is recognised by that
  // specific blue. Previously duplicated across three files, two of which had
  // drifted so the same source showed different colours on different screens.

  static const sourceDirect = Color(0xFF047857);
  static const sourceBookingCom = Color(0xFF003580);
  static const sourceAirbnb = Color(0xFFFF5A5F);
  static const sourceExpedia = Color(0xFF00355F);
  static const sourceAgoda = Color(0xFFE2231A);
  static const sourceWalkIn = Color(0xFF854D0E);

  static Color bookingSource(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom:
        return sourceBookingCom;
      case BookingSource.airbnb:
        return sourceAirbnb;
      case BookingSource.expedia:
        return sourceExpedia;
      case BookingSource.direct:
        return sourceDirect;
      case BookingSource.other:
        return sourceWalkIn;
    }
  }
}
