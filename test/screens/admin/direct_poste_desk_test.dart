import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/screens/admin/tabs/direct/direct_poste_desk.dart';

void main() {
  test('commentateur a radio et salon, pas le score', () {
    final d = DirectPosteDesk.of({UserRole.commentateur});
    expect(d.allows(DirectLivePart.radio), isTrue);
    expect(d.allows(DirectLivePart.salon), isTrue);
    expect(d.allows(DirectLivePart.emission), isTrue);
    expect(d.allows(DirectLivePart.startStop), isFalse);
    expect(d.allows(DirectLivePart.score), isFalse);
    expect(d.allows(DirectLivePart.stats), isFalse);
    expect(d.allows(DirectLivePart.votes), isFalse);
  });

  test('CM a la régie, pas le micro', () {
    final d = DirectPosteDesk.of({UserRole.communityManager});
    expect(d.allows(DirectLivePart.startStop), isTrue);
    expect(d.allows(DirectLivePart.score), isTrue);
    expect(d.allows(DirectLivePart.stories), isTrue);
    expect(d.allows(DirectLivePart.votes), isTrue);
    expect(d.allows(DirectLivePart.radio), isFalse);
    expect(d.allows(DirectLivePart.emission), isFalse);
    expect(d.allows(DirectLivePart.stats), isFalse);
  });

  test('statisticien n’a que les stats', () {
    final d = DirectPosteDesk.of({UserRole.statisticien});
    expect(d.allows(DirectLivePart.stats), isTrue);
    expect(d.allows(DirectLivePart.score), isFalse);
    expect(d.allows(DirectLivePart.radio), isFalse);
    expect(d.allows(DirectLivePart.startStop), isFalse);
    expect(d.allows(DirectLivePart.salon), isFalse);
  });

  test('admin voit tous les blocs live', () {
    final d = DirectPosteDesk.of({UserRole.admin});
    expect(d.adminView, isTrue);
    for (final part in DirectLivePart.values) {
      expect(d.allows(part), isTrue, reason: part.name);
    }
  });

  test('profil : commentateur radio sans cockpit, stats sans régie', () {
    final com = DirectPosteDesk.of({UserRole.commentateur});
    expect(com.showsProfileLivePanel, isTrue);
    expect(com.profileCanPilot, isFalse);
    expect(com.allows(DirectLivePart.radio), isTrue);

    final stats = DirectPosteDesk.of({UserRole.statisticien});
    expect(stats.showsProfileLivePanel, isTrue);
    expect(stats.profileCanPilot, isFalse);
    expect(stats.allows(DirectLivePart.stats), isTrue);
    expect(stats.allows(DirectLivePart.radio), isFalse);

    final cm = DirectPosteDesk.of({UserRole.communityManager});
    expect(cm.profileCanPilot, isTrue);
    expect(cm.allows(DirectLivePart.radio), isFalse);
    expect(cm.allows(DirectLivePart.stories), isTrue);

    final benevole = DirectPosteDesk.of({UserRole.teamDvcr});
    expect(benevole.showsProfileLivePanel, isFalse);
  });
}
