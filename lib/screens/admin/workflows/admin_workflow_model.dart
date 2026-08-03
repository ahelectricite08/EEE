import 'package:flutter/material.dart';

import '../admin_module_colors.dart';
import '../admin_nav_model.dart';


/// Navigation primaire Admin Phase 1 — phases match + administration.
enum AdminWorkflowId {
  preparation,
  live,
  apresMatch,
  administration,
}

/// Mode d’affichage du corps Admin.
enum AdminNavSurface {
  /// Hub d’un flux (Préparation / Après-match / Administration).
  workflowHub,

  /// Contenu d’un onglet registry (Direct cockpit, outils, deep-link…).
  tab,
}

/// Raccourci hub → onglet existant (permissions filtrées au runtime).
class AdminWorkflowShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final int tabIndex;
  final int? diffusionSubTab;

  /// Si true : reste sur le hub (ex. panneau médias Après-match).
  final bool stayOnHub;

  const AdminWorkflowShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tabIndex,
    this.diffusionSubTab,
    this.stayOnHub = false,
  });
}

class AdminWorkflowDef {
  final AdminWorkflowId id;
  final String label;
  final String shortLabel;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<AdminWorkflowShortcut> shortcuts;

  const AdminWorkflowDef({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.shortcuts,
  });

  bool get opensDirectCockpit => id == AdminWorkflowId.live;
}

/// Source unique des 4 flux (shell, sidebar, mobile, hubs).
abstract final class AdminWorkflows {
  static const List<AdminWorkflowDef> all = [
    AdminWorkflowDef(
      id: AdminWorkflowId.preparation,
      label: 'Préparation match',
      shortLabel: 'Prépa',
      subtitle: 'Équipes, calendrier, live, notifs et contenus avant le coup d’envoi.',
      color: AdminModuleColors.preparation,
      icon: Icons.event_available_rounded,
      shortcuts: [
        AdminWorkflowShortcut(
          title: 'Équipes & stades',
          subtitle: 'Vérifier logos, noms et référentiel.',
          icon: Icons.stadium_rounded,
          tabIndex: AdminTabIndex.stades,
        ),
        AdminWorkflowShortcut(
          title: 'Matchs',
          subtitle: 'Fiche, compositions, programmation.',
          icon: Icons.sports_soccer_rounded,
          tabIndex: AdminTabIndex.matchs,
        ),
        AdminWorkflowShortcut(
          title: 'Programmer le live',
          subtitle: 'Ouvrir Direct pour démarrer / configurer.',
          icon: Icons.live_tv_rounded,
          tabIndex: AdminTabIndex.direct,
        ),
        AdminWorkflowShortcut(
          title: 'Notifications',
          subtitle: 'Rappel match et push de préparation.',
          icon: Icons.send_rounded,
          tabIndex: AdminTabIndex.notifs,
          diffusionSubTab: 1,
        ),
        AdminWorkflowShortcut(
          title: 'Actus & graphismes',
          subtitle: 'Préparer une / contenus liés au match.',
          icon: Icons.newspaper_rounded,
          tabIndex: AdminTabIndex.articles,
        ),
      ],
    ),
    AdminWorkflowDef(
      id: AdminWorkflowId.live,
      label: 'Match en direct',
      shortLabel: 'Direct',
      subtitle: 'Score, chrono, buts, cartons, stats, push et modération.',
      color: AdminModuleColors.live,
      icon: Icons.sensors_rounded,
      shortcuts: [],
    ),
    AdminWorkflowDef(
      id: AdminWorkflowId.apresMatch,
      label: 'Après-match',
      shortLabel: 'Après',
      subtitle:
          'Stats finales, MOTM, médias (audio / clips), replay, publication.',
      color: AdminModuleColors.apresMatch,
      icon: Icons.flag_rounded,
      shortcuts: [
        AdminWorkflowShortcut(
          title: 'Statistiques match',
          subtitle: 'Finaliser saisie et publication.',
          icon: Icons.bar_chart_rounded,
          tabIndex: AdminTabIndex.stats,
        ),
        AdminWorkflowShortcut(
          title: 'MOTM & notes',
          subtitle: 'Votes et notes depuis Direct.',
          icon: Icons.how_to_vote_rounded,
          tabIndex: AdminTabIndex.direct,
        ),
        AdminWorkflowShortcut(
          title: 'Médias & export résumé',
          subtitle:
              'Audio, clips vMix, parole du coach, export résumé.',
          icon: Icons.movie_filter_rounded,
          tabIndex: AdminTabIndex.direct,
          stayOnHub: true,
        ),
        AdminWorkflowShortcut(
          title: 'Replay & fiche',
          subtitle: 'ID YouTube replay et faits sur la fiche match.',
          icon: Icons.sports_soccer_rounded,
          tabIndex: AdminTabIndex.matchs,
        ),
        AdminWorkflowShortcut(
          title: 'Publication actu',
          subtitle: 'Résumé / article post-match.',
          icon: Icons.newspaper_rounded,
          tabIndex: AdminTabIndex.articles,
        ),
        AdminWorkflowShortcut(
          title: 'Notifications',
          subtitle: 'Annoncer résultat ou résumé.',
          icon: Icons.send_rounded,
          tabIndex: AdminTabIndex.notifs,
        ),
      ],
    ),
    AdminWorkflowDef(
      id: AdminWorkflowId.administration,
      label: 'Administration',
      shortLabel: 'Admin',
      subtitle: 'Membres, staff, réglages, TV et journaux.',
      color: AdminModuleColors.administration,
      icon: Icons.admin_panel_settings_rounded,
      shortcuts: [
        AdminWorkflowShortcut(
          title: 'Membres',
          subtitle: 'Comptes, rôles, XP.',
          icon: Icons.group_rounded,
          tabIndex: AdminTabIndex.users,
        ),
        AdminWorkflowShortcut(
          title: 'Staff & permissions',
          subtitle: 'RBAC et badges staff.',
          icon: Icons.admin_panel_settings_rounded,
          tabIndex: AdminTabIndex.staff,
        ),
        AdminWorkflowShortcut(
          title: 'Réglages',
          subtitle: 'Saison, maintenance, home.',
          icon: Icons.tune_rounded,
          tabIndex: AdminTabIndex.settings,
        ),
        AdminWorkflowShortcut(
          title: 'Android TV',
          subtitle: 'Antenne et next live.',
          icon: Icons.tv_rounded,
          tabIndex: AdminTabIndex.tv,
        ),
        AdminWorkflowShortcut(
          title: 'Journal',
          subtitle: 'Logs d’administration.',
          icon: Icons.history_rounded,
          tabIndex: AdminTabIndex.logs,
        ),
      ],
    ),
  ];

  static AdminWorkflowDef defOf(AdminWorkflowId id) =>
      all.firstWhere((w) => w.id == id);

  static AdminWorkflowId inferFromTab(int tab) {
    switch (tab) {
      case AdminTabIndex.direct:
        return AdminWorkflowId.live;
      case AdminTabIndex.matchs:
      case AdminTabIndex.stades:
      case AdminTabIndex.notifs:
      case AdminTabIndex.articles:
        return AdminWorkflowId.preparation;
      case AdminTabIndex.stats:
        return AdminWorkflowId.apresMatch;
      case AdminTabIndex.users:
      case AdminTabIndex.staff:
      case AdminTabIndex.settings:
      case AdminTabIndex.tv:
      case AdminTabIndex.logs:
      case AdminTabIndex.xp:
        return AdminWorkflowId.administration;
      default:
        return AdminWorkflowId.administration;
    }
  }
}
