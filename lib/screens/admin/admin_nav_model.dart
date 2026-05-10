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
}

// ── Univers par onglet ────────────────────────────────────────────────────────
AdminUniverse universeForTab(int tab) {
  switch (tab) {
    case AdminTabIndex.direct:
    case AdminTabIndex.matchs:
    case AdminTabIndex.stats:
      return AdminUniverse.live;
    case AdminTabIndex.articles:
    case AdminTabIndex.stades:
      return AdminUniverse.contenu;
    case AdminTabIndex.notifs:
      return AdminUniverse.diffusion;
    case AdminTabIndex.users:
    case AdminTabIndex.communaute:
      return AdminUniverse.communaute;
    case AdminTabIndex.xp:
    case AdminTabIndex.settings:
    case AdminTabIndex.logs:
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
  if (roles.contains(UserRole.admin)) {
    allowed.add(AdminTabIndex.stades);
    allowed.add(AdminTabIndex.xp);
    allowed.add(AdminTabIndex.settings);
    allowed.add(AdminTabIndex.logs);
    allowed.add(AdminTabIndex.tournament);
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
