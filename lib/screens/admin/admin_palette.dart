import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN DESIGN TOKENS — thème **clair**, aligné sur [AppColorsLight] (app DVCR).
// ══════════════════════════════════════════════════════════════════════════════

// ── Backgrounds ───────────────────────────────────────────────────────────────
const adminBg          = AppColorsLight.scaffold;
const adminSurface     = AppColorsLight.cardMuted;
const adminCard        = AppColorsLight.card;
const adminCardHigh    = AppColorsLight.cardMuted;
const adminBorder      = AppColorsLight.border;
const adminBorderLight = Color(0xFFE8E4D9);

// ── Sidebar (light shell) ─────────────────────────────────────────────────────
const adminSidebarBg       = AppColorsLight.card;
const adminSidebarBorder   = AppColorsLight.border;
const adminSidebarHover    = Color(0xFFF3F0E8);
const adminSidebarSelected = Color(0xFFFFF8E8);
const adminSidebarMuted    = AppColorsLight.textMuted;

// ── Brand ─────────────────────────────────────────────────────────────────────
const adminGold        = Color(0xFFC8A436); // or principal — identique à l'app
const adminGold2       = Color(0xFFE1C15A); // or clair pour gradients
const adminRed         = Color(0xFFBA203C); // rouge principal
const adminRedSoft     = Color(0xFF8B1729); // rouge assombri
const adminGreen       = Color(0xFF0E5A43); // vert foncé (fond badges)
const adminGreenAccent = Color(0xFF4CAF50); // vert vif (succès, victoire)
const adminBlue        = Color(0xFF00BCD4); // cyan (émissions, live)
const adminPurple      = Color(0xFF7B61FF); // violet (diffusion)
const adminOrange      = Color(0xFFFF9800); // orange (warning, upcoming)

// ── Texte ─────────────────────────────────────────────────────────────────────
const adminTextPrimary = AppColorsLight.textPrimary;
const adminGrey        = AppColorsLight.textSecondary;
const adminGreyLight   = AppColorsLight.textMuted;

/// Texte / icônes sur fonds de marque (rouge, or).
const adminOnAccent = Colors.white;

// ── Gradients prêts à l'emploi ────────────────────────────────────────────────
const adminGoldGradient = LinearGradient(
  colors: [adminGold2, adminGold],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient adminAccentGradient(Color color) => LinearGradient(
  colors: [color.withAlpha(28), color.withAlpha(10)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Shadows ───────────────────────────────────────────────────────────────────
/// Ombre unique et discrète — pas de multi-layer / glow marketing.
List<BoxShadow> get adminCardShadow => [
  BoxShadow(
    color: const Color(0xFF1A2522).withAlpha(8),
    blurRadius: 8,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> get adminShellShadow => [
  BoxShadow(
    color: const Color(0xFF1A2522).withAlpha(8),
    blurRadius: 16,
    offset: const Offset(2, 0),
  ),
];

List<BoxShadow> adminGlowShadow(Color color) => [
  BoxShadow(
    color: color.withAlpha(40),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

// ── Univers thématiques ────────────────────────────────────────────────────────
/// Six groupes sidebar (audit admin 2026).
enum AdminUniverse {
  pilotage,
  matchDay,
  contenuDiffusion,
  communaute,
  jeux,
  system,
}

extension AdminUniverseX on AdminUniverse {
  String get label {
    switch (this) {
      case AdminUniverse.pilotage:
        return 'Pilotage';
      case AdminUniverse.matchDay:
        return 'Match Day';
      case AdminUniverse.contenuDiffusion:
        return 'Contenu & Diffusion';
      case AdminUniverse.communaute:
        return 'Communauté';
      case AdminUniverse.jeux:
        return 'Jeux';
      case AdminUniverse.system:
        return 'Système';
    }
  }

  Color get color {
    switch (this) {
      case AdminUniverse.pilotage:        return adminBlue;
      case AdminUniverse.matchDay:        return adminRed;
      case AdminUniverse.contenuDiffusion: return adminPurple;
      case AdminUniverse.communaute:      return adminGreenAccent;
      case AdminUniverse.jeux:            return const Color(0xFFE8A317);
      case AdminUniverse.system:          return adminOrange;
    }
  }

  IconData get icon {
    switch (this) {
      case AdminUniverse.pilotage:        return Icons.dashboard_rounded;
      case AdminUniverse.matchDay:        return Icons.sports_soccer_rounded;
      case AdminUniverse.contenuDiffusion: return Icons.layers_rounded;
      case AdminUniverse.communaute:      return Icons.groups_rounded;
      case AdminUniverse.jeux:            return Icons.casino_rounded;
      case AdminUniverse.system:          return Icons.settings_rounded;
    }
  }
}

// ── Utilitaire couleur hex ─────────────────────────────────────────────────────
Color adminColorFromHex(String value, {Color fallback = adminGold}) {
  final clean = value.trim().replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

// ── Box decorations réutilisables ─────────────────────────────────────────────
BoxDecoration adminCardDecoration({
  Color? color,
  Color? borderColor,
  double radius = 14,
  bool glow = false,
  Color glowColor = adminGold,
}) =>
    BoxDecoration(
      color: color ?? adminCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? adminBorder),
      boxShadow: glow ? adminGlowShadow(glowColor) : adminCardShadow,
    );
