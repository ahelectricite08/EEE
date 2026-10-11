import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/sedan_squad.dart';

void main() {
  test('SedanSquadPlayer lit photoUrl depuis Firestore', () {
    final p = SedanSquadPlayer.fromMap({
      'id': 'dupont_1',
      'name': 'Dupont',
      'number': 9,
      'position': 'ATT',
      'photoUrl': 'https://example.com/dupont.jpg',
    });
    expect(p.hasPhoto, isTrue);
    expect(p.photoUrl, 'https://example.com/dupont.jpg');
    expect(p.toMap()['photoUrl'], 'https://example.com/dupont.jpg');
  });

  test('SedanSquadPlayer ignore une photo vide', () {
    final p = SedanSquadPlayer.fromMap({
      'id': 'x',
      'name': 'Sans photo',
      'photoUrl': '  ',
    });
    expect(p.hasPhoto, isFalse);
    expect(p.toMap().containsKey('photoUrl'), isFalse);
  });

  test('matchVoteLabel ignore le côté adverse', () {
    final squad = SedanSquad(players: const [
      SedanSquadPlayer(
        id: 'k',
        name: 'Koffi',
        number: 9,
        photoUrl: 'https://example.com/k.jpg',
      ),
    ]);
    expect(squad.matchVoteLabel('9 Koffi'), isNull);
    expect(squad.matchVoteLabel('9 Koffi', sedanSide: false), isNull);
  });

  test('matchVoteLabel côté Sedan : numéro, nom, photo', () {
    final squad = SedanSquad(players: const [
      SedanSquadPlayer(
        id: 'k',
        name: "N'Dri Koffi",
        number: 9,
        photoUrl: 'https://example.com/k.jpg',
      ),
    ]);
    expect(squad.matchVoteLabel('9 Koffi', sedanSide: true)?.id, 'k');
    expect(squad.matchVoteLabel("N'Dri Koffi", sedanSide: true)?.hasPhoto, isTrue);
    expect(squad.matchVoteLabel('Koffi', sedanSide: true)?.id, 'k');
    expect(
      squad.matchVoteLabel('9 Koffi', sedanSide: true, playerId: 'k')?.photoUrl,
      'https://example.com/k.jpg',
    );
  });

  test('matchLineupLabel : nom seul, accents, apostrophe', () {
    final squad = SedanSquad(players: const [
      SedanSquadPlayer(id: 'd', name: 'Jean Dupont', number: 9),
      SedanSquadPlayer(id: 'n', name: "N'Goma", number: 8),
      SedanSquadPlayer(id: 'h', name: 'Hémery', number: 7),
    ]);
    expect(squad.matchLineupLabel('Dupont')?.id, 'd');
    expect(squad.matchLineupLabel('9 Dupont')?.id, 'd');
    expect(squad.matchLineupLabel('Ngoma')?.id, 'n');
    expect(squad.matchLineupLabel('Hemery')?.id, 'h');
    expect(squad.matchLineupLabel('Dupond')?.id, 'd');
  });

  test('faceForVoteLabel repli numéro sans photo', () {
    final p = SedanSquad.empty.faceForVoteLabel('9 Dupont');
    expect(p.hasPhoto, isFalse);
    expect(p.number, 9);
    expect(p.name, 'Dupont');
  });
}
