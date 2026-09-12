import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/services/live_start_service.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _m({
  required String id,
  required DateTime date,
  String team1 = 'CSSA',
  String team2 = 'FC Test',
  bool manual = false,
}) {
  return MatchModel(
    id: id,
    team1: team1,
    team2: team2,
    date: date,
    competition: 'Régional 1',
    status: MatchStatus.upcoming,
    manual: manual,
  );
}

void main() {
  final now = DateTime(2026, 9, 11, 10);

  test('picker : Sedan dans la fenêtre, pas le reste de la poule', () {
    final sedan = _m(id: 's', date: DateTime(2026, 9, 13, 18));
    final other = _m(
      id: 'o',
      date: DateTime(2026, 9, 13, 16),
      team1: 'Reims Sainte-Anne',
      team2: 'Étain Buzy',
    );
    expect(LiveStartService.isPickableLiveMatch(sedan, now: now), isTrue);
    expect(LiveStartService.isPickableLiveMatch(other, now: now), isFalse);
  });

  test('picker : match manuel hors Sedan dans la fenêtre', () {
    final manual = _m(
      id: 'man',
      date: DateTime(2026, 9, 12, 15),
      team1: 'Amical A',
      team2: 'Amical B',
      manual: true,
    );
    expect(LiveStartService.isPickableLiveMatch(manual, now: now), isTrue);
  });

  test('picker : Sedan hors fenêtre exclu', () {
    final later = _m(id: 'late', date: DateTime(2026, 10, 1, 18));
    expect(LiveStartService.isPickableLiveMatch(later, now: now), isFalse);
  });
}
