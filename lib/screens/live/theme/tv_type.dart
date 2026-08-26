import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tv_theme.dart';

/// Barlow Condensed titres / chiffres, Inter corps.
abstract final class TvType {
  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.85,
        height: 1.1,
        color: TvTheme.textMuted,
      );

  static TextStyle get kickerOnPhoto => kicker.copyWith(
        color: TvTheme.heroTextMuted,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: TvTheme.textMuted,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: TvTheme.textMuted,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.1,
        color: TvTheme.text,
      );

  static TextStyle get headline => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.02,
        letterSpacing: -0.2,
        color: TvTheme.text,
      );

  static TextStyle get masthead => GoogleFonts.barlowCondensed(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.5,
        color: TvTheme.heroText,
      );

  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1,
        color: TvTheme.heroText,
      );

  static TextStyle get section => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0.2,
        color: TvTheme.text,
      );
}
