import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Identité couleur par sous-onglet prono (wayfinding).
enum PronoPageAccent {
  accueil,
  matchs,
  progression,
  social;

  static PronoPageAccent forTabIndex(int index) => switch (index) {
        1 => PronoPageAccent.matchs,
        2 => PronoPageAccent.progression,
        _ => PronoPageAccent.accueil,
      };
}

extension PronoPageAccentX on PronoPageAccent {
  /// Couleur principale de la page.
  Color get color => switch (this) {
        // Vert institutionnel CSSA / DVCR (pas de fluo).
        PronoPageAccent.accueil => AppColors.green,
        PronoPageAccent.matchs => const Color(0xFF0284C7),
        PronoPageAccent.progression => const Color(0xFFD97706),
        PronoPageAccent.social => const Color(0xFF7C3AED),
      };

  /// Variante lumineuse (CTA, icônes actives).
  Color get bright => color;

  /// Texte / icônes sur fond [color] (contraste).
  Color get onColor => switch (this) {
        PronoPageAccent.accueil => Colors.white,
        PronoPageAccent.matchs => Colors.white,
        PronoPageAccent.progression => Colors.white,
        PronoPageAccent.social => Colors.white,
      };

  /// Variante profonde (rare — overlays neutres).
  Color get deep => switch (this) {
        PronoPageAccent.accueil => AppColors.green,
        PronoPageAccent.matchs => const Color(0xFF0369A1),
        PronoPageAccent.progression => const Color(0xFFB45309),
        PronoPageAccent.social => const Color(0xFF6D28D9),
      };
}

/// Thème « White Minimal Gaming » — fond clair, accent par page.
abstract final class PronoArenaTheme {
  // ── Shell (blanc cassé, aéré) ───────────────────────────────────────────
  static const Color scaffoldTop = Color(0xFFF8F7F4);
  static const Color scaffoldBottom = Color(0xFFFAFAFA);

  // ── Surfaces (cartes blanches) ───────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F3F5);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E8EC);
  static const Color edgeHighlight = Color(0xFFD4D4DC);

  // ── Texte ────────────────────────────────────────────────────────────────
  static const Color text = Color(0xFF1A1A1F);
  static const Color textMuted = Color(0xFF6B6B76);
  static const Color textSoft = Color(0xFF9A9AA6);

