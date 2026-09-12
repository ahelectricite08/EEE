import 'package:dvcr/features/prono/domain/my_prono.dart';
import 'package:flutter_test/flutter_test.dart';

MyPronoItem _item({
  required String id,
  required DateTime date,
  int? journee,
  int? points = 1,
}) {
  return MyPronoItem(
    matchId: id,
    team1: 'A',
    team2: 'B',
    matchDate: date,
    predHome: 1,
    predAway: 0,
    points: points,
    journee: journee,
  );
}

void main() {
  group('parsePronoJournee', () {
    test('reads journee / fffDay / matchday', () {
      expect(parsePronoJournee({'journee': 12}), 12);
      expect(parsePronoJournee({'fffDay': '8'}), 8);
      expect(parsePronoJournee({'matchday': 3.0}), 3);
      expect(parsePronoJournee({'journee': 0}), isNull);
      expect(parsePronoJournee({}), isNull);
    });
  });

  group('frenchRankLabel', () {
    test('1er then Ne', () {
      expect(frenchRankLabel(1), '1er');
      expect(frenchRankLabel(12), '12e');
    });
  });

  group('groupMyPronos', () {
    test('groups by journée when present', () {
      final items = [
        _item(id: 'a', date: DateTime(2026, 8, 30), journee: 4),
        _item(id: 'b', date: DateTime(2026, 8, 23), journee: 3),
        _item(id: 'c', date: DateTime(2026, 8, 30, 18), journee: 4),
      ];
      final groups = groupMyPronos(items);
      expect(groups.length, 2);
      expect(groups.first.label, 'Journée 4');
      expect(groups.first.items.map((e) => e.matchId), ['c', 'a']);
      expect(groups.last.label, 'Journée 3');
    });

    test('groups by date when no journée', () {
      final items = [
        _item(id: 'a', date: DateTime(2026, 8, 30, 18)),
        _item(id: 'b', date: DateTime(2026, 8, 23)),
        _item(id: 'c', date: DateTime(2026, 8, 30, 15)),
      ];
      final groups = groupMyPronos(
        items,
        dateLabel: (d) => '${d.day}/${d.month}',
      );
      expect(groups.length, 2);
      expect(groups.first.label, '30/8');
      expect(groups.first.items.length, 2);
      expect(groups.last.label, '23/8');
    });

    test('latestPlayedMyPronoJournee is last scored round not upcoming', () {
      final items = [
        _item(id: 'next', date: DateTime(2026, 9, 6), journee: 5, points: null),
        _item(id: 'a', date: DateTime(2026, 8, 30), journee: 4, points: 0),
        _item(id: 'b', date: DateTime(2026, 8, 23), journee: 3, points: 1),
      ];
      final latest = latestPlayedMyPronoJournee(items);
      expect(latest?.label, 'Journée 4');
      expect(latest?.items.map((e) => e.matchId), ['a']);
      expect(hasOlderMyPronoJournees(items), isTrue);
    });

    test('latestPlayed clusters Saturday + Sunday without journée', () {
      final items = [
        _item(id: 'sun', date: DateTime(2026, 8, 30, 18), points: 3),
        _item(id: 'sat', date: DateTime(2026, 8, 29, 15), points: 1),
        _item(id: 'old', date: DateTime(2026, 8, 23), points: 0),
      ];
      final latest = latestPlayedMyPronoJournee(
        items,
        dateLabel: (d) => '${d.day}/${d.month}',
      );
      expect(latest?.items.map((e) => e.matchId).toSet(), {'sun', 'sat'});
      expect(hasOlderMyPronoJournees(items), isTrue);
    });

    test('pointsLabel', () {
      expect(
        _item(id: 'x', date: DateTime(2026, 1, 1), points: 3).pointsLabel,
        '+3',
      );
      expect(
        _item(id: 'y', date: DateTime(2026, 1, 1), points: 1).pointsLabel,
        '+1',
      );
      expect(
        _item(id: 'z', date: DateTime(2026, 1, 1), points: 0).pointsLabel,
        '0',
      );
      expect(
        MyPronoItem(
          matchId: 'x',
          team1: 'A',
          team2: 'B',
          matchDate: DateTime(2026, 1, 1),
          predHome: 0,
          predAway: 0,
        ).pointsLabel,
        'en att.',
      );
      expect(
        MyPronoItem(
          matchId: 'x',
          team1: 'A',
          team2: 'B',
          matchDate: DateTime(2026, 1, 1),
          predHome: 0,
          predAway: 0,
        ).isPending,
        isTrue,
      );
    });
  });
}
