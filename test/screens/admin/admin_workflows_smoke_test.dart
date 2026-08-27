import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/souvenir_branding.dart';
import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/screens/admin/admin_nav_model.dart';
import 'package:dvcr/screens/admin/admin_palette.dart';
import 'package:dvcr/screens/admin/admin_tab_registry.dart';
import 'package:dvcr/screens/admin/workflows/admin_workflow_model.dart';
import 'package:dvcr/services/role_permissions_service.dart';
import 'package:dvcr/services/user_service.dart';

void main() {
  test('AdminWorkflows exposes 4 primary fluxes', () {
    expect(AdminWorkflows.all, hasLength(4));
    expect(
      AdminWorkflows.all.map((w) => w.id).toList(),
      [
        AdminWorkflowId.preparation,
        AdminWorkflowId.live,
        AdminWorkflowId.apresMatch,
        AdminWorkflowId.administration,
      ],
    );
  });

  test('live workflow opens Direct cockpit', () {
    expect(AdminWorkflows.defOf(AdminWorkflowId.live).opensDirectCockpit, isTrue);
    expect(
      AdminWorkflows.defOf(AdminWorkflowId.preparation).opensDirectCockpit,
      isFalse,
    );
  });

  test('hub shortcuts map to existing tab indices', () {
    final indices = <int>{};
    for (final w in AdminWorkflows.all) {
      for (final s in w.shortcuts) {
        indices.add(s.tabIndex);
      }
    }
    expect(indices, contains(AdminTabIndex.matchs));
    expect(indices, contains(AdminTabIndex.stats));
    expect(indices, contains(AdminTabIndex.users));
    expect(indices, contains(AdminTabIndex.staff));
    expect(indices, contains(AdminTabIndex.visuels));
    expect(indices, contains(AdminTabIndex.adherents));
    expect(indices, isNot(contains(AdminTabIndex.estiDvcr)));
  });

  test('team_dvcr cannot open admin tabs even if matrix grants access', () {
    final config = Map<String, List<String>>.from(
      RolePermissionsService.defaultPermissions,
    );
    config['team_dvcr'] = [
      RolePermissionsService.adminAccess,
      RolePermissionsService.adminDashboard,
      RolePermissionsService.adminArticles,
    ];
    expect(
      UserService.canAccessAdminPanel({UserRole.teamDvcr}),
      isFalse,
    );
    expect(
      allowedTabIndices({UserRole.teamDvcr}, config),
      isEmpty,
    );
  });

  test('CM keeps historical tabs and gains actus + visuels', () {
    final allowed = allowedTabIndices(
      {UserRole.communityManager},
      RolePermissionsService.defaultPermissions,
    );
    expect(allowed, contains(AdminTabIndex.dashboard));
    expect(allowed, contains(AdminTabIndex.direct));
    expect(allowed, contains(AdminTabIndex.matchs));
    expect(allowed, contains(AdminTabIndex.communaute));
    expect(allowed, contains(AdminTabIndex.pronos));
    expect(allowed, contains(AdminTabIndex.articles));
    expect(allowed, contains(AdminTabIndex.visuels));
    expect(allowed, isNot(contains(AdminTabIndex.adherents)));
    expect(allowed, isNot(contains(AdminTabIndex.settings)));
    expect(allowed, isNot(contains(AdminTabIndex.users)));
  });

  test('registry exposes visuels in Contenu', () {
    final visuels = adminTabDefs
        .where((d) => d.index == AdminTabIndex.visuels)
        .toList();
    expect(visuels, hasLength(1));
    expect(visuels.single.universe, AdminUniverse.contenuDiffusion);
  });

  test('Administration hub exposes Chat and Pronos for staff shortcuts', () {
    final titles = AdminWorkflows.defOf(AdminWorkflowId.administration)
        .shortcuts
        .map((s) => s.title)
        .toList();
    expect(titles, contains('Chat'));
    expect(titles, contains('Pronos & jeux'));
    expect(titles, contains('Photos & réseaux'));
    final photos = AdminWorkflows.defOf(AdminWorkflowId.administration)
        .shortcuts
        .where((s) => s.title == 'Photos & réseaux')
        .single;
    expect(photos.subtitle, contains('logos'));
  });

  test('CM Prépa hub keeps Matchs, Direct and Actus', () {
    final allowed = allowedTabIndices(
      {UserRole.communityManager},
      RolePermissionsService.defaultPermissions,
    ).toSet();
    final prepa = AdminWorkflows.defOf(AdminWorkflowId.preparation)
        .shortcuts
        .where((s) => allowed.contains(s.tabIndex))
        .map((s) => s.tabIndex)
        .toSet();
    expect(prepa, contains(AdminTabIndex.matchs));
    expect(prepa, contains(AdminTabIndex.direct));
    expect(prepa, contains(AdminTabIndex.articles));
    expect(prepa, isNot(contains(AdminTabIndex.stades)));
    expect(prepa, isNot(contains(AdminTabIndex.notifs)));
  });

  test('Statisticien Après hub keeps Stats and Direct lecture', () {
    final allowed = allowedTabIndices(
      {UserRole.statisticien},
      RolePermissionsService.defaultPermissions,
    ).toSet();
    final apres = AdminWorkflows.defOf(AdminWorkflowId.apresMatch)
        .shortcuts
        .where((s) => allowed.contains(s.tabIndex))
        .map((s) => s.tabIndex)
        .toSet();
    expect(apres, contains(AdminTabIndex.stats));
    expect(apres, contains(AdminTabIndex.direct));
    expect(apres, isNot(contains(AdminTabIndex.matchs)));
  });

  test('Après-match exposes médias shortcut on hub', () {
    final apres = AdminWorkflows.defOf(AdminWorkflowId.apresMatch);
    final medias = apres.shortcuts
        .where((s) => s.title == 'Médias & export résumé')
        .toList();
    expect(medias, hasLength(1));
    expect(medias.single.stayOnHub, isTrue);
    expect(medias.single.tabIndex, AdminTabIndex.direct);
  });

  test('Souvenir branding doc id is stable', () {
    expect(SouvenirBranding.firestoreDocId, 'souvenir_branding');
    expect(SouvenirBranding.storageFolder, 'match_souvenir');
    expect(SouvenirBranding.defaults.showOnFrame, isFalse);
    expect(SouvenirBranding.defaults.featureEnabled, isTrue);
    expect(
      SouvenirBranding(enabled: true, logoUrl: 'https://x.test/l.png')
          .showOnFrame,
      isTrue,
    );
    expect(
      SouvenirBranding(enabled: true, logoUrl: 'https://x.test/l.png')
          .showOnFiche,
      isTrue,
    );
    expect(
      SouvenirBranding(enabled: false, logoUrl: 'https://x.test/l.png')
          .showOnFiche,
      isFalse,
    );
    expect(
      SouvenirBranding(enabled: true, logoUrl: '').showOnFiche,
      isFalse,
    );
    expect(
      SouvenirBranding.fromMap({'enabled': true}).featureEnabled,
      isTrue,
    );
    expect(
      SouvenirBranding.fromMap({'featureEnabled': false}).featureEnabled,
      isFalse,
    );
  });

  test('inferFromTab maps Direct to live workflow', () {
    expect(
      AdminWorkflows.inferFromTab(AdminTabIndex.direct),
      AdminWorkflowId.live,
    );
    expect(
      AdminWorkflows.inferFromTab(AdminTabIndex.stats),
      AdminWorkflowId.apresMatch,
    );
  });
}
