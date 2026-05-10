import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../screens/admin/admin_palette.dart';

/// Tokens Admin Center v2 — réexporte la palette admin + pont vers l’app.
abstract final class AdminThemeTokens {
  static const Color bg = adminBg;
  static const Color surface = adminSurface;
  static const Color card = adminCard;
  static const Color border = adminBorder;
  static const Color gold = adminGold;
  static const Color red = adminRed;
  static const Color textMuted = adminGrey;

  /// Rayon standard cartes / panneaux admin.
  static const double radiusMd = 12;
  static const double radiusLg = 20;

  /// Cohérence avec [AppColors] sur mobile.
  static Color get appPrimary => AppColors.red;
}
