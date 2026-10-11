import 'package:dvcr/features/prono/domain/models/prono_match_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

PronoMatchListItem _item({
  required String id,
  String team1 = 'Epernay',
  String team2 = 'Hettange',
  DateTime? date,
  int? score1,
  int? score2,
}) {
  return PronoMatchListItem(
    id: id,
    team1: team1,
    team2: team2,
    date: date ?? DateTime(2026, 10, 3, 18, 30),
    competition: 'Régional 1',
    score1: score1,
    score2: score2,
  );
}

void main() {
  test('même affiche le même jour → même clé, FFF gagne sur un id manuel', () {
    final fff = _item(id: 'fff_55794280', score1: 1, score2: 1);
    final manual = _item(id: 'abcManual1');
    expect(pronoFixtureDedupeKey(fff), pronoFixtureDedupeKey(manual));
    expect(preferFffPronoMatch(fff, manual), isTrue);
    expect(preferFffPronoMatch(manual, fff), isFalse);
  });

  test('équipes inversées le même jour restent la même affiche', () {
    final home = _item(id: 'fff_1', team1: 'A', team2: 'B');
    final swapped = _item(id: 'fff_2', team1: 'B', team2: 'A');
    expect(pronoFixtureDedupeKey(home), pronoFixtureDedupeKey(swapped));
  });
}
