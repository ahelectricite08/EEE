import 'package:dvcr/features/prono/domain/leaderboard_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planLeaderboardWindow', () {
    test('empty leaderboard', () {
      final p = planLeaderboardWindow(totalCount: 0, myRank: null);
      expect(p.topCount, 0);
      expect(p.showNeighborZone, isFalse);
      expect(p.myRank, isNull);
    });

    test('user in top 20 — no neighbor zone', () {
      final p = planLeaderboardWindow(totalCount: 100, myRank: 7);
      expect(p.topCount, 20);
      expect(p.showNeighborZone, isFalse);
      expect(p.myRank, 7);
    });

    test('user 1st / 2nd — still only top', () {
      expect(
        planLeaderboardWindow(totalCount: 50, myRank: 1).showNeighborZone,
        isFalse,
      );
      expect(
        planLeaderboardWindow(totalCount: 50, myRank: 2).showNeighborZone,
        isFalse,
      );
    });

    test('user outside top 20 — neighbors rank-1, me, rank+1', () {
      final p = planLeaderboardWindow(totalCount: 600, myRank: 500);
      expect(p.topCount, 20);
      expect(p.showNeighborZone, isTrue);
      expect(p.neighborFrom, 499);
      expect(p.neighborTo, 501);
      expect(p.myRank, 500);
    });

    test('user just after top 20 — no overlap with top', () {
      final p = planLeaderboardWindow(totalCount: 100, myRank: 21);
      expect(p.showNeighborZone, isTrue);
      expect(p.neighborFrom, 21); // 20 already in top
      expect(p.neighborTo, 22);
    });

    test('user last — no rank+1', () {
      final p = planLeaderboardWindow(totalCount: 80, myRank: 80);
      expect(p.showNeighborZone, isTrue);
      expect(p.neighborFrom, 79);
      expect(p.neighborTo, 80);
    });

    test('fewer than topN players — show all, no zone', () {
      final p = planLeaderboardWindow(totalCount: 12, myRank: 12);
      expect(p.topCount, 12);
      expect(p.showNeighborZone, isFalse);
      expect(p.myRank, 12);
    });

    test('unranked user', () {
      final p = planLeaderboardWindow(totalCount: 40, myRank: null);
      expect(p.topCount, 20);
      expect(p.showNeighborZone, isFalse);
      expect(p.myRank, isNull);
    });
  });

  group('sliceLeaderboardWindow', () {
    test('slices league list around current user', () {
      final entries = List.generate(30, (i) => 'u$i');
      final sliced = sliceLeaderboardWindow<String>(
        sortedEntries: entries,
        uidOf: (e) => e,
        currentUid: 'u24', // rank 25
      );
      expect(sliced.top.map((e) => e.rank).toList(),
          List.generate(20, (i) => i + 1));
      expect(sliced.neighbors.map((e) => e.rank).toList(), [24, 25, 26]);
      expect(sliced.neighbors.map((e) => e.data).toList(),
          ['u23', 'u24', 'u25']);
    });
  });
}
