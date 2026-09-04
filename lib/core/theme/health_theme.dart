import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens for Petrimonium Health, carried over from the Claude Design
/// prototype (`Petrimonium Health.dc.html`). Health is the "white-first"
/// member of the Petrimonium family: Wallet is green, Academy is purple,
/// Health leans on a warm neutral surface with a single terracotta accent.
abstract final class HealthColors {
  static const background = Color(0xFFF1EEE9);
  static const surface = Color(0xFFFBFAF8);
  static const card = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF4F1EC);

  static const textPrimary = Color(0xFF1C1B19);
  static const textSecondary = Color(0xFF746F68);
  static const textMuted = Color(0xFF8A8378);

  static const border = Color(0x1F1C1B19);
  static const borderSoft = Color(0x141C1B19);

  static const positive = Color(0xFF3F7D5C);
  static const negative = Color(0xFFB23B2E);

  static const mentorAccent = Color(0xFF7A5FD1);
  static const mentorTint = Color(0x1AC5ABFF);
}

/// The three accent options the design offers for Health's theme. The first
/// entry is the default used across the prototype.
abstract final class HealthAccent {
  static const terracotta = Color(0xFFC1502E);
  static const rust = Color(0xFFB2451F);
  static const ochre = Color(0xFFA8632E);

  static const List<Color> options = [terracotta, rust, ochre];
}

ThemeData buildHealthTheme({Color accent = HealthAccent.terracotta}) {
  final textTheme = GoogleFonts.outfitTextTheme().apply(
    bodyColor: HealthColors.textPrimary,
    displayColor: HealthColors.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: HealthColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      surface: HealthColors.surface,
    ),
    fontFamily: GoogleFonts.outfit().fontFamily,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: HealthColors.surface,
      foregroundColor: HealthColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HealthColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HealthColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HealthColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
      hintStyle: const TextStyle(color: Color(0xFFB7B0A5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    dividerColor: HealthColors.border,
  );
}
