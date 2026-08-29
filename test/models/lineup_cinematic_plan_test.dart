import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/lineup_cinematic_plan.dart';
import 'package:dvcr/models/match_lineup.dart';
import 'package:dvcr/models/sedan_squad.dart';

void main() {
  test('5-3-2 ne devient pas un 4-3-3 : lignes 5 / 3 / 2 après le gardien', () {
    const side = MatchLineupSide(
      formation: '5-3-2',
      starters: [
        '1 Gardien',
        '2 D1',
        '3 D2',
        '4 D3',
        '5 D4',
        '6 D5',
        '7 M1',
        '8 M2',
        '10 M3',
        '9 A1',
        '11 A2',
      ],
      substitutes: ['12 Banc', '16 Remp'],
    );

    final plan = LineupCinematicTeamPlan.fromSide(
      side: side,
      teamName: 'Sedan',
      isSedan: true,
    );

    expect(plan.keepers.players.single.name, 'Gardien');
    expect(plan.outfieldLines.map((l) => l.label).toList(), [
      'DÉFENSE',
      'MILIEU',
      'ATTAQUE',
    ]);
    expect(plan.outfieldLines[0].players.length, 5);
    expect(plan.outfieldLines[1].players.length, 3);
    expect(plan.outfieldLines[2].players.length, 2);
    expect(plan.substitutes.players.length, 2);
  });

  test('4-2-3-1 produit quatre lignes de champ', () {
    const side = MatchLineupSide(
      formation: '4-2-3-1',
      starters: [
        '1 G',
        '2 a',
        '3 b',
        '4 c',
        '5 d',
        '6 e',
        '8 f',
        '7 g',
        '10 h',
        '11 i',
        '9 j',
      ],
    );
    final plan = LineupCinematicTeamPlan.fromSide(
      side: side,
      teamName: 'CSSA',
      isSedan: true,
    );
    expect(plan.outfieldLines.map((l) => l.players.length).toList(), [4, 2, 3, 1]);
    expect(plan.outfieldLines.last.label, 'ATTAQUE');
  });

  test('formation 1-4-3-3 : le 1 compte comme gardien', () {
    const side = MatchLineupSide(
      formation: '1-4-3-3',
      starters: [
        '1 G',
        '2 a',
        '3 b',
        '4 c',
        '5 d',
        '6 e',
        '8 f',
        '10 g',
        '7 h',
        '11 i',
        '9 j',
      ],
    );
    final plan = LineupCinematicTeamPlan.fromSide(
      side: side,
      teamName: 'CSSA',
      isSedan: true,
    );
    expect(plan.keepers.players.length, 1);
    expect(plan.outfieldLines.map((l) => l.players.length).toList(), [4, 3, 3]);
  });

  test('Sedan : ordre GB puis lignes via effectif, pas un schéma inventé', () {
    const squad = SedanSquad(
      players: [
        SedanSquadPlayer(id: 'g', name: 'Gros', number: 1, position: 'GB'),
        SedanSquadPlayer(id: 'd', name: 'Def', number: 4, position: 'DEF'),
        SedanSquadPlayer(id: 'm', name: 'Mil', number: 8, position: 'MIL'),
        SedanSquadPlayer(id: 'a', name: 'Att', number: 9, position: 'ATT'),
      ],
    );
    const side = MatchLineupSide(
      formation: '1-1-1',
      starters: ['9 Att', '8 Mil', '4 Def', '1 Gros'],
    );
    final plan = LineupCinematicTeamPlan.fromSide(
      side: side,
      teamName: 'Sedan',
      isSedan: true,
      sedanSquad: squad,
    );
    expect(plan.keepers.players.single.name, 'Gros');
    expect(plan.outfieldLines[0].players.single.name, 'Def');
    expect(plan.outfieldLines[1].players.single.name, 'Mil');
    expect(plan.outfieldLines[2].players.single.name, 'Att');
  });

  test('TEST : XI aléatoire CSSA + adversaire, 11 titulaires', () {
    const squad = SedanSquad(
      players: [
        SedanSquadPlayer(id: 'g1', name: 'Gros', number: 1, position: 'GB'),
        SedanSquadPlayer(id: 'g2', name: 'RempGb', number: 16, position: 'GB'),
        SedanSquadPlayer(id: 'd1', name: 'Def1', number: 2, position: 'DEF'),
        SedanSquadPlayer(id: 'd2', name: 'Def2', number: 3, position: 'DEF'),
        SedanSquadPlayer(id: 'd3', name: 'Def3', number: 4, position: 'DEF'),
        SedanSquadPlayer(id: 'd4', name: 'Def4', number: 5, position: 'DEF'),
        SedanSquadPlayer(id: 'd5', name: 'Def5', number: 12, position: 'DEF'),
        SedanSquadPlayer(id: 'm1', name: 'Mil1', number: 6, position: 'MIL'),
        SedanSquadPlayer(id: 'm2', name: 'Mil2', number: 8, position: 'MIL'),
        SedanSquadPlayer(id: 'm3', name: 'Mil3', number: 10, position: 'MIL'),
        SedanSquadPlayer(id: 'm4', name: 'Mil4', number: 14, position: 'MIL'),
        SedanSquadPlayer(id: 'a1', name: 'Att1', number: 7, position: 'ATT'),
        SedanSquadPlayer(id: 'a2', name: 'Att2', number: 9, position: 'ATT'),
        SedanSquadPlayer(id: 'a3', name: 'Att3', number: 11, position: 'ATT'),
        SedanSquadPlayer(id: 'a4', name: 'Att4', number: 17, position: 'ATT'),
      ],
    );
    final a = LineupCinematicShow.randomTest(
      squad: squad,
      random: Random(42),
    );
    final b = LineupCinematicShow.randomTest(
      squad: squad,
      random: Random(7),
    );
    expect(a.force, isTrue);
    expect(a.sedan.keepers.players, isNotEmpty);
    expect(
      a.sedan.keepers.players.length +
          a.sedan.outfieldLines.fold<int>(
            0,
            (n, l) => n + l.players.length,
          ),
      11,
    );
    expect(a.opponent, isNotNull);
    expect(
      a.opponent!.keepers.players.length +
          a.opponent!.outfieldLines.fold<int>(
            0,
            (n, l) => n + l.players.length,
          ),
      11,
    );
    expect(a.sedan.substitutes.players, isNotEmpty);
    final namesA = a.sedan.keepers.players.map((p) => p.name).join('|');
    final namesB = b.sedan.keepers.players.map((p) => p.name).join('|');
    final fieldA = a.sedan.outfieldLines
        .expand((l) => l.players)
        .map((p) => p.name)
        .join('|');
    final fieldB = b.sedan.outfieldLines
        .expand((l) => l.players)
        .map((p) => p.name)
        .join('|');
    expect('$namesA|$fieldA', isNot('$namesB|$fieldB'));
    expect(a.sedan.keepers.players.single.name, anyOf('Gros', 'RempGb'));
  });

  test('TEST sans effectif : fallback 11 + 11', () {
    final show = LineupCinematicShow.randomTest(random: Random(1));
    expect(
      show.sedan.keepers.players.length +
          show.sedan.outfieldLines.fold<int>(
            0,
            (n, l) => n + l.players.length,
          ),
      11,
    );
    expect(show.opponent!.hasContent, isTrue);
  });

  test('playKey : match + timestamp d’annonce, pas de fenêtre 5 min', () {
    final saved = DateTime(2026, 8, 28, 14, 0);
    expect(
      LineupCinematicWindow.playKey('m1', saved),
      'm1_${saved.millisecondsSinceEpoch ~/ 1000}',
    );
    expect(
      LineupCinematicWindow.playKey('m1', saved.add(const Duration(seconds: 2))),
      isNot(LineupCinematicWindow.playKey('m1', saved)),
    );
  });

  test('auto-play : live + XI annoncé + jamais vu ; jamais si live coupé', () {
    final announced = DateTime(2026, 8, 28, 14, 0);
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: true,
        liveRunning: true,
        alreadyPlayed: false,
        lineupAnnouncedAt: announced,
      ),
      isTrue,
    );
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: true,
        liveRunning: true,
        alreadyPlayed: false,
        lineupAnnouncedAt: announced.add(const Duration(hours: 3)),
      ),
      isTrue,
    );
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: true,
        liveRunning: false,
        alreadyPlayed: false,
        lineupAnnouncedAt: announced,
      ),
      isFalse,
    );
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: true,
        liveRunning: true,
        alreadyPlayed: true,
        lineupAnnouncedAt: announced,
      ),
      isFalse,
    );
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: true,
        liveRunning: true,
        alreadyPlayed: false,
        lineupAnnouncedAt: null,
      ),
      isFalse,
    );
    expect(
      LineupCinematicGate.shouldPlay(
        flagOn: false,
        liveRunning: true,
        alreadyPlayed: false,
        lineupAnnouncedAt: announced,
      ),
      isFalse,
    );
  });

  test('splash adhésion : bloqué tant que XI resolving/playing', () {
    expect(
      LineupCinematicSplashHold.blocksAdhesionSplash(
        LineupCinematicOccupancy.resolving,
      ),
      isTrue,
    );
    expect(
      LineupCinematicSplashHold.blocksAdhesionSplash(
        LineupCinematicOccupancy.playing,
      ),
      isTrue,
    );
    expect(
      LineupCinematicSplashHold.blocksAdhesionSplash(
        LineupCinematicOccupancy.idle,
      ),
      isFalse,
    );
    expect(
      LineupCinematicSplashHold.afterEvaluate(overlayPlaying: true),
      LineupCinematicOccupancy.playing,
    );
    expect(
      LineupCinematicSplashHold.afterEvaluate(overlayPlaying: false),
      LineupCinematicOccupancy.idle,
    );
    expect(
      LineupCinematicSplashHold.afterEvaluate(
        overlayPlaying: false,
        launchInputsReady: false,
      ),
      LineupCinematicOccupancy.resolving,
    );
    expect(
      LineupCinematicSplashHold.afterEvaluate(
        overlayPlaying: true,
        launchInputsReady: false,
      ),
      LineupCinematicOccupancy.playing,
    );
  });

  test('Séquence Sedan puis adversaire, remplaçants en dernier par équipe', () {
    const sedan = MatchLineupSide(
      formation: '4-3-3',
      starters: [
        '1 G',
        '2 a',
        '3 b',
        '4 c',
        '5 d',
        '6 e',
        '8 f',
        '10 g',
        '7 h',
        '11 i',
        '9 j',
      ],
      substitutes: ['12 Banc'],
    );
    const opp = MatchLineupSide(
      formation: '5-3-2',
      starters: [
        '1 Og',
        '2 oa',
        '3 ob',
        '4 oc',
        '5 od',
        '6 oe',
        '7 of',
        '8 og',
        '10 oh',
        '9 oi',
        '11 oj',
      ],
    );
    final show = LineupCinematicShow(
      matchId: 'm1',
      sedan: LineupCinematicTeamPlan.fromSide(
        side: sedan,
        teamName: 'Sedan',
        isSedan: true,
      ),
      opponent: LineupCinematicTeamPlan.fromSide(
        side: opp,
        teamName: 'Visiteur',
        isSedan: false,
      ),
    );
    final labels = show.steps.map((s) => '${s.isSedan}:${s.lineLabel}').toList();
    expect(labels.first, 'true:COMPOSITION CSSA');
    expect(labels.contains('true:REMPLAÇANTS'), isTrue);
    expect(labels.last, isNot('true:REMPLAÇANTS'));
    expect(labels.where((e) => e.startsWith('false:')).first,
        'false:COMPOSITION ADVERSE');
    expect(labels.last.contains('false:'), isTrue);
  });

  test('écussons : logo1 domicile, logo2 extérieur, CSSA des deux côtés', () {
    final home = LineupCinematicCrests.fromHomeAway(
      sedanIsHome: true,
      logo1: ' https://a/cssa.png ',
      logo2: 'https://b/opp.png',
    );
    expect(home.sedan, 'https://a/cssa.png');
    expect(home.opponent, 'https://b/opp.png');
    final away = LineupCinematicCrests.fromHomeAway(
      sedanIsHome: false,
      logo1: 'https://a/opp.png',
      logo2: 'https://b/cssa.png',
    );
    expect(away.sedan, 'https://b/cssa.png');
    expect(away.opponent, 'https://a/opp.png');
  });
}
