import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Identité couleur par sous-onglet prono (wayfinding club, pas SaaS).
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
  /// Couleur principale de la page — vert / or / rouge CSSA.
  Color get color => switch (this) {
        PronoPageAccent.accueil => PronoArenaTheme.green,
        PronoPageAccent.matchs => PronoArenaTheme.greenBright,
        PronoPageAccent.progression => PronoArenaTheme.gold,
        PronoPageAccent.social => PronoArenaTheme.red,
      };

  Color get bright => switch (this) {
        PronoPageAccent.accueil => PronoArenaTheme.greenBright,
        PronoPageAccent.matchs => PronoArenaTheme.greenBright,
        PronoPageAccent.progression => PronoArenaTheme.gold,
        PronoPageAccent.social => PronoArenaTheme.red,
      };

  /// Texte / icônes sur fond [color].
  Color get onColor => switch (this) {
        PronoPageAccent.progression => PronoArenaTheme.ink,
        _ => Colors.white,
      };

  /// Encre de la page — fond des blocs « moment ».
  Color get deep => switch (this) {
        PronoPageAccent.accueil => PronoArenaTheme.ink,
        PronoPageAccent.matchs => PronoArenaTheme.ink,
        PronoPageAccent.progression => PronoArenaTheme.inkWarm,
        PronoPageAccent.social => PronoArenaTheme.inkRed,
      };

  /// Teinte papier très légère — jamais une carte pleine, juste un souffle.
  Color get wash => switch (this) {
        PronoPageAccent.accueil => const Color(0xFFEDF1EC),
        PronoPageAccent.matchs => const Color(0xFFEBF1EE),
        PronoPageAccent.progression => const Color(0xFFF5EFDF),
        PronoPageAccent.social => const Color(0xFFF6EAEA),
      };
}

/// Thème « Journal du Sanglier » — canvas ivoire DVCR, réglures, blocs d’encre.
///
/// Cinq langages de composition partagent ces tokens :
/// masthead photo · réglure (feeds) · encre (moments) · table (classements) ·
/// vestiaire (ligues / duels).
abstract final class PronoArenaTheme {
  // ── Canvas ─────────────────────────────────────────────────────────────────
  static const Color scaffoldTop = Color(0xFFF4F0E6);
  static const Color scaffoldBottom = Color(0xFFF4F0E6);

  // ── Papier ─────────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceMuted = Color(0xFFEDE7D9);
  static const Color surfaceElevated = Color(0xFFFFFDF8);

  // ── Réglures ───────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFDDD6C6);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color edgeHighlight = Color(0xFFCFC6B4);

  // ── Encre (moments) ────────────────────────────────────────────────────────
  // L'encre n'est pas le vert du club posé en aplat : c'est une encre
  // imprimée, presque noire, dans laquelle le vert ne survit qu'en sous-ton.
  // Un aplat saturé pleine largeur fait bloc plastique ; celle-ci fait matière.

  /// Vert-noir profond — fond des blocs de conséquence.
  static const Color ink = Color(0xFF0A1C18);
  static const Color inkRaised = Color(0xFF13302A);
  /// Brun-noir — versant « saison / progression ».
  static const Color inkWarm = Color(0xFF191510);
  /// Bordeaux-noir — versant « vestiaire ». Jamais le rouge d'alerte.
  static const Color inkRed = Color(0xFF2E0F16);

  // ── Verts club ─────────────────────────────────────────────────────────────
  static const Color green = AppColors.green;
  static const Color greenBright = Color(0xFF167A5F);
  static const Color gold = AppColors.gold;
  static const Color goldSoft = Color(0xFFE0C56C);
  /// Or de texte sur papier — l'or du club tombe à ~2:1 sur l'ivoire, illisible
  /// en petit corps. Réservé au TEXTE ; les filets et arêtes gardent [gold].
  static const Color goldDeep = Color(0xFF8A6A18);
  static const Color red = AppColors.red;

  // ── Texte ──────────────────────────────────────────────────────────────────
  static const Color text = Color(0xFF14181A);
  static const Color textMuted = Color(0xFF5E6662);
  static const Color textSoft = Color(0xFF8A918C);

  // ── Texte sur encre / photo ────────────────────────────────────────────────
  static const Color onInk = Color(0xFFFFFFFF);
  static const Color onInkMuted = Color(0x9EFFFFFF);
  static const Color onInkSoft = Color(0x66FFFFFF);
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextMuted = Color(0xE0FFFFFF);

  // ── Compat ─────────────────────────────────────────────────────────────────
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accent = green;
  static const Color accentBright = greenBright;
  static const Color accentDeep = ink;
  static const Color accentGold = gold;
  static const Color danger = red;

