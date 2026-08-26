import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'calendar_theme.dart';

/// Voix du calendrier — Barlow Condensed titres / chiffres, Inter corps.
abstract final class CalendarType {
  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.85,
        height: 1.1,
        color: CalendarTheme.textMuted,
      );

  static TextStyle get kickerOnPhoto => kicker.copyWith(
        color: CalendarTheme.heroTextMuted,
      );

  static TextStyle get kickerGoldPaper => kicker.copyWith(
        color: CalendarTheme.goldDeep,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: CalendarTheme.textMuted,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: CalendarTheme.textMuted,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: CalendarTheme.text,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: CalendarTheme.text,
      );

  static TextStyle get fixture => GoogleFonts.barlowCondensed(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.15,
        color: CalendarTheme.text,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.1,
        color: CalendarTheme.text,
      );

  static TextStyle get headline => GoogleFonts.barlowCondensed(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -0.2,
        color: CalendarTheme.text,
      );

  static TextStyle get display => GoogleFonts.barlowCondensed(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 0.92,
        letterSpacing: -0.4,
        color: CalendarTheme.text,
      );

  static TextStyle get masthead => GoogleFonts.barlowCondensed(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.5,
        color: CalendarTheme.heroText,
      );

  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1,
        color: CalendarTheme.heroText,
      );

  static TextStyle get numeralGutter => GoogleFonts.barlowCondensed(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.8,
        color: CalendarTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get scoreCompact => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.6,
        color: CalendarTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get stat => GoogleFonts.barlowCondensed(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -0.6,
        color: CalendarTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get rank => GoogleFonts.barlowCondensed(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.3,
        color: CalendarTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
