import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../services/role_permissions_service.dart';
import 'admin_nav_model.dart';
import 'admin_palette.dart';

/// Catalogue des postes staff — source unique pour le back-office.
class StaffPosteDef {
  final UserRole role;
  final String label;
  final String shortLabel;
  final String mission;
  final List<String> does;
  final List<String> defaultPermissions;
  final int landingTab;
  final Color color;
  final IconData icon;

  const StaffPosteDef({
    required this.role,
    required this.label,
    required this.shortLabel,
    required this.mission,
    required this.does,
    required this.defaultPermissions,
    required this.landingTab,
    required this.color,
    required this.icon,
  });

  String get firestoreKey => role.firestoreRole;
}

/// Pages du back-office, dans l’ordre où on les range.
abstract final class StaffPostes {
  static const List<StaffPosteDef> all = [
    StaffPosteDef(
      role: UserRole.admin,
      label: 'Admin',
      shortLabel: 'Admin',
      mission: 'Tout le back-office : membres, réglages, association, staff.',
      does: [
        'Attribue les postes et ouvre / ferme les pages',
        'Gère les membres, HelloAsso, l’app et le journal',
        'Peut tout faire à la place des autres postes',
      ],
      defaultPermissions: RolePermissionsService.allPermissions,
      landingTab: AdminTabIndex.dashboard,
      color: Color(0xFFEF5350),
      icon: Icons.workspace_premium_rounded,
    ),
    StaffPosteDef(
      role: UserRole.communityManager,
      label: 'Community Manager',
      shortLabel: 'CM',
      mission: 'Direct, contenus, chat, pronos, notifs et réseaux.',
      does: [
        'Régie live : START/STOP, score, stories, MOTM, push',
        'Matchs, actus, photos, TV, chat, pronos',
        'Ne touche pas au micro, ni aux membres / HelloAsso',
      ],
      defaultPermissions: [
        RolePermissionsService.adminAccess,
        RolePermissionsService.adminDashboard,
        RolePermissionsService.adminDirect,
        RolePermissionsService.adminMatches,
        RolePermissionsService.adminArticles,
        RolePermissionsService.adminCommunity,
        RolePermissionsService.adminPronos,
        RolePermissionsService.adminNotifs,
        RolePermissionsService.adminTv,
        RolePermissionsService.chatAccess,
        RolePermissionsService.commentsModerate,
      ],
      landingTab: AdminTabIndex.direct,
      color: Color(0xFF2979FF),
      icon: Icons.shield_rounded,
    ),
    StaffPosteDef(
      role: UserRole.commentateur,
      label: 'Commentateur',
      shortLabel: 'Com.',
      mission: 'Studio et radio du direct — pas le score ni les membres.',
      does: [
        'Micro / radio depuis le profil — pas le back-office',
        'Ne démarre pas le match et ne touche pas au score',
        'Salon live / émission si besoin, jamais le cockpit score',
      ],
      defaultPermissions: [
        RolePermissionsService.adminAccess,
        RolePermissionsService.adminDirect,
        RolePermissionsService.chatAccess,
      ],
      landingTab: AdminTabIndex.direct,
      color: Color(0xFF1565C0),
      icon: Icons.mic_rounded,
    ),
    StaffPosteDef(
      role: UserRole.editor,
      label: 'Éditeur',
      shortLabel: 'Éditeur',
      mission: 'Rédaction : articles, visuels liés aux actus.',
      does: [
        'Écrit, publie et met en avant les actus',
        'Photos & réseaux (mêmes droits visuels que les actus)',
        'Pas de live, pas de membres',
      ],
      defaultPermissions: [
        RolePermissionsService.adminAccess,
        RolePermissionsService.adminArticles,
        RolePermissionsService.chatAccess,
        RolePermissionsService.commentsModerate,
      ],
      landingTab: AdminTabIndex.articles,
      color: Color(0xFF00BCD4),
      icon: Icons.edit_note_rounded,
    ),
    StaffPosteDef(
      role: UserRole.statisticien,
      label: 'Statisticien',
      shortLabel: 'Stats',
      mission: 'Saisie et publication des stats — live en lecture.',
      does: [
        'Saisit les stats depuis le profil pendant le live',
        'Lit le score — jamais START, radio ou MOTM',
        'Pas de back-office, pas d’actus, pas de membres',
      ],
      defaultPermissions: [
        RolePermissionsService.adminAccess,
        RolePermissionsService.adminStats,
        RolePermissionsService.adminDirect,
        RolePermissionsService.chatAccess,
      ],
      landingTab: AdminTabIndex.stats,
      color: Color(0xFF9C27B0),
      icon: Icons.query_stats_rounded,
    ),
  ];

  static StaffPosteDef? ofRole(UserRole role) {
    for (final p in all) {
      if (p.role == role) return p;
    }
    return null;
  }

  static StaffPosteDef? ofKey(String firestoreKey) {
    for (final p in all) {
      if (p.firestoreKey == firestoreKey) return p;
    }
    return null;
  }

  /// Poste principal parmi les rôles staff (priorité [kUserRolePriority]).
  static StaffPosteDef? primaryOf(Set<UserRole> roles) {
    for (final r in kUserRolePriority) {
      if (!roles.contains(r)) continue;
      final p = ofRole(r);
      if (p != null) return p;
    }
    return null;
  }

  static List<int> defaultTabsFor(UserRole role) {
    final perms = ofRole(role)?.defaultPermissions ?? const <String>[];
    return allowedTabIndices(
      {role},
      {role.firestoreRole: List<String>.from(perms)},
    );
  }
}

/// Pages du back-office, triées comme la sidebar.
abstract final class AdminPageCatalog {
  static List<AdminTabDef> sorted(List<AdminTabDef> tabs) {
    final byUniverse = groupAdminTabsByUniverse(tabs);
    return [for (final g in byUniverse) ...g.$2];
  }

  static String searchBlob(AdminTabDef tab) {
    final postes = StaffPostes.all
        .where((p) => p.defaultPermissions.contains(tab.permission))
        .map((p) => '${p.label} ${p.shortLabel}')
        .join(' ');
    return '${tab.label} ${tab.universe.label} $postes ${tab.permission}'
        .toLowerCase();
  }

  static List<StaffPosteDef> postesForPermission(String permission) {
    return StaffPostes.all
        .where((p) =>
            p.role == UserRole.admin ||
            p.defaultPermissions.contains(permission))
        .toList();
  }
}
