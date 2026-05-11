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

  static const _adminPrimary = Color(0xFFE65100);       // Elevate: Burnt Orange
  static const _adminPrimaryLight = Color(0xFFFF9800);  // Elevate: Lighter Orange
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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8EDF3)),
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
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _adminTextMuted,
        ),
        dataTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _adminTextDark,
        ),
      ),
    );
  }

  // ─── DM Serif Display helpers ────────────────────────────────────────────────

  /// H1 — large page display titles (32 px).
  static const TextStyle serifDisplayLarge = TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: _adminTextDark,
    letterSpacing: -0.3,
  );

  /// H2 — page-level section titles and prominent dialog headings (24 px).
  static const TextStyle serifDisplayMedium = TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: _adminTextDark,
  );

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
  static const double cardRadius = 12.0;

  /// Standard horizontal page content padding.
  static const double pagePadH = 32.0;

  /// Subtle card shadow shared by hotel and restaurant cards.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  /// Standard white card: consistent border, radius, shadow.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: const Color(0xFFE8EDF3)),
    boxShadow: cardShadow,
  );

  /// KPI card base decoration (uniform border — safe with borderRadius).
  /// Use [kpiCard] to get the full left-accent card widget.
  static BoxDecoration kpiDecoration(Color accent) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: const Color(0xFFE8EDF3)),
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
        border: Border.all(color: const Color(0xFFE8EDF3)),
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

  static const Color restaurantAccent    = Color(0xFFF97316);
  static const Color restaurantAccentBg  = Color(0xFFFFF7ED);
  static const Color restaurantAccentMid = Color(0xFFFFEDD5);

  // ─── Semantic Status Colors (const) ─────────────────────────────────────────

  static const Color statusGreen  = Color(0xFF22C55E);   // success / available
  static const Color statusAmber  = Color(0xFFF59E0B);   // warning / preparing
  static const Color statusRed    = Color(0xFFEF4444);   // danger / occupied
  static const Color statusBlue   = Color(0xFF2563EB);   // info / hotel accent
  static const Color statusPurple = Color(0xFF8B5CF6);   // payment due

  // ─── Page Background ─────────────────────────────────────────────────────────

  static const Color pageBg = Color(0xFFF5F7FA);

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
