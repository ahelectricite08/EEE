import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN DESIGN TOKENS — peau club (Home / TV / Profil).
// Ivoire #F4F0E6, filet 1 px, encre, pas de cards Material grises / violet SaaS.
// ══════════════════════════════════════════════════════════════════════════════

const adminPaperRadius = 6.0;

// ── Backgrounds (Home) ────────────────────────────────────────────────────────
const adminBg          = Color(0xFFF4F0E6);
const adminSurface     = Color(0xFFEDE7D9);
const adminCard        = Color(0xFFFFFDF8);
const adminCardHigh    = Color(0xFFEDE7D9);
const adminBorder      = Color(0xFFDDD6C6);
const adminHairline    = Color(0xFFE6E0D1);
const adminBorderLight = Color(0xFFE6E0D1);

// ── Sidebar ───────────────────────────────────────────────────────────────────
const adminSidebarBg       = Color(0xFFFFFDF8);
const adminSidebarBorder   = Color(0xFFDDD6C6);
const adminSidebarHover    = Color(0xFFEDE7D9);
const adminSidebarSelected = Color(0xFFEDE7D9);
const adminSidebarMuted    = Color(0xFF5E6662);

// ── Brand club ────────────────────────────────────────────────────────────────
const adminGold        = Color(0xFFC8A436);
const adminGold2       = Color(0xFFC8A436);
const adminRed         = Color(0xFFBA203C);
const adminRedSoft     = Color(0xFF8B1729);
const adminGreen       = Color(0xFF0A4438);
const adminGreenAccent = Color(0xFF167A5F);
const adminInk         = Color(0xFF0A1C18);
/// Ancien cyan Material — désormais vert club (évite les chips cheap).
const adminBlue        = Color(0xFF167A5F);
/// Ancien violet Material — désormais vert profond.
const adminPurple      = Color(0xFF062921);
/// Ancien orange Material — or club.
const adminOrange      = Color(0xFFC8A436);

// ── Texte ─────────────────────────────────────────────────────────────────────
const adminTextPrimary = Color(0xFF14181A);
const adminGrey        = Color(0xFF5E6662);
const adminGreyLight   = Color(0xFF8A948E);

const adminOnAccent = Colors.white;

const adminGoldGradient = LinearGradient(
  colors: [Color(0xFF0A4438), Color(0xFF062921)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient adminAccentGradient(Color color) => LinearGradient(
  colors: [color.withAlpha(18), color.withAlpha(6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Filet plat — pas d’ombre SaaS.
List<BoxShadow> get adminCardShadow => const [];

List<BoxShadow> get adminShellShadow => const [];

List<BoxShadow> adminGlowShadow(Color color) => const [];

enum AdminUniverse {
  pilotage,
  matchDay,
  contenuDiffusion,
  communaute,
  jeux,
  association,
  system,
}

const List<AdminUniverse> kAdminUniverseSidebarOrder = [
  AdminUniverse.pilotage,
  AdminUniverse.contenuDiffusion,
  AdminUniverse.matchDay,
  AdminUniverse.jeux,
  AdminUniverse.communaute,
  AdminUniverse.association,
  AdminUniverse.system,
];

extension AdminUniverseX on AdminUniverse {
  String get label {
    switch (this) {
      case AdminUniverse.pilotage:
        return 'Pilotage';
      case AdminUniverse.matchDay:
        return 'Match & live';
      case AdminUniverse.contenuDiffusion:
        return 'Contenu';
      case AdminUniverse.communaute:
        return 'Communauté';
      case AdminUniverse.jeux:
        return 'Pronos';
      case AdminUniverse.association:
        return 'Association';
      case AdminUniverse.system:
        return 'Réglages';
    }
  }

  Color get color {
    switch (this) {
      case AdminUniverse.pilotage:
        return adminGreen;
      case AdminUniverse.matchDay:
        return adminRed;
      case AdminUniverse.contenuDiffusion:
        return adminGreenAccent;
      case AdminUniverse.communaute:
        return adminGreenAccent;
      case AdminUniverse.jeux:
        return adminGold;
      case AdminUniverse.association:
        return adminGreen;
      case AdminUniverse.system:
        return adminInk;
    }
  }

  IconData get icon {
    switch (this) {
      case AdminUniverse.pilotage:
        return Icons.dashboard_rounded;
      case AdminUniverse.matchDay:
        return Icons.sports_soccer_rounded;
      case AdminUniverse.contenuDiffusion:
        return Icons.layers_rounded;
      case AdminUniverse.communaute:
        return Icons.groups_rounded;
      case AdminUniverse.jeux:
        return Icons.casino_rounded;
      case AdminUniverse.association:
        return Icons.handshake_rounded;
      case AdminUniverse.system:
        return Icons.settings_rounded;
    }
  }
}

Color adminColorFromHex(String value, {Color fallback = adminGold}) {
  final clean = value.trim().replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

BoxDecoration adminCardDecoration({
  Color? color,
  Color? borderColor,
  double radius = adminPaperRadius,
  bool glow = false,
  Color glowColor = adminGold,
}) =>
    BoxDecoration(
      color: color ?? adminCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? adminHairline, width: 1),
    );

BoxDecoration adminPaper({Color? edge, double radius = adminPaperRadius}) =>
    BoxDecoration(
      color: adminCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: edge ?? adminHairline, width: 1),
    );
