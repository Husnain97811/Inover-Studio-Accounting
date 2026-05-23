// lib/core/theme/app_theme.dart
// Design system: Inover Studio ERP
// Colors: Deep forest emerald (#0B6B43) + Royal gold (#C49A4A)
// Typography: Inter (UI) + Instrument Serif (display) + JetBrains Mono (numbers)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

// ─────────────────────────────────────────────────
//  DESIGN TOKENS  (from colors_and_type.css)
// ─────────────────────────────────────────────────
class D {
  D._();
  // Brand — forest emerald
  static const brand500 = Color(0xFF0B6B43);
  static const brand600 = Color(0xFF075432);
  static const brand700 = Color(0xFF053D24);
  static const brand50 = Color(0xFFE8F0EA);
  static const brand100 = Color(0xFFC5DCC8);
  static const brand400 = Color(0xFF2E8851);

  // Gold
  static const gold400 = Color(0xFFC49A4A);
  static const gold300 = Color(0xFFD4AB52);
  static const gold200 = Color(0xFFE4C879);
  static const gold500 = Color(0xFFA47A2E);
  static const gold600 = Color(0xFF7E5E22);
  static const gold50 = Color(0xFFF9F1DA);
  static const gold100 = Color(0xFFF0DFA8);

  // Ink (text)
  static const ink800 = Color(0xFF0A1A11);
  static const ink700 = Color(0xFF142016);
  static const ink600 = Color(0xFF243027);
  static const ink400 = Color(0xFF5E6A5F);

  // Neutral (warm parchment)
  static const neutral50 = Color(0xFFF4EEDD);
  static const neutral100 = Color(0xFFEBE3CC);
  static const neutral200 = Color(0xFFDDD3B8);
  static const neutral300 = Color(0xFFC4B89A);
  static const neutral400 = Color(0xFF9F947A);
  static const neutral600 = Color(0xFF524B3A);
  static const neutral700 = Color(0xFF3A3527);

  // Semantic
  static const success500 = Color(0xFF0B6B43);
  static const success700 = Color(0xFF053D24);
  static const success50 = Color(0xFFE8F0EA);
  static const warning500 = Color(0xFFB07013);
  static const warning700 = Color(0xFF784A09);
  static const warning50 = Color(0xFFFBE9C8);
  static const danger500 = Color(0xFF9C2922);
  static const danger700 = Color(0xFF6B170F);
  static const danger50 = Color(0xFFF5DAD3);
  static const info500 = Color(0xFF1F4F73);
  static const info50 = Color(0xFFDCE8F0);

  // Surfaces (light mode)
  static const bgApp = neutral50; // parchment canvas
  static const bgSurface = Color(0xFFFFFEF9); // ivory cards
  static const bgCream = Color(0xFFF9F3DF);
  static const bgSidebar = ink800;
  static const fgPrimary = Color(0xFF1A2018);
  static const fgSecondary = neutral600;
  static const fgTertiary = Color(0xFF7A7158);
  static const fgOnInk = Color(0xFFF5EFD9);
  static const fgOnBrand = Color(0xFFFFFEF9);
  static const borderDefault = neutral200;
  static const borderSubtle = neutral100;
  static const borderGold = gold200;
  static const borderOnInk = Color(0x2EC49A4A); // gold 18% alpha

  // Layout
  static const sidebarWidth = 240.0;
  static const topbarHeight = 48.0;
  static const statusbarHeight = 24.0;
}

// ─────────────────────────────────────────────────
//  BIZ THEME  (per business type — only accents change,
//  base design system stays the same)
// ─────────────────────────────────────────────────
class BizTheme {
  final Color primary;
  final Color sidebarBg;
  final Color cardBg;
  final Color scaffoldBg;
  final IconData moduleIcon;
  final List<Color> chartColors;

  // These are ALWAYS the design-system values regardless of business type
  Color get gold => D.gold400;
  Color get ink => D.ink800;
  Color get fgOnSidebar => D.fgOnInk;
  Color get border => D.borderDefault;

  const BizTheme({
    required this.primary,
    required this.sidebarBg,
    required this.cardBg,
    required this.scaffoldBg,
    required this.moduleIcon,
    required this.chartColors,
  });
}

class AppTheme {
  AppTheme._();

