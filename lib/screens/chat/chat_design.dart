import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Salon DVCR — même presse qu’Actus / TV / Calendrier.
///
/// Ivoire, filet 1 px, Barlow Condensed + Inter. Plaques papier
/// *translucides* posées sur la photo Communauté (Admin → Réglages →
/// Photos hero → Onglets → Communauté). Ni Discord, ni journal opaque,
/// ni fade vert de [FlexibleSpaceBar].
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

  /// Voile d’encre — juste assez pour détacher les plaques, pas un aplat.
  static const Color veilInk = Color(0x29062921);

  /// Souffle ivoire très léger — aide le texte sans tuer la photo.
  static const Color veilIvory = Color(0x2AFFFDF8);

  /// Blur ImageFiltered (pas BackdropFilter : trop lourd). Photo encore lisible.
  /// Hero quasi net ; le fil garde le flou actuel.
  static const double blurHero = 1.5;
  static const double blurFeed = 9;

  /// Chrome du salon (onglets + composer) — ivoire plein, pas un gris translu.
  static const Color chrome = ivory;

  static const double gutter = 16;
  static const double radius = 6;
  static const double radiusMd = 8;
  static const double fillet = 2;
  static const double stripe = 3;

  /// Plaque des autres — ivoire qui laisse passer la photo.
  static const Color plateOther = Color(0xB8FFFDF8);

  /// Plaque « moi » — souffle vert, même transparence.
  static const Color plateMine = Color(0xB0E6EEE8);

  /// Mention / modération — souffle or.
  static const Color plateGold = Color(0xB8F5EFDF);

  /// Onglets / typing : papier léger sur le décor.
  static const Color glassBar = Color(0x8CFFFDF8);

  /// Composer : un peu plus présent pour la saisie, la photo reste.
  static const Color glassComposer = Color(0xC6FFFDF8);

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
    return hairline;
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

  /// Nameplate dans la photo — « La commu DVCR ».
  static TextStyle get heroTitle => GoogleFonts.barlowCondensed(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.35,
        height: 1,
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
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        height: 1,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
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
