import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Salon DVCR — tribune en tête, fil sur papier.
///
/// Même presse qu’Actus / Calendrier / Pronos : ivoire, filet 1 px,
/// Barlow Condensed + Inter. La photo Communauté reste le masthead,
/// plus le papier peint du fil (illisibilité, flou, plaques translucides).
abstract final class ChatDesign {
  static const Color ivory = Color(0xFFF4F0E6);
  static const Color paper = Color(0xFFFFFDF8);
  static const Color ink = Color(0xFF0A1C18);
  static const Color green = Color(0xFF0A4438);
  static const Color greenDeep = Color(0xFF062921);
  static const Color accent = Color(0xFF167A5F);
  static const Color gold = Color(0xFFC8A436);
  static const Color goldDeep = Color(0xFF8A6A18);
  static const Color red = Color(0xFFBA203C);
  static const Color text = Color(0xFF14181A);
  static const Color muted = Color(0xFF5E6662);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color border = Color(0xFFDDD6C6);
  static const Color heroUnder = Color(0xFF151515);
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  static const Color chrome = ivory;
  static const Color feed = ivory;

  static const double gutter = 16;
  static const double radius = 2;
  static const double radiusMd = 4;
  static const double fillet = 3;
  static const double stripe = 3;

  /// Plaque des autres — papier opaque.
  static const Color plateOther = paper;

  /// Plaque « moi » — souffle vert club, toujours opaque.
  static const Color plateMine = Color(0xFFE8EFEA);

  /// Mention / modération — souffle or.
  static const Color plateGold = Color(0xFFF5EFDF);

  static Color plateFill({
    required bool mine,
    bool mention = false,
    bool moderation = false,
  }) {
    if (moderation || mention) return plateGold;
    if (mine) return plateMine;
    return plateOther;
  }

  static Color plateAccent({
    required bool mine,
    bool mention = false,
    bool moderation = false,
  }) {
    if (moderation || mention) return gold;
    if (mine) return green;
    return accent;
  }

  static BoxDecoration plateBox({
    required bool mine,
    bool mention = false,
    bool moderation = false,
  }) {
    return BoxDecoration(
      color: plateFill(mine: mine, mention: mention, moderation: moderation),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline, width: 1),
    );
  }

  static TextStyle get kickerOnPhoto => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        height: 1,
        color: heroTextMuted,
      );

  static TextStyle get masthead => GoogleFonts.barlowCondensed(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 0.9,
        letterSpacing: -0.5,
        color: heroText,
      );

  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1,
        color: heroText,
      );

  static TextStyle get heroTitle => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 0.95,
        color: heroText,
      );

  static TextStyle get subtitleOnPhoto => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: heroTextMuted,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.1,
        color: text,
      );

  static TextStyle get tab => GoogleFonts.barlowCondensed(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        height: 1,
      );

  static TextStyle get byline => GoogleFonts.barlowCondensed(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 1,
        color: text,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: text,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: muted,
      );
}
