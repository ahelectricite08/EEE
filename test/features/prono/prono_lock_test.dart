import 'package:dvcr/features/prono/domain/prono_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kickoff = DateTime(2026, 10, 4, 18, 0);

  group('prono lock', () {
    test('open until kickoff, locked at kickoff', () {
      expect(
        isMatchPronoLocked(kickoff, now: DateTime(2026, 10, 4, 17, 59)),
        isFalse,
      );
      expect(
        isMatchPronoLocked(kickoff, now: kickoff),
        isTrue,
      );
    });

    test('window opens 7 days before', () {
      expect(
        isMatchPronoWindowOpen(kickoff, now: DateTime(2026, 9, 26, 17, 0)),
        isFalse,
      );
      expect(
        isMatchPronoWindowOpen(kickoff, now: DateTime(2026, 9, 28, 12, 0)),
        isTrue,
      );
      expect(
        isMatchPronoViewable(kickoff, now: DateTime(2026, 10, 4, 19, 0)),
        isTrue,
      );
    });

    test('in play until finished with scores', () {
      expect(
        isMatchPronoInPlay(
          kickoff,
          status: 'live',
          now: DateTime(2026, 10, 4, 18, 30),
        ),
        isTrue,
      );
      expect(
        isMatchPronoInPlay(
          kickoff,
          status: 'finished',
          score1: 2,
          score2: 1,
          now: DateTime(2026, 10, 4, 20, 0),
        ),
        isFalse,
      );
      expect(
        isMatchPronoSettled(status: 'finished', score1: 2, score2: 1),
        isTrue,
      );
    });

    test('cta labels', () {
      expect(
        pronoCtaLabel(
          matchDate: kickoff,
          hasPred: true,
          now: DateTime(2026, 10, 3, 12, 0),
        ),
        'Modifier mon prono',
      );
      expect(
        pronoCtaLabel(
          matchDate: kickoff,
          hasPred: true,
          status: 'live',
          now: DateTime(2026, 10, 4, 18, 15),
        ),
        'Prono verrouillé · match en cours',
      );
      expect(
        pronoCtaLabel(
          matchDate: kickoff,
          hasPred: true,
          status: 'live',
          now: DateTime(2026, 10, 4, 18, 15),
          compact: true,
        ),
        'Verrouillé',
      );
    });

    test('posted line never repeats the result', () {
      expect(
        pronoPostedLine(predHome: 2, predAway: 1),
        'Ton prono 2–1',
      );
      expect(
        pronoPostedLine(predHome: 2, predAway: 1, points: 3),
        'Ton prono 2–1  ·  +3',
      );
      expect(
        pronoPostedLine(predHome: 1, predAway: 1, points: 0),
        'Ton prono 1–1  ·  0 pt',
      );
    });

    test('versus line', () {
      expect(
        pronoVersusResultLine(predHome: 2, predAway: 1),
        'Ton prono 2–1',
      );
      expect(
        pronoVersusResultLine(
          predHome: 2,
          predAway: 1,
          resHome: 1,
          resAway: 0,
          live: true,
        ),
        'Ton prono 2–1  ·  live 1–0',
      );
      expect(
        pronoVersusResultLine(
          predHome: 2,
          predAway: 1,
          resHome: 2,
          resAway: 1,
          points: 3,
        ),
        'Ton prono 2–1  ·  2–1  ·  +3',
      );
    });

    test('board lookback is two days', () {
      expect(pronoBoardLookback, const Duration(days: 2));
    });
  });
}
