import 'package:flutter/material.dart';

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
      icon.withAlpha(28),
      icon.withAlpha(56),
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

  static const double radiusLg = 16;
  static const double radiusMd = 12;
  static const double radiusSm = 8;

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
    return BoxDecoration(
      color: scaffoldBottom,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(sheetTopRadius)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  static BoxDecoration tileFillDecoration({double radius = radiusMd}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
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
      border: Border.all(color: t.$2),
    );
  }

  static BoxDecoration iconBadgeCircleDecoration({
    PronoIconAccent accent = PronoIconAccent.primary,
  }) {
    final t = iconAccentColors(accent);
    return BoxDecoration(
      color: t.$1,
      shape: BoxShape.circle,
      border: Border.all(color: t.$2),
    );
  }

  static BoxDecoration chevronCircleDecoration() {
    return BoxDecoration(
      color: surfaceMuted,
      shape: BoxShape.circle,
      border: Border.all(color: border),
    );
  }

  /// Padding bas du scroll — la barre Prono est déjà hors body (Scaffold).
  static double bottomContentInset(BuildContext context) => 20;
}