  // All business types use the SAME base palette from the design system.
  // Only the primary accent color changes slightly.
  static BizTheme forBusiness(BusinessType type) {
    return switch (type) {
      BusinessType.medical => const BizTheme(
        primary: D.info500,
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.local_hospital_rounded,
        chartColors: [D.info500, D.brand500, D.gold400, D.warning500],
      ),
      BusinessType.restaurant => const BizTheme(
        primary: D.danger500,
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.restaurant_rounded,
        chartColors: [D.danger500, D.gold400, D.brand500, D.warning500],
      ),
      BusinessType.electronics => const BizTheme(
        primary: Color(0xFF4B4ACF),
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.devices_rounded,
        chartColors: [Color(0xFF4B4ACF), D.brand500, D.gold400, D.info500],
      ),
      BusinessType.bookshop => const BizTheme(
        primary: D.warning700,
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.menu_book_rounded,
        chartColors: [D.warning700, D.brand500, D.gold400, D.info500],
      ),
      BusinessType.clothing => const BizTheme(
        primary: Color(0xFF8B3A6E),
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.checkroom_rounded,
        chartColors: [Color(0xFF8B3A6E), D.gold400, D.brand500, D.info500],
      ),
      BusinessType.distribution => const BizTheme(
        primary: D.info500,
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.local_shipping_rounded,
        chartColors: [D.info500, D.brand500, D.gold400, D.warning500],
      ),
      _ => const BizTheme(
        // general / default — pure design-system emerald
        primary: D.brand500,
        sidebarBg: D.bgSidebar,
        cardBg: D.bgSurface,
        scaffoldBg: D.bgApp,
        moduleIcon: Icons.store_rounded,
        chartColors: [D.brand500, D.gold400, D.info500, D.warning500],
      ),
    };
  }

  static ThemeData build(BizTheme biz) {
    // Always light mode — design system is parchment-light
    final fg = D.fgPrimary;
    final fgMuted = D.fgSecondary;
    final border = D.borderDefault;
    final surface = D.bgSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: biz.scaffoldBg,
      colorScheme: ColorScheme.light(
        primary: biz.primary,
        onPrimary: D.fgOnBrand,
        secondary: D.gold400,
        onSecondary: D.ink800,
        tertiary: D.brand400,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: fg,
        error: D.danger500,
        onError: Colors.white,
        outline: border,
        surfaceContainerHighest: D.bgCream,
      ),
      textTheme: _buildTextTheme(fg, fgMuted),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        shadowColor: const Color(0x0A0A1A11),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        constraints: const BoxConstraints(minHeight: 32),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: D.neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: D.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: D.brand500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: D.danger500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: D.danger500, width: 1.5),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fgMuted,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: D.fgTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: biz.primary,
          foregroundColor: D.fgOnBrand,
          elevation: 0,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          side: const BorderSide(color: D.neutral300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: biz.primary,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: D.fgPrimary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: D.borderDefault),
        ),
        shadowColor: const Color(0x1A0A1A11),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: D.ink800,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: D.fgOnInk,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? D.brand500
              : Colors.transparent,
        ),
        side: const BorderSide(color: D.neutral300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color fg, Color muted) {
    // Inter for all UI, numbers use JetBrains Mono via explicit style
    return TextTheme(
      displayLarge: _ts(
        36,
        FontWeight.w400,
        fg,
        fontFamily: 'Instrument Serif',
        height: 1.05,
      ),
      displayMedium: _ts(
        28,
        FontWeight.w400,
        fg,
        fontFamily: 'Instrument Serif',
        height: 1.1,
      ),
      displaySmall: _ts(
        22,
        FontWeight.w400,
        fg,
        fontFamily: 'Instrument Serif',
        height: 1.15,
      ),
      headlineLarge: _ts(18, FontWeight.w600, fg),
      headlineMedium: _ts(15, FontWeight.w600, fg),
      headlineSmall: _ts(14, FontWeight.w600, fg),
      titleLarge: _ts(14, FontWeight.w600, fg),
      titleMedium: _ts(13, FontWeight.w500, fg),
      titleSmall: _ts(12, FontWeight.w500, fg),
      bodyLarge: _ts(14, FontWeight.w400, fg),
      bodyMedium: _ts(13, FontWeight.w400, fg),
      bodySmall: _ts(12, FontWeight.w400, muted),
      labelLarge: _ts(13, FontWeight.w500, fg),
      labelMedium: _ts(12, FontWeight.w500, muted),
      labelSmall: _ts(10, FontWeight.w700, D.fgTertiary, letterSpacing: 0.08),
    );
  }

  static TextStyle _ts(
    double size,
    FontWeight weight,
    Color color, {
    String fontFamily = 'Inter',
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// ── Semantic color helpers (unchanged API) ─────────
class SemColor {
  SemColor._();
  static const success = D.success500;
  static const warning = D.warning500;
  static const error = D.danger500;
  static const info = D.info500;
  static const successBg = D.success50;
  static const warningBg = D.warning50;
  static const errorBg = D.danger50;
  static const infoBg = D.info50;
}
