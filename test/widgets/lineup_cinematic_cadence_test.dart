import 'package:dvcr/models/lineup_cinematic_plan.dart';
import 'package:dvcr/widgets/lineup_cinematic_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LineupCinematicStep step({
    required String label,
    int players = 0,
    bool intro = false,
    bool subs = false,
  }) {
    return LineupCinematicStep(
      isSedan: true,
      teamName: 'Sedan',
      formation: '',
      lineLabel: label,
      players: List.generate(
        players,
        (i) => LineupCinematicPlayer(name: 'J$i', number: i),
      ),
      isTeamIntro: intro,
      isSubstitutes: subs,
    );
  }

  test('hold plus long que l’ancien 2,2 s, lisible par poste', () {
    expect(
      LineupCinematicCadence.holdFor(step(label: 'COMPOSITION CSSA', intro: true)),
      const Duration(milliseconds: 3200),
    );
    expect(
      LineupCinematicCadence.holdFor(step(label: 'GARDIEN', players: 1)),
      const Duration(milliseconds: 3200),
    );
    expect(
      LineupCinematicCadence.holdFor(step(label: 'DÉFENSE', players: 4)),
      const Duration(milliseconds: 3800),
    );
    expect(
      LineupCinematicCadence.holdFor(
        step(label: 'REMPLAÇANTS', players: 7, subs: true),
      ),
      const Duration(milliseconds: 4700),
    );
    expect(LineupCinematicCadence.open.inMilliseconds, 720);
    expect(
      LineupCinematicCadence.skipLock,
      const Duration(milliseconds: 3000),
    );
    expect(LineupCinematicCadence.skipAllowed(Duration.zero), isFalse);
    expect(
      LineupCinematicCadence.skipAllowed(const Duration(milliseconds: 2999)),
      isFalse,
    );
    expect(
      LineupCinematicCadence.skipAllowed(const Duration(milliseconds: 3000)),
      isTrue,
    );
  });
}
