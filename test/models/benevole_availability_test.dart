import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/benevole_availability.dart';

void main() {
  test('board parses Antoine payload', () {
    final board = BenevoleAvailabilityBoard.fromMap({
      'email': 'a@b.fr',
      'posts': ['Réalisateur', 'Ralenti'],
      'matches': [
        {
          'id': 'uuid',
          'putId': '55794284',
          'homeTeam': 'SEDAN ARDENNES CS',
          'awayTeam': 'UCKANGE USAG',
          'kickoffAt': '2026-10-03T16:30:00.000Z',
          'status': 'PRESENT',
          'wishes': ['Réalisateur'],
        },
      ],
    });
    expect(board.email, 'a@b.fr');
    expect(board.posts, ['Réalisateur', 'Ralenti']);
    expect(board.matches.single.putId, '55794284');
    expect(board.matches.single.status, 'PRESENT');
    expect(board.matches.single.wishes, ['Réalisateur']);
  });
}
