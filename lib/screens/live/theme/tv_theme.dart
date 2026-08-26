import 'package:flutter/material.dart';

/// Presse DVCR TV — même famille qu’Actus / Calendrier.
/// Ivoire, filet 1 px, pas de bande saturée ni d’or cheap.
abstract final class TvTheme {
  static const Color scaffold = Color(0xFFF4F0E6);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceMuted = Color(0xFFEDE7D9);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color border = Color(0xFFDDD6C6);

  static const Color ink = Color(0xFF0A1C18);
  static const Color green = Color(0xFF0A4438);
  static const Color greenDeep = Color(0xFF062921);
  static const Color greenBright = Color(0xFF167A5F);
  static const Color gold = Color(0xFFC8A436);
  static const Color goldDeep = Color(0xFF8A6A18);
  static const Color red = Color(0xFFBA203C);

  static const Color text = Color(0xFF14181A);
  static const Color textMuted = Color(0xFF5E6662);
  static const Color textSoft = Color(0xFF8A918C);

  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  static const Color accent = greenBright;

  static const double gutter = 20;
  static const double paperRadius = 6;

  static BoxDecoration paper({Color? edge}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(paperRadius),
      border: Border.all(color: edge ?? hairline, width: 1),
    );
  }

  static BoxDecoration heroAccentStripe() {
    return const BoxDecoration(color: accent);
  }
}
