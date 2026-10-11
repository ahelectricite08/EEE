import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/official_sedan_lineup_draft.dart';
import 'package:dvcr/models/sedan_squad.dart';

SedanSquad _squad() => SedanSquad(
      players: [
        for (var i = 0; i < 20; i++)
          SedanSquadPlayer(
            id: 'p$i',
            name: 'Joueur$i',
            number: i + 1,
            position: i == 0
                ? 'GB'
                : i < 5
                    ? 'DEF'
                    : i < 10
                        ? 'MIL'
                        : 'ATT',
          ),
      ],
    );

void main() {
  test('phase XI jusqu’à 11, puis banc automatique', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft();
    for (var i = 0; i < 11; i++) {
      expect(d.phase, OfficialSedanLineupPhase.xi);
      expect(d.tapPlayer(squad.players[i]), isTrue);
    }
    expect(d.phase, OfficialSedanLineupPhase.bench);
    expect(d.starterIds.length, 11);
    expect(d.tapPlayer(squad.players[11]), isTrue);
    expect(d.benchIds, ['p11']);
  });

  test('plafond banc = 7 (slots éditeur historique)', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft(
      starterIds: [for (var i = 0; i < 11; i++) 'p$i'],
    );
    expect(d.phase, OfficialSedanLineupPhase.bench);
    for (var i = 11; i < 20; i++) {
      d.tapPlayer(squad.players[i]);
    }
    expect(d.benchIds.length, OfficialSedanLineupDraft.benchMax);
    expect(d.benchFull, isTrue);
  });

  test('retirer un titulaire ramène à Compose le XI', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft(
      starterIds: [for (var i = 0; i < 11; i++) 'p$i'],
      benchIds: ['p11'],
    );
    expect(d.phase, OfficialSedanLineupPhase.bench);
    d.tapPlayer(squad.players[0]);
    expect(d.phase, OfficialSedanLineupPhase.xi);
    expect(d.starterIds.length, 10);
    expect(d.benchIds, ['p11']);
  });

  test('en phase XI, un remplaçant est promu titulaire', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft(
      starterIds: [for (var i = 0; i < 10; i++) 'p$i'],
      benchIds: ['p15'],
    );
    expect(d.phase, OfficialSedanLineupPhase.xi);
    d.tapPlayer(squad.players[15]);
    expect(d.starterIds.contains('p15'), isTrue);
    expect(d.benchIds, isEmpty);
  });

  test('export titulaires trié GB → DEF → MIL → ATT', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft();
    d.tapPlayer(squad.players[12]); // ATT
    d.tapPlayer(squad.players[0]); // GB
    d.tapPlayer(squad.players[6]); // MIL
    expect(
      d.starterLineupNames(squad),
      ['1 Joueur0', '7 Joueur6', '13 Joueur12'],
    );
  });

  test('hydrate depuis les libellés compo (numéro + nom)', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft.fromNames(
      squad: squad,
      starters: ['1 Joueur0', 'Ghost', '2 Joueur1'],
      substitutes: ['12 Joueur11', 'Inconnu'],
    );
    expect(d.starterIds, ['p0', 'p1']);
    expect(d.unmatchedStarters, ['Ghost']);
    expect(d.benchIds, ['p11']);
    expect(d.unmatchedBench, ['Inconnu']);
  });

  test('tap d’un titulaire le retire, second tap d’un banc le retire', () {
    final squad = _squad();
    final d = OfficialSedanLineupDraft(
      starterIds: [for (var i = 0; i < 11; i++) 'p$i'],
      benchIds: ['p12'],
    );
    d.tapPlayer(squad.players[12]);
    expect(d.benchIds, isEmpty);
    d.tapPlayer(squad.players[12]);
    expect(d.benchIds, ['p12']);
  });
}
