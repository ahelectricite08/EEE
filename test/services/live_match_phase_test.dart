import 'package:dvcr/services/live_match_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveMatchPhase.minuteChip', () {
    test('fin de match affiche FIN, pas la minute figée', () {
      expect(
        LiveMatchPhase.minuteChip(
          lastEvent: 'fulltime',
          elapsedSeconds: 4 * 60,
          storedMinute: 4,
          chronoRunning: false,
        ),
        'FIN',
      );
    });

    test('mi-temps affiche MI-TEMPS, pas la minute figée', () {
      expect(
        LiveMatchPhase.minuteChip(
          lastEvent: 'halftime',
          elapsedSeconds: 45 * 60,
          storedMinute: 45,
          chronoRunning: false,
        ),
        'MI-TEMPS',
      );
    });

    test('en jeu affiche la minute du chrono', () {
      expect(
        LiveMatchPhase.minuteChip(
          lastEvent: '',
          elapsedSeconds: 4 * 60 + 12,
          storedMinute: 4,
          chronoRunning: true,
        ),
        "4'",
      );
    });

    test('fin de prolongations affiche FIN PROL.', () {
      expect(
        LiveMatchPhase.minuteChip(
          lastEvent: 'extra_fulltime',
          elapsedSeconds: 120 * 60,
          storedMinute: 120,
          chronoRunning: false,
        ),
        'FIN PROL.',
      );
    });
  });
}
