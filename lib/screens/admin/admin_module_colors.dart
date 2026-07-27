import 'package:flutter/material.dart';

import 'admin_nav_model.dart';
import 'admin_palette.dart';

/// Code couleur Admin par flux / onglet — accents sobres, pas de rainbow.
///
/// 🟢 Préparation · 🔴 Direct · 🔵 Après-match · 🟣 Administration
/// + accents distincts pour jeux / communauté / pilotage.
abstract final class AdminModuleColors {
  /// Vert club — équipes, matchs, notifs, actus.
  static const Color preparation = adminGreen;

  /// Rouge LIVE — cockpit Direct.
  static const Color live = adminRed;

  /// Bleu après-match — stats, classements, finalisation.
  static const Color apresMatch = Color(0xFF2F5F9E);

  /// Violet-gris — membres, settings, logs, TV, staff.
  static const Color administration = Color(0xFF5E5478);

  /// Ambre sobre — pronos & jeux.
  static const Color jeux = Color(0xFFB0892E);

  /// Vert-teal — chat, bénévoles, adhérents.
  static const Color communaute = Color(0xFF2F7A6B);

  /// Ardoise — pilotage / dashboard.
  static const Color pilotage = Color(0xFF4A5568);

  /// Accent d’onglet (header, chips, barre latérale outils).
  static Color forTab(int tabIndex) {
    switch (tabIndex) {
      case AdminTabIndex.matchs:
      case AdminTabIndex.stades:
      case AdminTabIndex.notifs:
      case AdminTabIndex.articles:
      case AdminTabIndex.matchReminder:
        return preparation;
      case AdminTabIndex.direct:
        return live;
      case AdminTabIndex.stats:
        return apresMatch;
      case AdminTabIndex.users:
      case AdminTabIndex.staff:
      case AdminTabIndex.settings:
      case AdminTabIndex.logs:
      case AdminTabIndex.tv:
      case AdminTabIndex.xp:
      case AdminTabIndex.badges:
        return administration;
      case AdminTabIndex.pronos:
      case AdminTabIndex.estiDvcr:
      case AdminTabIndex.tournament:
        return jeux;
      case AdminTabIndex.communaute:
      case AdminTabIndex.benevoles:
      case AdminTabIndex.adherents:
        return communaute;
      case AdminTabIndex.dashboard:
      default:
        return pilotage;
    }
  }
}
