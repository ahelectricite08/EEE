import '../../../models/user_role.dart';
import '../../../services/role_permissions_service.dart';

/// RBAC Admin Center — un seul niveau **plein pouvoir** : [UserRole.admin].
/// **Statisticien** et **CM / editor** : périmètres restreints (UI via
/// [RolePermissionsService] + données via [firestore.rules]).
abstract final class AdminRbac {
  /// Accès total au panel et aux collections réservées admin-only.
  static bool isFullAdmin(Set<UserRole> roles) => roles.contains(UserRole.admin);

  /// Staff pouvant accéder à l’UI admin (onglets filtrés par permissions).
  static bool hasAdminUiAccess(Set<UserRole> roles, Map<String, List<String>>? config) {
    return RolePermissionsService.hasPermission(
      roles,
      RolePermissionsService.adminAccess,
      config,
    );
  }

  /// Peut éditer contenu éditorial (articles, vidéos) — aligné règles Firestore.
  static bool canEditEditorialContent(Set<UserRole> roles) {
    return isFullAdmin(roles) ||
        roles.contains(UserRole.editor) ||
        roles.contains(UserRole.communityManager);
  }

  /// Peut édifier données matchs / live opérationnel — admin, CM, stats.
  static bool canEditMatchOperations(Set<UserRole> roles) {
    return isFullAdmin(roles) ||
        roles.contains(UserRole.communityManager) ||
        roles.contains(UserRole.statisticien);
  }
}
