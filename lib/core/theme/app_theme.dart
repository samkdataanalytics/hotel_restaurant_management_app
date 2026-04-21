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

  static const _adminPrimary = Color(0xFF3B82F6);
  static const _adminPrimaryLight = Color(0xFF60A5FA);
  static const _adminBgDark = Color(0xFF0F172A);
  static const _adminSidebar = Color(0xFF1E293B);
  static const _adminContent = Color(0xFFF8FAFC);
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
        displayLarge:   TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w700, color: _adminTextDark),
        displayMedium:  TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600, color: _adminTextDark),
        headlineLarge:  TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, color: _adminTextDark),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: _adminTextDark),
        titleLarge:     TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: _adminTextDark),
        titleMedium:    TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: _adminTextDark),
        bodyLarge:      TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400, color: _adminTextDark),
        bodyMedium:     TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, color: _adminTextMuted),
        labelLarge:     TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _adminPrimary),
      ),
      cardTheme: CardThemeData(
        color: _adminCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
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
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _adminPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _adminTextMuted,
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _adminTextDark,
        ),
      ),
    );
  }

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
