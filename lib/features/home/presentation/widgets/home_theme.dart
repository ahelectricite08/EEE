import 'package:flutter/material.dart';

import 'home_palette.dart';

/// Presse de l’accueil — même famille qu’Actus / TV / Calendrier.
/// Ivoire, filet 1 px, pas de bande saturée ni d’or cheap.
abstract final class HomeTheme {
  static const Color scaffold = homeBg;
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceMuted = homeSurfaceMuted;
  static const Color hairline = homeHairline;
  static const Color border = homeBorder;

  static const Color ink = homeInk;
  static const Color green = homeGreen;
  static const Color greenDeep = homeGreenDeep;
  static const Color greenBright = homeGreenBright;
  static const Color red = homeRed;

  static const Color text = homeText;
  static const Color textMuted = homeMutedText;

  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  static const Color accent = greenBright;

  static const double gutter = 20;
  static const double paperRadius = 6;
  static const double stripeHeight = 2;

  static BoxDecoration paper({Color? edge, double radius = paperRadius}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: edge ?? hairline, width: 1),
    );
  }

  static BoxDecoration heroAccentStripe() {
    return const BoxDecoration(color: accent);
  }
}
