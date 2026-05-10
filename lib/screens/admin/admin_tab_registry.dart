import 'package:flutter/material.dart';

import '../../services/role_permissions_service.dart';
import 'admin_nav_model.dart';
import 'admin_palette.dart';
import 'tabs/dashboard/dashboard_tab.dart';
import 'tabs/direct/direct_tab.dart';
import 'tabs/articles/articles_tab.dart';
import 'tabs/matchs/matchs_tab.dart';
import 'tabs/stats/stats_tab.dart';
import 'tabs/notifs/notifs_tab.dart';
import 'tabs/users/users_tab.dart';
import 'tabs/communaute/communaute_tab.dart';
import 'tabs/stades/stades_tab.dart';
import 'tabs/xp/xp_tab.dart';
import 'tabs/settings/settings_tab.dart';
import 'tabs/logs/logs_tab.dart';
import 'tabs/tournament/tournament_tab.dart';

/// Source unique des onglets admin (shell, sidebar, deep-links).
/// Ordre d’affichage aligné sur les zones de l’app (les [AdminTabIndex] restent fixes pour les URL).
final List<AdminTabDef> adminTabDefs = [
  AdminTabDef(
    index: AdminTabIndex.dashboard,
    icon: Icons.home_work_rounded,
    label: 'Pilotage',
    permission: RolePermissionsService.adminDashboard,
    universe: AdminUniverse.pilotage,
    builder: (_) => const DashboardTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.tournament,
    icon: Icons.public_rounded,
    label: 'Coupe du monde',
    permission: 'admin.tournament',
    universe: AdminUniverse.pilotage,
    builder: (_) => const TournamentTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.direct,
    icon: Icons.live_tv_rounded,
    label: 'Live',
    permission: RolePermissionsService.adminDirect,
    universe: AdminUniverse.live,
    builder: (_) => const DirectTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.matchs,
    icon: Icons.sports_soccer_rounded,
    label: 'Matchs',
    permission: RolePermissionsService.adminMatches,
    universe: AdminUniverse.live,
    builder: (_) => const MatchsTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.stats,
    icon: Icons.bar_chart_rounded,
    label: 'Stats live',
    permission: RolePermissionsService.adminStats,
    universe: AdminUniverse.live,
    builder: (_) => const StatsTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.articles,
    icon: Icons.newspaper_rounded,
    label: 'Actus',
    permission: RolePermissionsService.adminArticles,
    universe: AdminUniverse.contenu,
    builder: (_) => const ArticlesTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.stades,
    icon: Icons.stadium_rounded,
    label: 'Stades',
    permission: RolePermissionsService.adminStades,
    universe: AdminUniverse.contenu,
    builder: (_) => const StadesTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.notifs,
    icon: Icons.notifications_active_rounded,
    label: 'Notifs',
    permission: RolePermissionsService.adminNotifs,
    universe: AdminUniverse.diffusion,
    builder: (_) => const NotifsTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.users,
    icon: Icons.group_rounded,
    label: 'Membres',
    permission: RolePermissionsService.adminUsers,
    universe: AdminUniverse.communaute,
    builder: (_) => const UsersTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.communaute,
    icon: Icons.forum_rounded,
    label: 'Communauté',
    permission: RolePermissionsService.adminCommunity,
    universe: AdminUniverse.communaute,
    builder: (_) => const CommunauteTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.xp,
    icon: Icons.trending_up_rounded,
    label: 'XP prono',
    permission: RolePermissionsService.adminXp,
    universe: AdminUniverse.system,
    builder: (_) => const XpTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.settings,
    icon: Icons.tune_rounded,
    label: 'Réglages',
    permission: RolePermissionsService.adminSettings,
    universe: AdminUniverse.system,
    builder: (_) => const SettingsTab(),
  ),
  AdminTabDef(
    index: AdminTabIndex.logs,
    icon: Icons.history_rounded,
    label: 'Journal',
    permission: RolePermissionsService.adminLogs,
    universe: AdminUniverse.system,
    builder: (_) => const LogsTab(),
  ),
];
