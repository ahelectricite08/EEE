import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/match_lineup.dart';
import 'package:dvcr/services/motm_vote_service.dart';

void main() {
  test('MOTM names are XI + bench, never coach or staff labels', () {
    const side = MatchLineupSide(
      coach: 'Jean Staffeur',
      starters: ['1 Dupont', 'Entraîneur', '2 Martin'],
      substitutes: ['12 Bernard', 'Jean Staffeur', 'Staff'],
    );

    expect(
      side.playerNamesForMotm,
      ['1 Dupont', '2 Martin', '12 Bernard'],
    );
  });

  test('fromDoc accepts untyped Firestore maps', () {
    final lineups = MatchLineups.fromDoc({
      'lineupHome': <dynamic, dynamic>{
        'coach': 'Dupont',
        'starters': [
          {'name': 'Koffi', 'number': 9},
          '10 Lopez',
        ],
        'substitutes': ['16 Ndiaye'],
      },
      'lineupAway': <dynamic, dynamic>{
        'coach': '',
        'starters': <dynamic>['A', 'B'],
        'substitutes': <dynamic>[],
      },
    });

    expect(lineups.home.playerNamesForMotm, ['9 Koffi', '10 Lopez', '16 Ndiaye']);
    expect(lineups.away.playerNamesForMotm, ['A', 'B']);
    expect(lineups.readyForMotmVote, isTrue);
  });

  test('mergeForMotm uses match fiche when live lineups were reset', () {
    final live = {
      'lineupHome': {
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
      'lineupAway': {
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
    };
    final match = {
      'lineupHome': {
        'coach': 'Tissier',
        'starters': ['1 Gardien', '4 Stoppeur'],
        'substitutes': ['12 Banc'],
      },
      'lineupAway': {
        'coach': 'Visiteur',
        'starters': ['Adversaire 1'],
        'substitutes': <String>[],
      },
    };

    final resolved = MotmVoteService.playersFromLineups(
      live,
      matchData: match,
    );
    expect(resolved.team1Players, ['1 Gardien', '4 Stoppeur', '12 Banc']);
    expect(resolved.team2Players, ['Adversaire 1']);
    expect(resolved.ready, isTrue);
  });

  test('empty composition stays empty so the admin can fill by hand', () {
    final resolved = MotmVoteService.playersFromLineups(const {});
    expect(resolved.team1Players, isEmpty);
    expect(resolved.team2Players, isEmpty);
    expect(resolved.ready, isFalse);
  });
}
