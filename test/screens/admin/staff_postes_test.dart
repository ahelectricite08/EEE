import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/screens/admin/admin_nav_model.dart';
import 'package:dvcr/screens/admin/staff_postes.dart';
import 'package:dvcr/services/role_permissions_service.dart';
import 'package:dvcr/services/user_service.dart';

void main() {
  test('commentateur is staff and lands on Direct only', () {
    expect(UserService.canAccessAdminPanel({UserRole.commentateur}), isTrue);
    expect(
      parseUserRoleFromFirestore('commentateur'),
      UserRole.commentateur,
    );
    final allowed = allowedTabIndices(
      {UserRole.commentateur},
      RolePermissionsService.defaultPermissions,
    );
    expect(allowed, contains(AdminTabIndex.direct));
    expect(allowed, isNot(contains(AdminTabIndex.reward)));
    expect(allowed, isNot(contains(AdminTabIndex.users)));
    expect(allowed, isNot(contains(AdminTabIndex.articles)));
    expect(StaffPostes.primaryOf({UserRole.commentateur})?.shortLabel, 'Com.');
  });

  test('CM has notifs and TV, not members or settings', () {
    final allowed = allowedTabIndices(
      {UserRole.communityManager},
      RolePermissionsService.defaultPermissions,
    );
    expect(allowed, contains(AdminTabIndex.notifs));
    expect(allowed, contains(AdminTabIndex.tv));
    expect(allowed, contains(AdminTabIndex.direct));
    expect(allowed, isNot(contains(AdminTabIndex.users)));
    expect(allowed, isNot(contains(AdminTabIndex.settings)));
    expect(allowed, isNot(contains(AdminTabIndex.adherents)));
  });

  test('poste catalog covers every back-office staff role', () {
    expect(
      StaffPostes.all.map((p) => p.role).toSet(),
      {
        UserRole.admin,
        UserRole.communityManager,
        UserRole.commentateur,
        UserRole.editor,
        UserRole.statisticien,
      },
    );
    expect(
      RolePermissionsService.labelOf(RolePermissionsService.adminDirect),
      contains('Direct'),
    );
  });
}
