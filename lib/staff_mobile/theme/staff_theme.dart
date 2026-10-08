import 'package:flutter/material.dart';

/// Theme for the staff mobile app.
///
/// Deliberately separate from `lib/app_theme.dart`, which ~40 web files import
/// and whose `mobileTheme` is the dark-gold *guest kiosk* look. Its private
/// `_gold*` / `_dark*` constants are also re-exported as getters that the web
/// sidebar uses, so editing that file to suit the staff app would repaint web
/// chrome. Nothing here is shared with web.
///
/// Design constraints this encodes, from how the app is actually used:
///   * One-handed, while standing, often in a hurry — every tappable target is
///     at least [minTouchTarget] on its short side.
///   * Bright dining rooms and dim kitchens — high contrast, and a real dark
///     theme rather than a dimmed light one.
///   * Glanceable table state — [tableStatus] colours are the one piece of
///     colour language staff must read at arm's length.
class StaffTheme {
  StaffTheme._();

  /// Minimum side of any interactive element. Material's default is 48dp; the
  /// primary floor and menu targets go well above this.
  static const double minTouchTarget = 48.0;

  static const double radius = 14.0;
  static const double gap = 12.0;

  // ─── Brand ────────────────────────────────────────────────────────────────
  // Sampled from assets/images/hotrest_logo_new.png: the mark is navy with a
  // teal ribbon through it, and those two are the whole palette.
  //
  // Still not the web panel's burnt orange — orange collides with the "order
  // is late" ageing colour on the floor and kitchen screens.

  /// The navy of the mark and wordmark. 13.98:1 on white, so it carries body
  /// text and white-on-navy buttons comfortably.
  static const brandNavy = Color(0xFF012C58);

  /// The teal of the ribbon. Only **3.42:1** on white, which fails WCAG AA for
  /// body text — so this is the colour of the mark and of large accents, never
  /// of a surface that has small white text on it. Use [brandTealInk] there.
  static const brandTeal = Color(0xFF0D9B94);

  /// The ribbon teal darkened to 4.98:1 on white: same hue, same family,
  /// but legible under small text. This is what interactive teal surfaces use.
  static const brandTealInk = Color(0xFF0A7D77);

  static const _seedLight = brandNavy;

  // Dark theme keeps a lifted teal: navy on a near-black ground has almost no
  // separation, so the brand reads through the accent rather than the primary.
  static const _seedDark = Color(0xFF5FC9C1);

  // ─── Table status ─────────────────────────────────────────────────────────
  // The colour language of the floor. Kept as an explicit map rather than
  // theme colours so it reads identically in both brightnesses.

  static const tableFree = Color(0xFF5F716D);
  static const tableSeated = Color(0xFF2F5E86);
  static const tableInKitchen = Color(0xFFC2410C);
  static const tableReady = Color(0xFF0E6E5E);
  static const tableBillRequested = Color(0xFF8A6100);

  static ThemeData get light => _build(Brightness.light, _seedLight);
  static ThemeData get dark => _build(Brightness.dark, _seedDark);

  static ThemeData _build(Brightness brightness, Color seed) {
    final isDark = brightness == Brightness.dark;

    // Material generates a harmonious tonal palette from the seed, then the
    // brand colours are pinned back on top of it in light mode. Without the
    // override, M3 lightens the navy into a mid-blue that is recognisably not
    // the logo. Dark mode keeps the generated tones: the real navy is unusable
    // as a primary on a near-black surface.
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = isDark
        ? base
        : base.copyWith(
            primary: brandNavy,
            onPrimary: Colors.white,
            secondary: brandTealInk,
            onSecondary: Colors.white,
            tertiary: brandTeal,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Light stays light — only the tint moves, from the old teal-leaning
      // neutral to one that sits under navy without looking green.
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B1013) : const Color(0xFFF3F5F8),
      fontFamily: 'Inter',

      // Larger base sizes than the web panel: this is read at arm's length.
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 15),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
