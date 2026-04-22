import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Brand (from website exactly) ──────────────────────────────────────────
  static const teal        = Color(0xFF0D9E9A);
  static const tealLight   = Color(0xFFE6F7F7);
  static const tealDark    = Color(0xFF0A7A77);
  static const orange      = Color(0xFFF5841F);
  static const orangeLight = Color(0xFFFFF3E8);
  static const green       = Color(0xFF3BA34A);
  static const greenLight  = Color(0xFFEAF6EB);
  static const red         = Color(0xFFE53935);
  static const redLight    = Color(0xFFFFEBEE);

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background  = Color(0xFFF8FAFC);
  static const surface     = Color(0xFFFFFFFF);
  static const surface2    = Color(0xFFF1F5F9);
  static const border      = Color(0xFFE2E8F0);
  static const borderFocus = teal;

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textHint      = Color(0xFFCBD5E1);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = green;
  static const warning = orange;
  static const error   = red;
  static const primary = teal;

  // ── Priority ───────────────────────────────────────────────────────────────
  static Color priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical': return red;
      case 'high':     return orange;
      case 'medium':   return teal;
      default:         return textSecondary;
    }
  }

  static Color priorityBg(String p) {
    switch (p.toLowerCase()) {
      case 'critical': return redLight;
      case 'high':     return orangeLight;
      case 'medium':   return tealLight;
      default:         return surface2;
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base  = ThemeData.light(useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: inter,
      colorScheme: const ColorScheme.light(
        primary: AppColors.teal, secondary: AppColors.orange,
        surface: AppColors.surface, error: AppColors.red),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
        elevation: 0, scrolledUnderElevation: 1, shadowColor: AppColors.border,
        centerTitle: false, foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.inter(color: AppColors.textPrimary,
            fontSize: 17, fontWeight: FontWeight.w800),
        iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed, elevation: 8,
        selectedLabelStyle:   TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 10)),
      cardTheme: CardThemeData(color: AppColors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border))),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.surface2,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle:  const TextStyle(color: AppColors.textHint),
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 2))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal, foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14))),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.teal)),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.teal, unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.teal, dividerColor: AppColors.border),
    );
  }
}
