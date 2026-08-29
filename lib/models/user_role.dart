import 'package:flutter/material.dart';

/// Rôles DVCR (source unique pour toute l'app).
enum UserRole {
  supporter,
  donateur,
  partenaire,
  teamDvcr,
  editor,
  communityManager,
  statisticien,
  admin,
}

/// Priorité des rôles (du plus élevé au plus bas).
const List<UserRole> kUserRolePriority = [
  UserRole.admin,
  UserRole.communityManager,
  UserRole.editor,
  UserRole.statisticien,
  UserRole.teamDvcr,
  UserRole.supporter,
];

const List<UserRole> kStaffBadgeRoles = [
  UserRole.admin,
  UserRole.communityManager,
  UserRole.editor,
  UserRole.statisticien,
];

bool isStaffBadgeRole(UserRole role) => kStaffBadgeRoles.contains(role);

/// Homme du match bord terrain : bénévoles (`team_dvcr`) + staff Direct.
bool canSeeBenevoleProfileTools(Set<UserRole> roles) {
  return roles.contains(UserRole.teamDvcr) ||
      roles.contains(UserRole.admin) ||
      roles.contains(UserRole.communityManager) ||
      roles.contains(UserRole.statisticien);
}

/// Note du match portrait : bénévoles (`team_dvcr`).
/// Admin sans ce rôle : aperçu (comme le raccourci Espace bénévoles).
bool canSeeMatchRatingSocialPlate(Set<UserRole> roles) {
  return roles.contains(UserRole.teamDvcr) || roles.contains(UserRole.admin);
}

/// Feuille score + buteurs après fin de match : mêmes yeux que la note.
bool canSeeMatchSheetShare(Set<UserRole> roles) =>
    canSeeMatchRatingSocialPlate(roles);

/// Pilotage live profil (démarrer / score / chrono) : admin + CM.
bool canPilotLiveFromProfile(Set<UserRole> roles) {
  return roles.contains(UserRole.admin) ||
      roles.contains(UserRole.communityManager);
}

/// Saisie stats live depuis l’app : statisticien ou admin (tous les droits).
bool canEditLiveStatsFromApp(Set<UserRole> roles) {
  return roles.contains(UserRole.admin) ||
      roles.contains(UserRole.statisticien);
}

/// Lancer le vote Homme du match (même droit que Direct tapable : admin + CM).
bool canLaunchMotmVote(Set<UserRole> roles) {
  return roles.contains(UserRole.admin) ||
      roles.contains(UserRole.communityManager);
}

/// Aperçu des VOD adhérents sans flag HelloAsso (admin / CM ≠ adhérent).
bool canPreviewAdherentVod(Set<UserRole> roles) {
  return roles.contains(UserRole.admin) ||
      roles.contains(UserRole.communityManager);
}

/// Petit badge affiché chat / profil : **Team DVCR** ou **Membre** (palier standard).
UserRole memberBadgeTier(Set<UserRole> roles) {
  if (roles.contains(UserRole.teamDvcr)) return UserRole.teamDvcr;
  return UserRole.supporter;
}

/// Rôles visibles sur le profil et dans le chat (staff + un seul palier membre).
Set<UserRole> publicDisplayBadgeRoles(Set<UserRole> roles) {
  if (roles.isEmpty) return {UserRole.supporter};
  final staff = roles.where(isStaffBadgeRole).toSet();
  return {...staff, memberBadgeTier(roles)};
}

bool isDeprecatedMemberRole(UserRole role) =>
    role == UserRole.donateur || role == UserRole.partenaire;

UserRole normalizeMemberRole(UserRole role) {
  if (isDeprecatedMemberRole(role)) return UserRole.supporter;
  return role;
}

UserRole primaryUserRole(Set<UserRole> roles) {
  for (final r in kUserRolePriority) {
    if (roles.contains(r)) return r;
  }
  return UserRole.supporter;
}

UserRole parseUserRoleFromFirestore(String? roleString) {
  switch (roleString?.toLowerCase().trim()) {
    case 'admin':
      return UserRole.admin;
    case 'communitymanager':
    case 'community_manager':
      return UserRole.communityManager;
    case 'editor':
      return UserRole.editor;
    case 'statisticien':
      return UserRole.statisticien;
    case 'team_dvcr':
    case 'teamdvcr':
    case 'team dvcr':
    case 'team-dvcr':
    case 'benevole':
    case 'bénévole':
    case 'benevoles':
    case 'bénévoles':
    case 'volunteer':
      return UserRole.teamDvcr;
    case 'partenaire':
    case 'donateur':
    case 'donor':
    case 'adherent':
      return UserRole.supporter;
    case 'supporter':
    case 'free':
    case '':
    case null:
      return UserRole.supporter;
    default:
      return UserRole.supporter;
  }
}

Set<UserRole> parseUserRolesFromDoc(Map<String, dynamic>? data) {
  if (data == null) return {UserRole.supporter};
  final rolesList = data['roles'];
  if (rolesList is List && rolesList.isNotEmpty) {
    final set = rolesList
        .whereType<dynamic>()
        .map((e) => normalizeMemberRole(
              parseUserRoleFromFirestore(e.toString()),
            ))
        .toSet();
    return set.isEmpty ? {UserRole.supporter} : set;
  }
  return {normalizeMemberRole(parseUserRoleFromFirestore(data['role'] as String?))};
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.supporter:
        return 'Membre';
      case UserRole.donateur:
        return 'Membre';
      case UserRole.partenaire:
        return 'Partenaire';
      case UserRole.teamDvcr:
        return 'Team DVCR';
      case UserRole.editor:
        return 'Éditeur';
      case UserRole.communityManager:
        return 'Community Manager';
      case UserRole.statisticien:
        return 'Statisticien';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get icon {
    switch (this) {
      case UserRole.supporter:
        return '❤️';
      case UserRole.donateur:
        return '💰';
      case UserRole.partenaire:
        return '🤝';
      case UserRole.teamDvcr:
        return '⚡';
      case UserRole.editor:
        return '✏️';
      case UserRole.communityManager:
        return '🛡️';
      case UserRole.statisticien:
        return '📊';
      case UserRole.admin:
        return '👑';
    }
  }

  /// Valeur stockée dans Firestore (`users.role` / entrées de `users.roles`).
  /// (Ne pas utiliser [Enum.name] : `communityManager` ≠ `community_manager`.)
  String get firestoreRole {
    switch (this) {
      case UserRole.supporter:
        return 'supporter';
      case UserRole.donateur:
        return 'donateur';
      case UserRole.partenaire:
        return 'partenaire';
      case UserRole.teamDvcr:
        return 'team_dvcr';
      case UserRole.editor:
        return 'editor';
      case UserRole.communityManager:
        return 'community_manager';
      case UserRole.statisticien:
        return 'statisticien';
      case UserRole.admin:
        return 'admin';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.supporter:
        return const Color(0xFF9E9E9E);
      case UserRole.donateur:
        return const Color(0xFF4CAF50);
      case UserRole.partenaire:
        return const Color(0xFFFF9100);
      case UserRole.teamDvcr:
        return const Color(0xFFC8A436);
      case UserRole.editor:
        return const Color(0xFF00BCD4);
      case UserRole.communityManager:
        return const Color(0xFF2979FF);
      case UserRole.statisticien:
        return const Color(0xFF9C27B0);
      case UserRole.admin:
        return const Color(0xFFEF5350);
    }
  }

  bool get isVisible {
    switch (this) {
      case UserRole.supporter:
      case UserRole.teamDvcr:
        return true;
      default:
        return false;
    }
  }
}
