import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'match_detail_theme.dart';

/// Barlow Condensed (score, noms) + Inter (corps).
abstract final class MatchDetailType {
  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.85,
        height: 1.1,
        color: MatchDetailTheme.textMuted,
      );

  static TextStyle get kickerOnPhoto => kicker.copyWith(
        color: MatchDetailTheme.heroTextMuted,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: MatchDetailTheme.textMuted,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: MatchDetailTheme.textMuted,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: MatchDetailTheme.text,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: MatchDetailTheme.text,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.1,
        color: MatchDetailTheme.text,
      );

  static TextStyle get headline => GoogleFonts.barlowCondensed(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -0.2,
        color: MatchDetailTheme.text,
      );

  static TextStyle get score => GoogleFonts.barlowCondensed(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 0.92,
        letterSpacing: -1.2,
        color: MatchDetailTheme.heroText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get kickoff => GoogleFonts.barlowCondensed(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 0.92,
        letterSpacing: -0.8,
        color: MatchDetailTheme.heroText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get clubName => GoogleFonts.barlowCondensed(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.2,
        color: MatchDetailTheme.heroText,
      );

  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1,
        color: MatchDetailTheme.heroText,
      );

  static TextStyle get numeral => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.4,
        color: MatchDetailTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
