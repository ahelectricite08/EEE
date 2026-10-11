import 'package:dvcr/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kickoff = DateTime(2026, 10, 4, 15, 0);
  final after = DateTime(2026, 10, 8, 1, 30);

  group('MatchModel.resolveDisplayStatus', () {
    test('upcoming + score après coup d’envoi → finished', () {
      expect(
        MatchModel.resolveDisplayStatus(
          rawStatus: 'upcoming',
          date: kickoff,
          score1: 2,
          score2: 0,
          now: after,
        ),
        MatchStatus.finished,
      );
    });

    test('upcoming sans score reste upcoming', () {
      expect(
        MatchModel.resolveDisplayStatus(
          rawStatus: 'upcoming',
          date: kickoff,
          now: after,
        ),
        MatchStatus.upcoming,
      );
    });

    test('finished dans le futur redevient upcoming', () {
      expect(
        MatchModel.resolveDisplayStatus(
          rawStatus: 'finished',
          date: DateTime(2026, 10, 18, 18),
          score1: 0,
          score2: 0,
          now: after,
        ),
        MatchStatus.upcoming,
      );
    });
  });
}
