import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Accents colorés pour les icônes Prono (reste cohérent avec vert + or DVCR).
enum PronoIconAccent {
  primary,
  matches,
  schedule,
  ranking,
  progress,
  social,
  energy,
  /// Duels & défis (rouge brique, lisible sur fond clair).
  competitive,
}

/// Tokens Prono — vert & or DVCR sur cadres ; barres et icônes reprennent des
/// **accents distincts** par section (lisibles sur fond clair, pas arc-en-ciel).
abstract final class PronoTokens {
  static const Color scaffold = AppColorsLight.scaffold;
  static const Color surface = AppColorsLight.card;
  static const Color surfaceMuted = AppColorsLight.cardMuted;
  static const Color border = AppColorsLight.border;
  static const Color text = AppColorsLight.textPrimary;
  static const Color textMuted = AppColorsLight.textSecondary;
  static const Color textSoft = AppColorsLight.textMuted;
  static const Color accent = AppColors.green;
  static const Color accentDeep = Color(0xFF062921);
  static const Color accentGold = AppColors.gold;
  static const Color danger = AppColors.red;

  // Accents secondaires (sections / icônes)
  static const Color _toneTeal = Color(0xFF0F766E);
  static const Color _toneSky = Color(0xFF2563EB);
  static const Color _toneAmber = Color(0xFFD97706);
  static const Color _toneViolet = Color(0xFF7C3AED);
  static const Color _toneSocial = Color(0xFF1E8A8A);
  static const Color _toneEmber = Color(0xFFEA580C);

  static (Color bg, Color border, Color icon) _iconTone(Color icon) {
    return (
      icon.withAlpha(28),
      icon.withAlpha(52),
      icon,
    );
  }

  /// Trait vertical / horizontal (liston) : vert → or léger quand actif.
  static List<Color> barStripeColors({required bool active}) {
    if (!active) {
      return [textSoft.withAlpha(120), surfaceMuted];
    }
    return [
      accentDeep,
      accent,
      Color.lerp(accent, accentGold, 0.42)!,
    ];
  }

  /// Barre verticale alignée sur la pastille / thème d’une tuile social.
  static List<Color> accentBarStripeColors(PronoIconAccent a) {
    final mid = iconAccentColors(a).$3;
    final deep = Color.lerp(mid, accentDeep, 0.55)!;
    final tip = Color.lerp(mid, accentGold, 0.40)!;
    return [deep, mid, tip];
  }

  static const double radiusLg = 22;
  static const double radiusMd = 16;
  static const double radiusSm = 12;

  /// Rayon du panneau qui remonte sur le hero (accueil prono).
  static const double sheetTopRadius = 28;

  /// Fond écran : crème / menthe / voile vert (plus chaud que gris uniforme).
  static BoxDecoration scaffoldDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF9F6EE),
          Color.lerp(
                const Color(0xFFF5F2E9),
                accent,
                0.045,
              ) ??
              const Color(0xFFF3F6F4),
          Color.lerp(
                const Color(0xFFECEEEA),
                accent,
                0.075,
              ) ??
              const Color(0xFFECF1EF),
        ],
        stops: const [0.0, 0.48, 1.0],
      ),
    );
  }

  /// Ombres : neutre + halo vert + touche or sur la profondeur.
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: const Color(0xFF1A2522).withAlpha(10),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: accent.withAlpha(22),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: accentGold.withAlpha(14),
          blurRadius: 22,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
      ];

  /// Bordure carte « mise en avant » (mélange discret vert + or).
  static Color cardBorderHighlight(bool prominent) {
    if (!prominent) return border.withAlpha(170);
    return Color.lerp(accent, accentGold, 0.28)!.withAlpha(105);
  }

  /// Carte / panneau type feuille Pronos (filet or modéré + ombre).
  static BoxDecoration panelDecoration(
    BuildContext context, {
    double radius = radiusMd,
    bool strongGold = false,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentGold.withAlpha(strongGold ? 115 : 72),
        width: strongGold ? 1.15 : 1,
      ),
      boxShadow: cardShadow(context),
    );
  }

  /// Feuille sous le hero (accueil) : surface blanche, relief doux.
  static BoxDecoration homeOverlapSheetDecoration(BuildContext context) {
    return BoxDecoration(
      color: surface,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(sheetTopRadius)),
      border: Border.all(color: border.withAlpha(140)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1A2522).withAlpha(12),
          blurRadius: 28,
          offset: const Offset(0, -6),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: accent.withAlpha(18),
          blurRadius: 36,
          offset: const Offset(0, 14),
          spreadRadius: -6,
        ),
      ],
    );
  }

  /// Dégradé très léger pour remplir une tuile (évite le blanc « plat »).
  static BoxDecoration tileFillDecoration({double radius = radiusMd}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface,
          Color.lerp(surface, accent, 0.035) ?? surface,
          surfaceMuted.withAlpha(215),
        ],
        stops: const [0.0, 0.55, 1.0],
      ),
    );
  }

  /// Pastilles / icônes : une teinte par intention (sport, planning, jeu…).
  static (Color bg, Color border, Color icon) iconAccentColors(
    PronoIconAccent a,
  ) {
    switch (a) {
      case PronoIconAccent.primary:
        return _iconTone(accent);
      case PronoIconAccent.matches:
        return _iconTone(_toneTeal);
      case PronoIconAccent.schedule:
        return _iconTone(_toneSky);
      case PronoIconAccent.ranking:
        return _iconTone(Color.lerp(_toneAmber, accentGold, 0.35)!);
      case PronoIconAccent.progress:
        return _iconTone(_toneViolet);
      case PronoIconAccent.social:
        return _iconTone(_toneSocial);
      case PronoIconAccent.energy:
        return _iconTone(_toneEmber);
      case PronoIconAccent.competitive:
        return (
          danger.withAlpha(30),
          danger.withAlpha(58),
          danger,
        );
    }
  }

  /// Pastille d’icône plate, teinte selon [accent].
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

  /// Cercle flèche « suite » : vert nuit + halo vert et pointe d’or.
  static BoxDecoration chevronCircleDecoration() {
    return BoxDecoration(
      color: accentDeep,
      shape: BoxShape.circle,
      border: Border.all(color: accentGold.withAlpha(100), width: 1),
      boxShadow: [
        BoxShadow(
          color: accent.withAlpha(44),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: accentGold.withAlpha(38),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Espace sous le dernier item (le corps du [Scaffold] est déjà au-dessus de la nav).
  static double bottomContentInset(BuildContext context) {
    return 20 + MediaQuery.paddingOf(context).bottom;
  }
}
