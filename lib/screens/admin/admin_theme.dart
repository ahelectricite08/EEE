import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

/// Thème Material des pages admin — ivoire, filets, plus de template vert/gris.
abstract final class AdminTheme {
  static ThemeData wrap(ThemeData base) {
    final radius = BorderRadius.circular(adminPaperRadius);
    return base.copyWith(
      scaffoldBackgroundColor: adminBg,
      canvasColor: adminBg,
      cardColor: adminCard,
      dividerColor: adminHairline,
      colorScheme: const ColorScheme.light(
        primary: adminGreen,
        onPrimary: Colors.white,
        secondary: adminRed,
        onSecondary: Colors.white,
        surface: adminCard,
        onSurface: adminTextPrimary,
        error: adminRed,
        onError: Colors.white,
        outline: adminHairline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: adminBg,
        foregroundColor: adminTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: adminCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: adminHairline, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: adminSurface,
        selectedColor: adminGreen.withAlpha(22),
        disabledColor: adminSurface,
        side: const BorderSide(color: adminHairline, width: 1),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: adminTextPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: adminGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: adminGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: adminInk,
          side: const BorderSide(color: adminBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? adminGreen : adminGrey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? adminGreen.withAlpha(90)
              : adminHairline,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: adminSurface,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
        hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: adminHairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: adminHairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: adminGreen, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: adminGreen,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: adminGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: adminInk,
        textColor: adminTextPrimary,
        tileColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: adminCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: adminHairline, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: adminInk,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