  // ── Podium ─────────────────────────────────────────────────────────────────
  static const Color podiumGold = gold;
  static const Color podiumSilver = Color(0xFF9A958B);
  static const Color podiumBronze = Color(0xFFB07A4A);

  // ── Mouvement (discret) ────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 180);
  static const Duration animNormal = Duration(milliseconds: 220);
  static const Duration animSlow = Duration(milliseconds: 280);
  static const Curve animCurve = Curves.easeOutCubic;

  // ── Géométrie ──────────────────────────────────────────────────────────────
  /// Papier : coins doux. Encre : coins vifs. Réglure : rien.
  static const double cardRadius = 14;
  static const double cardPadding = 18;
  static const double inkRadius = 4;
  static const double ticketRadius = 4;
  static const double tapeRadius = 0;
  static const double boardRadius = 0;

  /// Gouttière éditoriale — l’axe vertical de tout le module.
  static const double gutter = 20;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F06302A),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> inkShadow = [
    BoxShadow(
      color: Color(0x2606302A),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];

  static BoxDecoration scaffoldDecoration({PronoPageAccent? pageAccent}) {
    return const BoxDecoration(color: scaffoldTop);
  }

  /// Photo journalism — clair en haut, encre en bas pour asseoir le titre.
  static List<Color> heroGradientColors(PronoPageAccent page) {
    return [
      Colors.black.withValues(alpha: 0.24),
      Colors.black.withValues(alpha: 0.06),
      Colors.black.withValues(alpha: 0.90),
    ];
  }

  static BoxDecoration heroAccentStripe(PronoPageAccent page) {
    return BoxDecoration(color: page.color);
  }

  static String heroKicker(PronoPageAccent page) => switch (page) {
        PronoPageAccent.accueil => 'ARÈNE',
        PronoPageAccent.matchs => 'CALENDRIER',
        PronoPageAccent.progression => 'SAISON',
        PronoPageAccent.social => 'VESTIAIRE',
      };

  // ── Langage 1 · PAPIER ─────────────────────────────────────────────────────

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
        color: highlighted ? edgeHighlight : hairline,
        width: 1,
      ),
    );
  }

  static BoxDecoration paperQuiet({double radius = cardRadius}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline),
    );
  }

  // ── Langage 2 · RÉGLURE ────────────────────────────────────────────────────

  /// Ligne de feed — pas une carte, un filet bas.
  static BoxDecoration fixtureTape() {
    return const BoxDecoration(
      color: Colors.transparent,
      border: Border(bottom: BorderSide(color: hairline, width: 1)),
    );
  }

  // ── Langage 3 · ENCRE ──────────────────────────────────────────────────────

  /// Bloc de conséquence — jamais un aplat.
  ///
  /// Trois arrêts en diagonale : la lumière tombe en haut à gauche, l'encre
  /// se charge vers le bas à droite. C'est ce très léger volume qui sépare
  /// « matière imprimée » de « rectangle de couleur ».
  static BoxDecoration inkSlab({
    double radius = inkRadius,
    Color? tint,
    bool shadow = false,
  }) {
    final base = tint ?? ink;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, Colors.white, 0.11)!,
          base,
          Color.lerp(base, Colors.black, 0.34)!,
        ],
        stops: const [0.0, 0.48, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow ? inkShadow : null,
    );
  }

  static BoxDecoration scoreboardInk({double radius = inkRadius}) =>
      inkSlab(radius: radius);

  /// Photo de dalle admin — étape 1 : passage en monochrome assombri.
  ///
  /// L'admin peut déposer n'importe quelle image, y compris une photo de plein
  /// jour presque blanche. Plutôt que de l'écraser sous un voile quasi opaque
  /// (la photo deviendrait invisible), on la tire d'abord vers le bas : gris de
  /// luminance × [_photoLuma], donc un blanc pur plafonne à ~140/255. Le pire
  /// cas devient prévisible, et le sujet garde ses formes.
  static const double _photoLuma = 0.55;

  static const ColorFilter inkPhotoFilter = ColorFilter.matrix(<double>[
    0.2126 * _photoLuma, 0.7152 * _photoLuma, 0.0722 * _photoLuma, 0, 0,
    0.2126 * _photoLuma, 0.7152 * _photoLuma, 0.0722 * _photoLuma, 0, 0,
    0.2126 * _photoLuma, 0.7152 * _photoLuma, 0.0722 * _photoLuma, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  /// Étape 2 : le voile teinté. Monochrome + teinte = duotone de presse — la
  /// photo revient dans la famille du club (vert-noir, ou bordeaux en ligues)
  /// au lieu de tirer l'écran vers ses propres couleurs.
  ///
  /// Contraste garanti : même sur une photo blanche, le texte ivoire reste
  /// au-dessus de 6:1 au point le plus clair du dégradé.
  ///
  /// [veilBoost] assombrit le voile pour les dalles très chargées, où de petits
  /// corps et des aplats fins doivent tenir en plus des grands chiffres.
  static BoxDecoration inkPhotoVeil({Color? tint, double veilBoost = 0}) {
    final base = tint ?? ink;
    double a(double v) => (v + veilBoost).clamp(0.0, 1.0);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, Colors.white, 0.06)!.withValues(alpha: a(0.55)),
          base.withValues(alpha: a(0.64)),
          Color.lerp(base, Colors.black, 0.40)!.withValues(alpha: a(0.78)),
        ],
        stops: const [0.0, 0.48, 1.0],
      ),
    );
  }

  /// Papier + filet — remplace l'ancien billet d'encre (trop de blocs sombres).
  static BoxDecoration ticketPaper({double radius = ticketRadius}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }

  /// En-tête de table — papier, souligné d'un filet épais. L'encre est
  /// réservée à la dalle unique de l'écran.
  static BoxDecoration tableHeaderPaper() {
    return const BoxDecoration(
      color: scaffoldTop,
      border: Border(
        bottom: BorderSide(color: text, width: 2),
      ),
    );
  }

  /// Filet or fin — la signature « distinction » du module.
  static Widget goldRule({double width = 40, double height = 3}) {
    return Container(width: width, height: height, color: gold);
  }

  // ── Langage 5 · VESTIAIRE ──────────────────────────────────────────────────

  /// Salon / ligue — papier + casquette de couleur en tête.
  static BoxDecoration clubhousePanel({double radius = cardRadius}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline),
    );
  }

  // ── Styles hérités (widgets non redessinés) ────────────────────────────────

  static TextStyle sectionTitleStyle({PronoPageAccent? pageAccent}) {
    return const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: text,
      letterSpacing: 0.15,
      height: 1.1,
    );
  }

  static TextStyle scoreNumberStyle({Color? color, double size = 36}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color ?? text,
      height: 0.95,
      letterSpacing: -0.8,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ButtonStyle primaryCtaStyle({
    double verticalPadding = 15,
    double radius = 12,
    PronoPageAccent? pageAccent,
  }) {
    final fill = pageAccent?.deep ?? ink;
    final fg = pageAccent?.onColor ?? Colors.white;
    return FilledButton.styleFrom(
      backgroundColor: fill,
      foregroundColor: fg,
      disabledBackgroundColor: surfaceMuted,
      disabledForegroundColor: textSoft,
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 18),
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
          return Colors.white.withValues(alpha: 0.12);
        }
        return null;
      }),
    );
  }

  static ButtonStyle secondaryCtaStyle({
    double verticalPadding = 14,
    double radius = 12,
    PronoPageAccent? pageAccent,
  }) {
    final fg = pageAccent?.color ?? text;
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: const BorderSide(color: border),
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 16),
      backgroundColor: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static BoxDecoration primaryCtaDecoration({PronoPageAccent? pageAccent}) {
    return inkSlab(radius: 12, tint: pageAccent?.deep);
  }

  static BoxDecoration playChipDecoration({
    bool enabled = true,
    PronoPageAccent? pageAccent,
  }) {
    if (!enabled) {
      return BoxDecoration(
        color: surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      );
    }
    return BoxDecoration(
      color: pageAccent?.deep ?? ink,
      borderRadius: BorderRadius.circular(6),
    );
  }

  static BoxDecoration teamLogoRing({
    bool active = true,
    PronoPageAccent? pageAccent,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: surface,
      border: Border.all(
        color: active ? edgeHighlight : hairline,
        width: 1,
      ),
    );
  }

  static Color podiumStripeColor(int rank) => switch (rank) {
        1 => podiumGold,
        2 => podiumSilver,
        3 => podiumBronze,
        _ => Colors.transparent,
      };

  static Color podiumRankColor(int rank) => switch (rank) {
        1 => podiumGold,
        2 => podiumSilver,
        3 => podiumBronze,
        _ => textMuted,
      };

  static BoxDecoration sponsorPanelDecoration({
    double radius = cardRadius,
    PronoPageAccent? pageAccent,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline, width: 1),
      boxShadow: cardShadow,
    );
  }

  static Widget sectionAccentMark(PronoPageAccent page, {double size = 7}) {
    return Container(width: 16, height: 3, color: page.color);
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
