import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/lineup_prediction.dart';
import 'package:dvcr/models/lineup_xi_verdict.dart';
import 'package:dvcr/models/match_lineup.dart';
import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/services/lineup_prediction_service.dart';
import 'package:dvcr/utils/player_name_normalize.dart';

List<String> _names(String prefix, [int n = 11]) =>
    List.generate(n, (i) => '$prefix${i + 1}');

LineupPrediction _pred(List<String> names) => LineupPrediction(
      id: 'm_u',
      matchId: 'm',
      uid: 'u',
      displayName: 'Axel',
      playerNames: names,
    );

MatchModel _sedanHome() => MatchModel(
      id: 'm',
      team1: 'CSSA Sedan',
      team2: 'AS Test',
      date: DateTime(2026, 8, 29, 18),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    );

MatchLineups _lineups({
  required List<String> sedan,
  List<String> opponent = const [],
  bool sedanHome = true,
}) {
  final cssa = MatchLineupSide(starters: sedan);
  final other = MatchLineupSide(starters: opponent);
  return MatchLineups(
    home: sedanHome ? cssa : other,
    away: sedanHome ? other : cssa,
  );
}

void main() {
  test('XI probable lock window stays 60 h', () {
    expect(LineupPrediction.lockBeforeKickoff, const Duration(hours: 60));
    expect(LineupPrediction.lockBeforeKickoff, const Duration(days: 2, hours: 12));
    expect(LineupPrediction.lockWindowLabel, '2 j 12 h avant le match');
  });

  test('official Sedan XI (≥11 titulaires) remplace le jeu XI probable', () {
    final match = _sedanHome();
    final eleven = _names('Sedan');
    final opponent = _names('Adv');

    expect(
      LineupPredictionService.showsXiProbableGame(
        _lineups(sedan: eleven, opponent: opponent),
        match,
      ),
      isFalse,
    );
    expect(
      LineupPredictionService.hasOfficialSedanLineup(
        _lineups(sedan: eleven, opponent: opponent),
        match,
      ),
      isTrue,
    );
  });

  test('sans XI Sedan officiel, le jeu reste même si l’adversaire a une compo', () {
    final match = _sedanHome();
    expect(
      LineupPredictionService.showsXiProbableGame(
        _lineups(sedan: const ['1 Gardien'], opponent: _names('Adv')),
        match,
      ),
      isTrue,
    );
  });

  test('le verdict ne compte que les titulaires Sedan, jamais l’adversaire', () {
    final sedan = _names('Sedan');
    final opponent = _names('Adv');
    final pred = _pred(sedan);

    final vsSedan = LineupXiVerdict.resolve(
      prediction: pred,
      officialSedanStarters: sedan,
    );
    expect(vsSedan.kind, LineupXiVerdictKind.perfect);
    expect(vsSedan.matched, 11);
    expect(vsSedan.rankingPoints, 3);
    expect(vsSedan.title, LineupXiVerdict.titleBon);
    expect(vsSedan.body, contains('11 titulaires Sedan sur 11'));
    expect(vsSedan.body, contains('+3 pts au classement Pronos'));

    final vsOpponentByMistake = LineupXiVerdict.resolve(
      prediction: pred,
      officialSedanStarters: opponent,
    );
    expect(vsOpponentByMistake.kind, LineupXiVerdictKind.missed);
    expect(vsOpponentByMistake.matched, 0);
    expect(vsOpponentByMistake.rankingPoints, 0);
    expect(vsOpponentByMistake.title, LineupXiVerdict.titlePasBon);
  });

  test('un prono qui copie le XI adverse ne marque rien côté Sedan', () {
    final sedan = _names('Sedan');
    final opponent = _names('Adv');
    final verdict = LineupXiVerdict.resolve(
      prediction: _pred(opponent),
      officialSedanStarters: sedan,
    );
    expect(verdict.matched, 0);
    expect(verdict.title, LineupXiVerdict.titlePasBon);
    expect(
      LineupXiVerdict.hitSedanStarterLabels(
        prediction: _pred(opponent),
        officialSedanStarters: sedan,
      ),
      isEmpty,
    );
  });

  test('les remplaçants Sedan ne comptent pas — barème 9/10/11 titulaires', () {
    final starters = _names('Tit');
    final bench = _names('Banc', 5);
    final predicted = [...starters.take(8), ...bench.take(3)];
    final verdict = LineupXiVerdict.resolve(
      prediction: _pred(predicted),
      officialSedanStarters: starters,
    );
    expect(verdict.matched, 8);
    expect(verdict.rankingPoints, 0);
    expect(verdict.kind, LineupXiVerdictKind.missed);
    expect(verdict.title, LineupXiVerdict.titlePasBon);
    expect(LineupPrediction.pointsForMatches(9), 1);
    expect(LineupPrediction.pointsForMatches(10), 2);
    expect(LineupPrediction.pointsForMatches(11), 3);
    expect(LineupPrediction.pointsForMatches(8), 0);
  });

  test('9 et 10 titulaires Sedan → t’as presque bon + points classement', () {
    final official = _names('S');
    final nine = LineupXiVerdict.resolve(
      prediction: _pred([...official.take(9), 'X10', 'X11']),
      officialSedanStarters: official,
    );
    expect(nine.kind, LineupXiVerdictKind.almost);
    expect(nine.title, LineupXiVerdict.titlePresque);
    expect(nine.matched, 9);
    expect(nine.rankingPoints, 1);
    expect(nine.body, contains('9 titulaires Sedan sur 11'));
    expect(nine.body, contains('+1 pt au classement Pronos'));

    final ten = LineupXiVerdict.resolve(
      prediction: _pred([...official.take(10), 'X11']),
      officialSedanStarters: official,
    );
    expect(ten.title, LineupXiVerdict.titlePresque);
    expect(ten.matched, 10);
    expect(ten.rankingPoints, 2);
  });

  test('sans XI probable : copy 60 h Sedan-only, pas d’adversaire', () {
    final empty = LineupXiVerdict.resolve(
      prediction: null,
      officialSedanStarters: _names('Sedan'),
    );
    expect(empty.kind, LineupXiVerdictKind.empty);
    expect(empty.title, LineupXiVerdict.titleEmpty);
    expect(empty.body, LineupXiVerdict.emptyBody());
    expect(empty.body, contains(LineupPrediction.lockWindowLabel));
    expect(empty.body, contains('XI probable Sedan'));
    expect(empty.body, contains('points au classement'));
    expect(empty.body.toLowerCase(), isNot(contains('adversaire')));
    expect(
      LineupXiVerdict.resolve(
        prediction: _pred(_names('S', 10)),
        officialSedanStarters: _names('Sedan'),
      ).kind,
      LineupXiVerdictKind.empty,
    );
  });

  test('tampons de titulaires : uniquement les noms Sedan trouvés', () {
    final official = ['1 Dupont', '9 Martin', '10 Lopez'];
    final hits = matchingOfficialPlayerLabels(
      predicted: ['Dupont', 'Un visiteur', 'Lopez'],
      official: official,
    );
    expect(hits, ['1 Dupont', '10 Lopez']);
  });
}
