import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Presse du calendrier club — mêmes hex / échelle que le Journal des Pronos,
/// module séparé : l’agenda n’emprunte pas les widgets prono.
abstract final class CalendarTheme {
  static const Color scaffold = Color(0xFFF4F0E6);
  static const Color surface = Color(0xFFFFFDF8);
  /// Papier CSSA : un peu plus présent que les autres, sans crème jaune.
  static const Color sedanPaper = Color(0xFFF3F5F2);
  static const Color surfaceMuted = Color(0xFFEDE7D9);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color border = Color(0xFFDDD6C6);
  static const Color edgeHighlight = Color(0xFFCFC6B4);

  static const Color ink = Color(0xFF0A1C18);
  static const Color green = AppColors.green;
  static const Color greenBright = Color(0xFF167A5F);
  static const Color gold = AppColors.gold;
  static const Color goldDeep = Color(0xFF8A6A18);
  static const Color red = AppColors.red;

  static const Color text = Color(0xFF14181A);
  static const Color textMuted = Color(0xFF5E6662);
  static const Color textSoft = Color(0xFF8A918C);

  static const Color onInk = Color(0xFFFFFFFF);
  static const Color onInkMuted = Color(0x9EFFFFFF);
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  /// Un accent par vue — le vert club, pas l’or en aplat.
  static const Color accent = greenBright;

  static const Duration animFast = Duration(milliseconds: 180);
  static const Curve animCurve = Curves.easeOutCubic;

  static const double gutter = 20;
  static const double inkRadius = 4;
  static const double paperRadius = 6;
  static const double timeGutter = 52;
  static const double fixtureGap = 12;
  static const double crestFeatured = 48;
  static const double crestRegular = 36;
  static const double crestCompact = 28;
  static const double photoBand = 112;
  static const double photoBandCompact = 56;

  static const Color podiumGold = gold;
  static const Color podiumSilver = Color(0xFF9A958B);
  static const Color podiumBronze = Color(0xFFB07A4A);

  static BoxDecoration fixtureTape() {
    return const BoxDecoration(
      color: Colors.transparent,
      border: Border(bottom: BorderSide(color: hairline, width: 1)),
    );
  }

  /// Contenant club — papier ivoire, filet 1 px, rayon sobre. Pas d’ombre Material.
  /// [sedan] : papier un peu plus présent + filet encre, jamais de bordure or.
  static BoxDecoration fixturePaper({
    Color? edge,
    bool sedan = false,
  }) {
    final Color paper = sedan ? sedanPaper : surface;
    final Color stroke = edge ?? (sedan ? ink.withValues(alpha: 0.16) : hairline);
    return BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(paperRadius),
      border: Border.all(color: stroke, width: 1),
    );
  }

  static BoxDecoration paperQuiet({double radius = 0}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline),
    );
  }

  static BoxDecoration tableHeaderPaper() {
    return const BoxDecoration(
      color: scaffold,
      border: Border(bottom: BorderSide(color: text, width: 2)),
    );
  }

  static BoxDecoration heroAccentStripe() {
    return const BoxDecoration(color: accent);
  }

  static Widget goldRule({double width = 40, double height = 3}) {
    return Container(width: width, height: height, color: gold);
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
