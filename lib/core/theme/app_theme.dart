import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';

class AppTheme {
  static ThemeData lightTheme(AccentPreset accentPreset) {
    final TextTheme textTheme = GoogleFonts.plusJakartaSansTextTheme();
    final Color primary = accentPreset.primary;
    final Color glow = accentPreset.glow;

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.deepBlue,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.deepBlue,
        ),
      ),
      dividerColor: AppColors.deepBlue.withValues(alpha: 0.08),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.96),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.deepBlue.withValues(alpha: 0.56),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.deepBlue.withValues(alpha: 0.68),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.bodySmall,
        prefixIconColor: primary.withValues(alpha: 0.86),
        suffixIconColor: AppColors.deepBlue.withValues(alpha: 0.62),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.deepBlue.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.deepBlue.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF8D97A7),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.deepBlue.withValues(alpha: 0.08)),
        selectedColor: glow.withValues(alpha: 0.16),
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        labelStyle: textTheme.bodySmall,
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  static ThemeData darkTheme(AccentPreset accentPreset) {
    final TextTheme textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    final Color primary = accentPreset.primary;
    final Color secondary = accentPreset.secondary;
    final Color glow = accentPreset.glow;

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 13,
          color: AppColors.softGrayText,
        ),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.09),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.62),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.bodySmall,
        prefixIconColor: glow.withValues(alpha: 0.95),
        suffixIconColor: Colors.white.withValues(alpha: 0.62),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: glow, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: glow,
        unselectedItemColor: AppColors.softGrayText.withValues(alpha: 0.9),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        selectedColor: secondary.withValues(alpha: 0.24),
        backgroundColor: Colors.white.withValues(alpha: 0.09),
        labelStyle: textTheme.bodySmall,
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

