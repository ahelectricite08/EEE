import 'package:flutter/material.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import 'admin_palette.dart';

// ── Définition d'un onglet ────────────────────────────────────────────────────
class AdminTabDef {
  final int index;
  final IconData icon;
  final String label;
  final String permission; // RolePermissionsService.adminXxx
  final AdminUniverse universe;
  final WidgetBuilder builder; // factory lazy

  const AdminTabDef({
    required this.index,
    required this.icon,
    required this.label,
    required this.permission,
    required this.universe,
    required this.builder,
  });
}

// ── Index constants ────────────────────────────────────────────────────────────
abstract class AdminTabIndex {
  static const dashboard  = 0;
  static const direct     = 1;
  static const articles   = 2;
  static const matchs     = 3;
  static const stats      = 4;
  static const notifs     = 5;
  static const users      = 6;
  static const communaute = 7;
  static const stades     = 8;
  static const badges     = 9;
  static const xp         = 10;
  static const settings   = 11;
  static const logs       = 12;
  static const tournament = 13;
  static const matchReminder = 14;
  static const tv = 15;
  static const benevoles = 16;
  static const adherents = 17;
  static const pronos    = 18;
  static const estiDvcr  = 19;
}

// ── Univers par onglet ────────────────────────────────────────────────────────
AdminUniverse universeForTab(int tab) {
  switch (tab) {
    case AdminTabIndex.direct:
      return AdminUniverse.live;
    case AdminTabIndex.matchs:
    case AdminTabIndex.stats:
      return AdminUniverse.competition;
    case AdminTabIndex.articles:
    case AdminTabIndex.stades:
      return AdminUniverse.contenu;
    case AdminTabIndex.notifs:
      return AdminUniverse.diffusion;
    case AdminTabIndex.users:
    case AdminTabIndex.communaute:
    case AdminTabIndex.adherents:
      return AdminUniverse.communaute;
    case AdminTabIndex.pronos:
    case AdminTabIndex.estiDvcr:
      return AdminUniverse.jeux;
    case AdminTabIndex.tournament:
      return AdminUniverse.jeux;
    case AdminTabIndex.xp:
    case AdminTabIndex.settings:
    case AdminTabIndex.logs:
    case AdminTabIndex.tv:
      return AdminUniverse.system;
    default:
      return AdminUniverse.pilotage;
  }
}

// ── Calcul des indices accessibles ───────────────────────────────────────────
List<int> allowedTabIndices(
  Set<UserRole> roles,
  Map<String, List<String>> permissionsConfig,
) {
  final allowed = <int>{};
  final permissions = RolePermissionsService.permissionsForRoles(
    roles,
    permissionsConfig,
  );

  if (permissions.contains(RolePermissionsService.adminDashboard)) {
    allowed.add(AdminTabIndex.dashboard);
  }
  if (permissions.contains(RolePermissionsService.adminDirect)) {
    allowed.add(AdminTabIndex.direct);
  }
  if (permissions.contains(RolePermissionsService.adminArticles)) {
    allowed.add(AdminTabIndex.articles);
  }
  if (permissions.contains(RolePermissionsService.adminMatches)) {
    allowed.add(AdminTabIndex.matchs);
  }
  if (permissions.contains(RolePermissionsService.adminStats)) {
    allowed.add(AdminTabIndex.stats);
  }
  if (permissions.contains(RolePermissionsService.adminNotifs)) {
    allowed.add(AdminTabIndex.notifs);
  }
  if (permissions.contains(RolePermissionsService.adminUsers)) {
    allowed.add(AdminTabIndex.users);
  }
  if (permissions.contains(RolePermissionsService.adminCommunity)) {
    allowed.add(AdminTabIndex.communaute);
  }
  if (permissions.contains(RolePermissionsService.adminStades)) {
    allowed.add(AdminTabIndex.stades);
  }
  if (permissions.contains(RolePermissionsService.adminXp)) {
    allowed.add(AdminTabIndex.xp);
  }
  if (permissions.contains(RolePermissionsService.adminSettings)) {
    allowed.add(AdminTabIndex.settings);
  }
  if (permissions.contains(RolePermissionsService.adminLogs)) {
    allowed.add(AdminTabIndex.logs);
  }
  if (permissions.contains(RolePermissionsService.adminTv)) {
    allowed.add(AdminTabIndex.tv);
  }
  if (permissions.contains(RolePermissionsService.adminBenevoles)) {
    allowed.add(AdminTabIndex.benevoles);
  }
  if (permissions.contains(RolePermissionsService.adminAdherents)) {
    allowed.add(AdminTabIndex.adherents);
  }
  if (permissions.contains(RolePermissionsService.adminPronos)) {
    allowed.add(AdminTabIndex.pronos);
    allowed.add(AdminTabIndex.estiDvcr);
  }

  return (allowed.toList()..sort());
}

// ── Icône et couleur par rôle ─────────────────────────────────────────────────
IconData roleIcon(UserRole role) {
  switch (role) {
    case UserRole.admin:            return Icons.workspace_premium_rounded;
    case UserRole.communityManager: return Icons.shield_rounded;
    case UserRole.editor:           return Icons.edit_note_rounded;
    case UserRole.statisticien:     return Icons.query_stats_rounded;
    case UserRole.teamDvcr:         return Icons.bolt_rounded;
    case UserRole.partenaire:       return Icons.handshake_rounded;
    case UserRole.donateur:         return Icons.favorite_rounded;
    case UserRole.supporter:        return Icons.person_rounded;
  }
}
