import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'dvcr_page_transitions.dart';

class DVCRTheme {
  // Couleurs statiques pour accès direct
  static const Color primaryRed = AppColors.red;
  static const Color primaryGreen = AppColors.green;
  static const Color darkBackground = AppColors.background;
  static const Color surfaceDark = AppColors.card;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = AppColors.grey;
  static const Color textMuted = Colors.white54;

  static const Gradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.black54, AppColors.background],
  );

  // Styles de texte statiques
  static TextStyle get displayLarge => GoogleFonts.barlowCondensed(
      fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white);
  static TextStyle get titleLarge => GoogleFonts.barlowCondensed(
      fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle get titleMedium => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get bodyLarge => GoogleFonts.inter(fontSize: 16);
  static TextStyle get bodyMedium => GoogleFonts.inter(fontSize: 14);
  static TextStyle get labelLarge => GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Couleurs de base
      colorScheme: const ColorScheme.dark(
        primary: AppColors.red,
        secondary: AppColors.gold,
        surface: AppColors.card,
      ),

      // Style des textes par défaut
      textTheme: TextTheme(
        displayLarge: GoogleFonts.barlowCondensed(
          fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: Colors.white70,
        ),
      ),

      // Style global des AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  /// Thème clair — app mobile **et** web (admin inclus).
  static ThemeData get lightTheme {
    const surface = AppColorsLight.card;
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColorsLight.scaffold,
      colorScheme: const ColorScheme.light(
        primary: AppColors.red,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: AppColorsLight.textPrimary,
        surface: surface,
        onSurface: AppColorsLight.textPrimary,
        error: AppColors.red,
        onError: Colors.white,
        outline: AppColorsLight.border,
      ),
      dividerColor: AppColorsLight.border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColorsLight.border),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.barlowCondensed(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.green,
        ),
        titleLarge: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.green,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: AppColorsLight.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: AppColorsLight.textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColorsLight.textPrimary,
        iconTheme: IconThemeData(color: AppColors.green),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const DvcrForwardPageTransitionsBuilder(),
          TargetPlatform.linux: const DvcrForwardPageTransitionsBuilder(),
          TargetPlatform.windows: const DvcrForwardPageTransitionsBuilder(),
          TargetPlatform.fuchsia: const DvcrForwardPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gold;
          return AppColorsLight.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.gold.withAlpha(80);
          }
          return AppColorsLight.border;
        }),
      ),
    );
  }
}