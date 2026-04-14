import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Factory de temas Material 3 da aplicação.
///
/// Define tokens visuais globais (cores, tipografia, inputs e cards)
/// para os modos claro e escuro.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.atrOrange,
        secondary: AppColors.textSecondaryLight,
        error: AppColors.statusError,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: const TextStyle(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        titleLarge: const TextStyle(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.atrOrange, width: 2),
        ),
        labelStyle:
            const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
        hintStyle:
            const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.atrOrange,
        secondary: AppColors.textSecondaryDark,
        surface: AppColors.surfaceDark,
        error: AppColors.statusError,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        titleLarge: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.atrOrange, width: 2),
        ),
        labelStyle:
            const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
        hintStyle:
            const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