  // ── Texte sur photo hero ───────────────────────────────────────────────────
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE6FFFFFF);

  // ── Texte sur boutons accent (accents assombris → blanc) ───────────────────
  static const Color onAccent = Color(0xFFFFFFFF);

  // ── Accents globaux ────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF6B6B76);
  static const Color accentBright = Color(0xFF1A1A1F);
  static const Color accentDeep = Color(0xFF0A4438);
  static const Color accentGold = AppColors.gold;
  static const Color danger = AppColors.red;

  // ── Podium ─────────────────────────────────────────────────────────────────
  static const Color podiumGold = accentGold;
  static const Color podiumSilver = Color(0xFF9CA3AF);
  static const Color podiumBronze = Color(0xFFB87333);

  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 220);
  static const Duration animSlow = Duration(milliseconds: 250);
  static const Curve animCurve = Curves.easeOutCubic;

  static const double cardRadius = 14;
  static const double cardPadding = 20;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Fond zone prono — blanc cassé plat.
  static BoxDecoration scaffoldDecoration({PronoPageAccent? pageAccent}) {
    return const BoxDecoration(color: scaffoldTop);
  }

  /// Overlay hero — assombrissement pour lisibilité du texte blanc.
  static List<Color> heroGradientColors(PronoPageAccent page) {
    return [
      Colors.black.withValues(alpha: 0.30),
      Colors.black.withValues(alpha: 0.62),
    ];
  }

  /// Bande accent fine en haut du hero (2px, couleur page).
  static BoxDecoration heroAccentStripe(PronoPageAccent page) {
    return BoxDecoration(color: page.color);
  }

  /// Panneau de carte — blanc, bordure légère, ombre subtile.
  static BoxDecoration cardDecoration({
    double radius = cardRadius,
    Color? background,
    bool highlighted = false,
    PronoPageAccent? pageAccent,
  }) {
    return BoxDecoration(
      color: background ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: highlighted
            ? (pageAccent?.color ?? edgeHighlight).withValues(alpha: 0.45)
            : border,
        width: 1,
      ),
      boxShadow: highlighted ? const [] : cardShadow,
    );
  }

  /// Style titre de section — typographie-first.
  static TextStyle sectionTitleStyle({PronoPageAccent? pageAccent}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: text,
      letterSpacing: 0.3,
      height: 1.05,
    );
  }

  /// Style chiffres / scores — monospace condensé gaming.
  static TextStyle scoreNumberStyle({Color? color, double size = 32}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: color ?? text,
      height: 0.95,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// CTA principal — pill, remplissage accent page.
  static ButtonStyle primaryCtaStyle({
    double verticalPadding = 14,
    double radius = 99,
    PronoPageAccent? pageAccent,
  }) {
    final fill = pageAccent?.color ?? PronoPageAccent.accueil.color;
    final fg = pageAccent?.onColor ?? PronoPageAccent.accueil.onColor;
    return FilledButton.styleFrom(
      backgroundColor: fill,
      foregroundColor: fg,
      disabledBackgroundColor: surfaceMuted,
      disabledForegroundColor: textSoft,
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return surfaceMuted;
        return fill;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.black.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }

  /// Décor CTA plat (boutons custom).
  static BoxDecoration primaryCtaDecoration({PronoPageAccent? pageAccent}) {
    final fill = pageAccent?.color ?? PronoPageAccent.accueil.color;
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(99),
    );
  }

  /// Chip « PLAY » — accent page uniquement (matchs).
  static BoxDecoration playChipDecoration({
    bool enabled = true,
    PronoPageAccent? pageAccent,
  }) {
    if (!enabled) {
      return BoxDecoration(
        color: surfaceMuted,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      );
    }
    final fill = pageAccent?.color ?? PronoPageAccent.matchs.color;
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(99),
    );
  }

  /// Anneau logos d'équipe — bordure neutre.
  static BoxDecoration teamLogoRing({
    bool active = true,
    PronoPageAccent? pageAccent,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: active ? edgeHighlight : border,
        width: 1,
      ),
    );
  }

  /// Bande latérale podium (or / argent / bronze).
  static Color podiumStripeColor(int rank) {
    switch (rank) {
      case 1:
        return podiumGold;
      case 2:
        return podiumSilver;
      case 3:
        return podiumBronze;
      default:
        return Colors.transparent;
    }
  }

  static Color podiumRankColor(int rank) {
    switch (rank) {
      case 1:
        return podiumGold;
      case 2:
        return podiumSilver;
      case 3:
        return podiumBronze;
      default:
        return textMuted;
    }
  }

  /// Panneau sponsor — blanc, fine bordure accent.
  static BoxDecoration sponsorPanelDecoration({
    double radius = cardRadius,
    PronoPageAccent? pageAccent,
  }) {
    final accentColor = pageAccent?.color ?? edgeHighlight;
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentColor.withValues(alpha: 0.40),
        width: 1,
      ),
      boxShadow: cardShadow,
    );
  }

  /// Point de section en couleur page.
  static Widget sectionAccentMark(PronoPageAccent page, {double size = 6}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: page.color,
      ),
    );
  }
}

/// Alias rétrocompatible — tout le sous-arbre prono utilise l'arène.
typedef PronoTheme = PronoArenaTheme;

/// Scope : enveloppe le sous-arbre prono (shell + routes imbriquées).
class PronoThemeScope extends InheritedWidget {
  final PronoPageAccent? pageAccent;

  const PronoThemeScope({
    super.key,
    this.pageAccent,
    required super.child,
  });

  static bool isInScope(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PronoThemeScope>() !=
        null;
  }

  static PronoPageAccent? pageAccentOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PronoThemeScope>()
        ?.pageAccent;
  }

  @override
  bool updateShouldNotify(PronoThemeScope oldWidget) =>
      pageAccent != oldWidget.pageAccent;
}
