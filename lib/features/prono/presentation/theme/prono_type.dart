import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'prono_theme.dart';

/// Échelle typo Pronos — une voix par rôle, pas du Barlow 20 partout.
abstract final class PronoType {
  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.85,
        height: 1.1,
        color: PronoArenaTheme.textMuted,
      );

  static TextStyle get kickerOnInk => kicker.copyWith(
        color: PronoArenaTheme.onInkMuted,
      );

  /// Or sur ENCRE uniquement.
  static TextStyle get kickerGold => kicker.copyWith(
        color: PronoArenaTheme.gold,
      );

  /// Or sur PAPIER — même rôle, teinte assombrie pour rester lisible sur ivoire.
  static TextStyle get kickerGoldPaper => kicker.copyWith(
        color: PronoArenaTheme.goldDeep,
      );

  static TextStyle get kickerOnPhoto => kicker.copyWith(
        color: PronoArenaTheme.heroTextMuted,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: PronoArenaTheme.textMuted,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: PronoArenaTheme.textMuted,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: PronoArenaTheme.text,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: PronoArenaTheme.text,
      );

  static TextStyle get fixture => GoogleFonts.barlowCondensed(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.15,
        color: PronoArenaTheme.text,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.1,
        color: PronoArenaTheme.text,
      );

  static TextStyle get headline => GoogleFonts.barlowCondensed(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -0.2,
        color: PronoArenaTheme.text,
      );

  static TextStyle get display => GoogleFonts.barlowCondensed(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 0.92,
        letterSpacing: -0.4,
        color: PronoArenaTheme.text,
      );

  static TextStyle get masthead => GoogleFonts.barlowCondensed(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.5,
        color: PronoArenaTheme.heroText,
      );

  static TextStyle get score => GoogleFonts.barlowCondensed(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -1.4,
        color: Colors.white,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get scoreCompact => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.6,
        color: PronoArenaTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get stat => GoogleFonts.barlowCondensed(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -0.6,
        color: PronoArenaTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get rank => GoogleFonts.barlowCondensed(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.3,
        color: PronoArenaTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get cta => GoogleFonts.barlowCondensed(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        height: 1,
        color: Colors.white,
      );

  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1,
        color: PronoArenaTheme.heroText,
      );

  /// Chiffre de scène — le score qu’on pose sur le tableau d’affichage.
  static TextStyle get numeralStage => GoogleFonts.barlowCondensed(
        fontSize: 88,
        fontWeight: FontWeight.w800,
        height: 0.82,
        letterSpacing: -3,
        color: Colors.white,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Grand chiffre de gouttière (jour du calendrier, index d’annuaire).
  static TextStyle get numeralGutter => GoogleFonts.barlowCondensed(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.8,
        color: PronoArenaTheme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Code de salon / invitation — lettres espacées, lisibles à l’oral.
  static TextStyle get codeStamp => GoogleFonts.barlowCondensed(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 6,
        color: Colors.white,
      );
}
