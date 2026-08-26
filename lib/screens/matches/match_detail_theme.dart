import 'package:flutter/material.dart';

/// Presse de la fiche match — même famille qu’Accueil / Calendrier / TV.
/// Ivoire, filet 1 px, pas de bande saturée ni d’or cheap.
abstract final class MatchDetailTheme {
  static const Color scaffold = Color(0xFFF4F0E6);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color sedanPaper = Color(0xFFF3F5F2);
  static const Color surfaceMuted = Color(0xFFEDE7D9);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color border = Color(0xFFDDD6C6);

  static const Color ink = Color(0xFF0A1C18);
  static const Color green = Color(0xFF0A4438);
  static const Color greenDeep = Color(0xFF062921);
  static const Color greenBright = Color(0xFF167A5F);
  static const Color red = Color(0xFFBA203C);

  static const Color text = Color(0xFF14181A);
  static const Color textMuted = Color(0xFF5E6662);
  static const Color textSoft = Color(0xFF8A918C);

  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  static const Color accent = greenBright;

  static const Color crestFill = Color(0xFFFFFFFF);
  static const Color crestStrokeCssa = Color(0xFF0B3D2E);
  static const Color crestStrokeAway = Color(0xFFCFC6B4);

  static const double gutter = 20;
  static const double crestStroke = 1;
  static const double paperRadius = 6;
  static const double crestHero = 56;
  static const double crestCard = 36;
  static const double stripeHeight = 2;

  static BoxDecoration paper({
    Color? edge,
    bool sedan = false,
    double radius = paperRadius,
  }) {
    return BoxDecoration(
      color: sedan ? sedanPaper : surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: edge ?? (sedan ? ink.withValues(alpha: 0.16) : hairline),
        width: 1,
      ),
    );
  }

  static BoxDecoration heroAccentStripe() {
    return const BoxDecoration(color: accent);
  }

  static Widget clubRule({
    double width = 22,
    double height = 1,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height,
      color: color ?? green,
    );
  }
}
