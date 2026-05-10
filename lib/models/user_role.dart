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
  UserRole.partenaire,
  UserRole.donateur,
  UserRole.supporter,
];

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
      return UserRole.teamDvcr;
    case 'partenaire':
      return UserRole.partenaire;
    case 'donor': // ancien nom anglais
    case 'donateur':
      return UserRole.donateur;
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
        .map((e) => parseUserRoleFromFirestore(e.toString()))
        .toSet();
    return set.isEmpty ? {UserRole.supporter} : set;
  }
  return {parseUserRoleFromFirestore(data['role'] as String?)};
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.supporter:
        return 'Supporter';
      case UserRole.donateur:
        return 'Fidèle Supporter';
      case UserRole.partenaire:
        return 'Partenaire';
      case UserRole.teamDvcr:
        return 'Membre DVCR';
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
      case UserRole.donateur:
      case UserRole.partenaire:
      case UserRole.teamDvcr:
        return true;
      default:
        return false;
    }
  }
}
