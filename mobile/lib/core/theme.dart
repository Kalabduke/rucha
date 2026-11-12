import 'package:flutter/material.dart';

/// RUCHA design tokens — Ember Fitness-inspired revision.
///
/// Warm dark base, vivid orange primary, soft teal secondary.
/// Cards use elevation + subtle shadow instead of hard border lines.
class RuchaTheme {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background =
      Color(0xFF0E0E12); // near-black, slight warm tint
  static const Color surface = Color(0xFF17171D); // card background
  static const Color surface2 = Color(0xFF1E1E26); // elevated card
  static const Color surfaceLight = Color(0xFF26263A);
  static const Color sidebar = Color(0xFF0A0A0E);

  // ── Primary ──────────────────────────────────────────────────────────────
  /// Vivid orange — Start button, hero metric cards, record FAB
  static const Color accent = Color(0xFFFF6B2B);
  static const Color accentLight =
      Color(0xFFFF8C5A); // lighter tint for gradients
  static const Color accentCoral = accent;

  // ── Secondary ────────────────────────────────────────────────────────────
  static const Color accentGreen = Color(0xFF00D09C); // bright teal
  static const Color accentGold = Color(0xFFF5A623); // amber
  static const Color accentRed = Color(0xFFFF4D6A);
  static const Color accentBlue = Color(0xFF4B9EFF);

  // ── Activity colours ─────────────────────────────────────────────────────
  static const Color run = Color(0xFFFF6B2B);
  static const Color ride = Color(0xFF00D09C);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color border = Color(0xFF2A2A36);

  // ── Shared shadow ─────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow({Color? color, double opacity = 0.18}) => [
        BoxShadow(
          color: (color ?? Colors.black).withOpacity(opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentGreen,
        surface: surface,
        error: accentRed,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
