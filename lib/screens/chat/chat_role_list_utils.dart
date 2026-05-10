import '../../models/user_role.dart';

/// Trie les rôles selon la priorité DVCR (affichage badges chat).
void sortRolesByPriority(List<UserRole> roles) {
  roles.sort((a, b) {
    final ia = kUserRolePriority.indexOf(a);
    final ib = kUserRolePriority.indexOf(b);
    return ia.compareTo(ib);
  });
}
