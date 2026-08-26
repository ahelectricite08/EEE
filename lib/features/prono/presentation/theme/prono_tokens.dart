import 'package:flutter/material.dart';

import 'package:dvcr/navigation/main_shell_insets.dart';
import 'prono_theme.dart';

/// Accents fonctionnels pour icônes Prono (teintes sur fond arène).
enum PronoIconAccent {
  primary,
  matches,
  schedule,
  ranking,
  progress,
  social,
  energy,
  competitive,
}

/// Tokens Prono — palette « White Minimal Gaming », scoped au sous-arbre pronos.
abstract final class PronoTokens {
  static const Color scaffoldTop = PronoArenaTheme.scaffoldTop;
  static const Color scaffoldBottom = PronoArenaTheme.scaffoldBottom;
  static const Color surface = PronoArenaTheme.surface;
  static const Color surfaceMuted = PronoArenaTheme.surfaceMuted;
  static const Color surfaceElevated = PronoArenaTheme.surfaceElevated;
  static const Color border = PronoArenaTheme.border;
  static const Color edgeHighlight = PronoArenaTheme.edgeHighlight;
  static const Color text = PronoArenaTheme.text;
  static const Color textMuted = PronoArenaTheme.textMuted;
  static const Color textSoft = PronoArenaTheme.textSoft;
  static const Color accent = PronoArenaTheme.accent;
  static const Color accentBright = PronoArenaTheme.accentBright;
  static const Color accentDeep = PronoArenaTheme.accentDeep;
  static const Color accentGold = PronoArenaTheme.accentGold;
  static const Color danger = PronoArenaTheme.danger;
  static const Color onAccent = PronoArenaTheme.onAccent;

  /// Compat — couleur unie pour widgets qui attendent un [Color].
  static const Color scaffold = scaffoldTop;

  static const Duration animFast = PronoArenaTheme.animFast;
  static const Duration animNormal = PronoArenaTheme.animNormal;
  static const Duration animSlow = PronoArenaTheme.animSlow;
  static const Curve animCurve = PronoArenaTheme.animCurve;

  static (Color bg, Color border, Color icon) _iconTone(Color icon) {
    return (
      icon.withAlpha(16),
      Colors.transparent,
      icon,
    );
  }

  static List<Color> barStripeColors({
    required bool active,
    PronoPageAccent? pageAccent,
  }) {
    if (!active) return [border, border];
    if (pageAccent != null) {
      return [pageAccent.color, pageAccent.color];
    }
    return [edgeHighlight, edgeHighlight];
  }

  static List<Color> accentBarStripeColors(PronoIconAccent a) {
    final c = iconAccentColors(a).$3;
    return [c, c];
  }

  static List<Color> pageBarStripeColors(PronoPageAccent page) =>
      [page.color, page.color];

  /// Géométrie alignée sur le papier du journal (encre = coins vifs).
  static const double radiusLg = 16;
  static const double radiusMd = 14;
  static const double radiusSm = 8;

  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double sheetTopRadius = 20;

  static BoxDecoration scaffoldDecoration() =>
      PronoArenaTheme.scaffoldDecoration();

  static List<BoxShadow> cardShadow(BuildContext context) =>
      PronoArenaTheme.cardShadow;

  static Color cardBorderHighlight(bool prominent) =>
      prominent ? edgeHighlight : border;

  static BoxDecoration panelDecoration(
    BuildContext context, {
    double radius = radiusMd,
    bool strongGold = false,
  }) {
    return PronoArenaTheme.cardDecoration(
      radius: radius,
      highlighted: strongGold,
    );
  }

  static BoxDecoration homeOverlapSheetDecoration(BuildContext context) {
    return const BoxDecoration(
      color: scaffoldBottom,
      borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTopRadius)),
    );
  }

  static BoxDecoration tileFillDecoration({double radius = radiusMd}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: PronoArenaTheme.hairline),
    );
  }

  static (Color bg, Color border, Color icon) iconAccentColors(
    PronoIconAccent a,
  ) {
    switch (a) {
      case PronoIconAccent.primary:
        return _iconTone(PronoPageAccent.accueil.color);
      case PronoIconAccent.matches:
        return _iconTone(PronoPageAccent.matchs.color);
      case PronoIconAccent.schedule:
        return _iconTone(const Color(0xFF6B7280));
      case PronoIconAccent.ranking:
        return _iconTone(PronoPageAccent.progression.color);
      case PronoIconAccent.progress:
        return _iconTone(PronoPageAccent.progression.color);
      case PronoIconAccent.social:
        return _iconTone(PronoPageAccent.social.color);
      case PronoIconAccent.energy:
        return _iconTone(PronoPageAccent.progression.color);
      case PronoIconAccent.competitive:
        return _iconTone(danger);
    }
  }

  static BoxDecoration iconBadgeDecoration({
    required double radius,
    PronoIconAccent accent = PronoIconAccent.primary,
  }) {
    final t = iconAccentColors(accent);
    return BoxDecoration(
      color: t.$1,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static BoxDecoration iconBadgeCircleDecoration({
    PronoIconAccent accent = PronoIconAccent.primary,
  }) {
    return const BoxDecoration(
      color: surfaceMuted,
      shape: BoxShape.circle,
    );
  }

  static BoxDecoration chevronCircleDecoration() {
    return const BoxDecoration(
      color: surfaceMuted,
      shape: BoxShape.circle,
    );
  }

  /// Padding bas du scroll — barre Prono interne + nav principale via MediaQuery.
  static double bottomContentInset(BuildContext context) =>
      MainShellInsets.tabScrollTail(context, extra: 20);
}
