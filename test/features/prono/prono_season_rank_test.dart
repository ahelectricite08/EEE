import 'package:dvcr/features/prono/domain/prono_season_rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comparePronoSeasonRank', () {
    test('points first', () {
      expect(
        comparePronoSeasonRank(
          pointsA: 10,
          exactA: 9,
          lineupPointsA: 9,
          firstScorerPointsA: 9,
          uidA: 'z',
          pointsB: 20,
          exactB: 0,
          lineupPointsB: 0,
          firstScorerPointsB: 0,
          uidB: 'a',
        ),
        greaterThan(0),
      );
    });

    test('same points — more exacts ranks higher', () {
      expect(
        comparePronoSeasonRank(
          pointsA: 12,
          exactA: 4,
          lineupPointsA: 0,
          firstScorerPointsA: 0,
          uidA: 'a',
          pointsB: 12,
          exactB: 3,
          lineupPointsB: 99,
          firstScorerPointsB: 99,
          uidB: 'z',
        ),
        lessThan(0),
      );
    });

    test('same points and exacts — XI probable points, not 11/11 count', () {
      expect(
        comparePronoSeasonRank(
          pointsA: 12,
          exactA: 2,
          lineupPointsA: 8,
          firstScorerPointsA: 0,
          uidA: 'a',
          pointsB: 12,
          exactB: 2,
          lineupPointsB: 5,
          firstScorerPointsB: 99,
          uidB: 'z',
        ),
        lessThan(0),
      );
    });

    test('then first-scorer points', () {
      expect(
        comparePronoSeasonRank(
          pointsA: 12,
          exactA: 2,
          lineupPointsA: 5,
          firstScorerPointsA: 6,
          uidA: 'a',
          pointsB: 12,
          exactB: 2,
          lineupPointsB: 5,
          firstScorerPointsB: 3,
          uidB: 'z',
        ),
        lessThan(0),
      );
    });
  });

  group('rankPronoSeasonEntries', () {
    test('assigns sequential ranks after the shared order', () {
      final ranked = rankPronoSeasonEntries<(int, int, int, int, String)>(
        entries: const [
          (10, 0, 0, 0, 'd'),
          (12, 2, 3, 1, 'c'),
          (12, 3, 0, 0, 'b'),
          (12, 2, 4, 0, 'a'),
        ],
        pointsOf: (e) => e.$1,
        exactOf: (e) => e.$2,
        lineupPointsOf: (e) => e.$3,
        firstScorerPointsOf: (e) => e.$4,
        uidOf: (e) => e.$5,
      );
      expect(
        ranked.map((r) => (r.rank, r.entry.$5)).toList(),
        [
          (1, 'b'),
          (2, 'a'),
          (3, 'c'),
          (4, 'd'),
        ],
      );
    });
  });
}
