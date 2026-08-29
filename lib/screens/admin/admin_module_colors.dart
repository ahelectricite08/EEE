import 'package:flutter/material.dart';

import 'admin_nav_model.dart';
import 'admin_palette.dart';

/// Accents club — vert / rouge / or, pas de violet / cyan Material.
abstract final class AdminModuleColors {
  static const Color preparation = adminGreen;
  static const Color live = adminRed;
  static const Color apresMatch = adminGreenAccent;
  static const Color administration = adminInk;
  static const Color jeux = adminGold;
  static const Color communaute = adminGreenAccent;
  static const Color association = adminGreen;
  static const Color contenu = adminGreen;
  static const Color pilotage = adminGreen;

  /// Accent d’onglet (header, chips, barre latérale outils).
  static Color forTab(int tabIndex) {
    switch (tabIndex) {
      case AdminTabIndex.matchs:
      case AdminTabIndex.stades:
      case AdminTabIndex.matchReminder:
        return preparation;
      case AdminTabIndex.articles:
      case AdminTabIndex.tv:
      case AdminTabIndex.visuels:
        return contenu;
      case AdminTabIndex.direct:
        return live;
      case AdminTabIndex.stats:
        return apresMatch;
      case AdminTabIndex.users:
      case AdminTabIndex.staff:
      case AdminTabIndex.settings:
      case AdminTabIndex.logs:
      case AdminTabIndex.notifs:
      case AdminTabIndex.xp:
      case AdminTabIndex.badges:
        return administration;
      case AdminTabIndex.pronos:
      case AdminTabIndex.estiDvcr:
      case AdminTabIndex.tournament:
      case AdminTabIndex.reward:
        return jeux;
      case AdminTabIndex.communaute:
      case AdminTabIndex.benevoles:
        return communaute;
      case AdminTabIndex.adherents:
        return association;
      case AdminTabIndex.dashboard:
      default:
        return pilotage;
    }
  }
}
