import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  // ─── Mobile Theme (Luxury Hotel) ─────────────────────────

  static const _goldPrimary = Color(0xFFD4A853);
  static const _goldLight = Color(0xFFE8C97A);
  static const _goldDark = Color(0xFFB8922E);
  static const _darkBg = Color(0xFF1A1A2E);
  static const _darkSurface = Color(0xFF16213E);
  static const _darkCard = Color(0xFF1F2B47);
  static const _textLight = Color(0xFFF0F0F0);
  static const _textMuted = Color(0xFFB0B0C0);

  static ThemeData get mobileTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _goldPrimary,
        secondary: _goldLight,
        surface: _darkSurface,
        onPrimary: _darkBg,
        onSecondary: _darkBg,
        onSurface: _textLight,
      ),
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontFamily: 'Outfit', fontSize: 36, fontWeight: FontWeight.w700, color: _textLight, letterSpacing: -0.5),
        displayMedium:  TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w600, color: _textLight),
        headlineLarge:  TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w600, color: _textLight),
        headlineMedium: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: _textLight),
        titleLarge:     TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w500, color: _textLight),
        titleMedium:    TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w500, color: _textLight),
        bodyLarge:      TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w400, color: _textLight),
        bodyMedium:     TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w400, color: _textMuted),
        labelLarge:     TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: _goldPrimary, letterSpacing: 1.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _goldPrimary,
          foregroundColor: _darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _goldPrimary,
          side: const BorderSide(color: _goldPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCard,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: _goldLight, fontSize: 14),
        prefixIconColor: _goldPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _goldPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 6,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _goldPrimary,
        ),
        iconTheme: IconThemeData(color: _goldPrimary),
      ),
    );
  }

  // ─── Web Admin Theme ─────────────────────────────────────

  // ─── Brand ───────────────────────────────────────────────────────────────
  // Sampled from assets/images/hotrest_logo_new.png — the mark is a navy H
  // with a teal ribbon through it, and those two are the whole palette. They
  // replaced the previous burnt orange when the new logo was adopted.

  /// The navy of the mark and wordmark. 13.98:1 on white.
  static const brandNavy = Color(0xFF012C58);

  /// The teal of the ribbon, as drawn. Only 3.42:1 on white, so this is for
  /// the logo and large fills — never small text. Use [brandTeal] for that.
  static const brandTealPure = Color(0xFF0D9B94);

  /// The ribbon teal darkened to 4.98:1 on white: same hue, legible under
  /// body text and safe to put white text on. This is the usable teal.
  static const brandTeal = Color(0xFF0A7D77);

  /// Teal lifted for dark grounds. The pure teal is only 4.4:1 on the sidebar
  /// navy; this is 6.6:1 there and 7.8:1 on the darker auth gradients.
  static const brandTealOnDark = Color(0xFF3FBDB4);

  /// Brand accent for the dark screens — login, signup, invite, verify,
  /// onboarding and the guest QR pages.
  ///
  /// [adminPrimary] is navy and all but disappears there: 1.22:1 against the
  /// login card, where the burnt orange it replaced was 3.02:1. This is 4.99:1.
  static const brandOnDark = brandTealOnDark;

  /// Label colour for anything filled with [brandOnDark]: 6.09:1 on it, where
  /// white would be 2.30:1. No single teal clears both the 3:1 the fill needs
  /// against a dark card and the 4.5:1 a white label needs on the fill — the
  /// two ranges do not overlap — so dark labels are the way out.
  static const onBrandOnDark = brandNavy;

  static const _adminPrimary = brandNavy;
  static const _adminPrimaryLight = brandTeal;
  static const _adminBgDark = Color(0xFF0F172A);
  static const _adminSidebar = Color(0xFF101828);       // Elevate: Deeper Midnight
  static const _adminContent = Color(0xFFF8FAFC);       // Elevate: Soft Slate 50
  static const _adminCard = Colors.white;
  static const _adminTextDark = Color(0xFF1E293B);
  static const _adminTextMuted = Color(0xFF64748B);
  static const _adminSuccess = Color(0xFF22C55E);
  static const _adminWarning = Color(0xFFF59E0B);
  static const _adminDanger = Color(0xFFEF4444);

  static ThemeData get webTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _adminContent,
      colorScheme: const ColorScheme.light(
        primary: _adminPrimary,
        secondary: _adminPrimaryLight,
        surface: _adminCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _adminTextDark,
      ),
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 32, fontWeight: FontWeight.w400, color: _adminTextDark, letterSpacing: -0.3),
        displayMedium:  TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 24, fontWeight: FontWeight.w400, color: _adminTextDark),
        headlineLarge:  TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w600, color: _adminTextDark),
        headlineMedium: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: _adminTextDark),
        titleLarge:     TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: _adminTextDark),
        titleMedium:    TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500, color: _adminTextDark),
        bodyLarge:      TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w400, color: _adminTextDark, fontFeatures: [FontFeature.tabularFigures()]),
        bodyMedium:     TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w400, color: _adminTextMuted, fontFeatures: [FontFeature.tabularFigures()]),
        labelLarge:     TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: _adminPrimary),
      ),
      cardTheme: CardThemeData(
        color: _adminCard,
        elevation: 0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: cardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _adminPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // soft grey-blue instead of hard white
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _adminPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
        shadowColor: Colors.black26,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
        headingTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _adminTextMuted,
        ),
        dataTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _adminTextDark,
        ),
      ),
    );
  }

  // ─── DM Serif Display helpers ────────────────────────────────────────────────

  /// H3 — card headings and secondary dialog titles (20 px).
  static const TextStyle serifHeadingLarge = TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: _adminTextDark,
  );

  /// Utility — DM Serif at any size / color, for one-off uses.
  static TextStyle dmSerif({
    double fontSize = 18,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color ?? _adminTextDark,
        letterSpacing: letterSpacing,
      );

  // ─── Shared Design Tokens (used by all web screens) ─────────────────────────

  /// Unified card border-radius.
  /// Card corner radius. Was 12 here and in cardTheme while 22 call sites
  /// drew 16, so the loading skeleton did not match the screen that
  /// replaced it. Settled on the 16 already in use.
  static const double cardRadius = 16.0;

  /// Card border. Was an unnamed #E8EDF3 in cardTheme and cardDecoration
  /// while two screens drew Colors.grey.shade200 instead.
  static const Color cardBorder = Color(0xFFE8EDF3);

  /// Subtle card shadow shared by hotel and restaurant cards.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  /// Standard white card: consistent border, radius, shadow.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: cardBorder),
    boxShadow: cardShadow,
  );

  /// Wraps [child] in a KPI card with a coloured left accent strip.
  static Widget kpiCard({required Color accent, required Widget child}) {
    // Outer box: uniform border + borderRadius + shadow (flutter requires
    // uniform colors when borderRadius is set).
    // ClipRRect clips the inner content to the same radius.
    // Inner DecoratedBox: left accent strip only — no borderRadius, so valid.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: cardBorder),
        boxShadow: cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius - 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: child,
        ),
      ),
    );
  }

  // ─── Restaurant Section (const — safe in const expressions) ─────────────────

  // Teal, not the former orange: with navy as the brand primary the restaurant
  // side now reads as the ribbon through the mark, and orange was left looking
  // like the one survivor of the old palette. The hotel side keeps using each
  // property's own configurable colour, so the two halves stay distinguishable.
  //
  // restaurantAccent on restaurantAccentBg is 4.61:1 — the lightest tint that
  // still carries body text.
  static const Color restaurantAccent    = brandTeal;
  static const Color restaurantAccentBg  = Color(0xFFEFF8F7);
  static const Color restaurantAccentMid = Color(0xFFD5EDEB);

  // ─── Semantic Status Colors (const) ─────────────────────────────────────────

  static const Color statusGreen  = Color(0xFF22C55E);   // success / available
  static const Color statusAmber  = Color(0xFFF59E0B);   // warning / preparing
  static const Color statusRed    = Color(0xFFEF4444);   // danger / occupied
  static const Color statusBlue   = Color(0xFF2563EB);   // info / hotel accent
  static const Color statusPurple = Color(0xFF8B5CF6);   // payment due

  /// A child ticket added onto an open tab.
  ///
  /// Slate, not the teal it used to be. That teal (#009688) sat 11.4 dE from
  /// the brand accent once the brand went teal, so an add-on chip read as
  /// brand chrome. Slate is 25.3 dE from the nearest colour in this language
  /// and 7.58:1 on white, so it still carries chip text. It also says
  /// "subordinate", which is what an add-on is.
  static const Color statusAddOn  = Color(0xFF475569);

  /// Fallback brand colour for a property that has not picked one.
  ///
  /// Deliberately still gold, and deliberately NOT a HotRest brand colour:
  /// this slot belongs to the operator, it is offered as the first swatch in
  /// the property editor, and it is drawn on the dark sidebar where gold is
  /// 8.10:1. Painting it navy would both overwrite tenant branding and
  /// disappear (1.28:1). It lived as a bare literal in three places that could
  /// drift; the string form exists because OrgProperty.primaryColor is hex.
  static const Color defaultPropertyColor = Color(0xFFD4A853);
  static const String defaultPropertyColorHex = '#D4A853';

  /// An order that has been fired and is with the kitchen.
  ///
  /// Deliberately the same blue the kitchen board gives its "Preparing" lane
  /// (kitchen_screen.dart), so the floor and the board agree. The POS and
  /// table screens previously used a second hardcoded teal here, which after
  /// the rebrand was 9.9 dE from the brand accent beside it -- the two states
  /// could not be told apart.
  static const Color statusInKitchen = statusBlue;

  // ─── Page Background ─────────────────────────────────────────────────────────

  /// The page ground. Was declared as #F5F7FA and referenced nowhere, while
  /// nine screens hardcoded #F8FAFC -- the value the scaffold already uses.
  /// Re-pointed at the one in use rather than moving nine screens onto an
  /// unused shade.
  static const Color pageBg = Color(0xFFF8FAFC);

  // ─── Responsive helpers ───────────────────────────────────────────────────

  /// True when viewport width < 600 px (phone portrait).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  /// True when viewport width is between 600 and 1024 px.
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1024;
  }

  /// Standard scrollable-content padding: 16 on mobile, 32 on desktop.
  static EdgeInsets screenPad(BuildContext context) =>
      EdgeInsets.all(isMobile(context) ? 16.0 : 32.0);

  // ─── Helper Colors for Web Admin ─────────────────────────

  static Color get sidebarBg => _adminSidebar;
  static Color get sidebarDark => _adminBgDark;
  static Color get adminPrimary => _adminPrimary;
  static Color get success => _adminSuccess;
  static Color get warning => _adminWarning;
  static Color get danger => _adminDanger;
  static Color get adminTextMuted => _adminTextMuted;
  static Color get goldPrimary => _goldPrimary;
  static Color get goldLight => _goldLight;
  static Color get darkBg => _darkBg;
  static Color get darkCard => _darkCard;
  static Color get darkSurface => _darkSurface;
  static Color get textMuted => _textMuted;

  // ─── Gradient Decorations ────────────────────────────────

  static BoxDecoration get goldGradientDecoration => const BoxDecoration(
    gradient: LinearGradient(
      colors: [_goldDark, _goldPrimary, _goldLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  static BoxDecoration get darkGlassDecoration => BoxDecoration(
    color: _darkCard.withOpacity(0.7),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _goldPrimary.withOpacity(0.2)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
