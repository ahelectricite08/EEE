import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/souvenir_branding.dart';
import 'package:dvcr/screens/admin/admin_nav_model.dart';
import 'package:dvcr/screens/admin/workflows/admin_workflow_model.dart';

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
    expect(indices, isNot(contains(AdminTabIndex.estiDvcr)));
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
