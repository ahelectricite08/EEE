import 'package:dvcr/models/dugauguez_place.dart';
import 'package:dvcr/models/match_fan_poll_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = DateTime(2026, 8, 28, 20);

  test('four option labels stay funny club copy', () {
    expect(
      DugauguezPlaceChoice.values.map((c) => c.label).toList(),
      [
        'À la maison',
        'Au stade',
        'En virage',
        'En virage extérieur',
      ],
    );
  });

  test('place window is H-30 inclusive to KO+20 exclusive, no live required', () {
    expect(
      DugauguezPlaceWindow.isOpen(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 19, 29),
      ),
      isFalse,
    );
    expect(
      DugauguezPlaceWindow.isOpen(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 19, 30),
      ),
      isTrue,
    );
    expect(
      DugauguezPlaceWindow.isOpen(kickoff: ko, now: ko),
      isTrue,
    );
    expect(
      DugauguezPlaceWindow.isOpen(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 20, 19, 59),
      ),
      isTrue,
    );
    expect(
      DugauguezPlaceWindow.isOpen(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 20, 20),
      ),
      isFalse,
    );
    expect(
      MatchFanPollWindow.opensAt(ko),
      DateTime(2026, 8, 28, 19, 30),
    );
    expect(
      DugauguezPlaceWindow.closesAt(ko),
      DateTime(2026, 8, 28, 20, 20),
    );
  });

  test('only Sedan home (team1) — away CSSA stays hidden', () {
    bool show(String team1, {bool force = false, DateTime? now}) {
      return DugauguezPlaceGate.shouldShow(
        team1: team1,
        kickoff: ko,
        now: now ?? DateTime(2026, 8, 28, 20, 5),
        force: force,
      );
    }

    expect(show('CSSA'), isTrue);
    expect(show('SEDAN ARDENNES CS'), isTrue);
    expect(show('AS Belfort'), isFalse);
    expect(DugauguezPlaceGate.isSedanHome('Bogny'), isFalse);
    expect(
      show('CSSA', now: DateTime(2026, 8, 28, 19, 29)),
      isFalse,
    );
    expect(show('Bogny', force: true), isTrue);
    expect(
      show('CSSA', force: true, now: DateTime(2026, 8, 28, 12)),
      isTrue,
    );
    expect(
      DugauguezPlaceGate.shouldShow(
        team1: 'Bogny',
        kickoff: null,
        now: DateTime(2026, 8, 28, 20, 20),
        force: true,
      ),
      isTrue,
    );
  });

  test('percentages round from the four buckets', () {
    final counts = DugauguezPlaceCounts({
      DugauguezPlaceChoice.home: 2,
      DugauguezPlaceChoice.stadium: 1,
      DugauguezPlaceChoice.virage: 1,
      DugauguezPlaceChoice.virageExt: 0,
    });
    expect(counts.total, 4);
    expect(counts.percentOf(DugauguezPlaceChoice.home), 50);
    expect(counts.percentOf(DugauguezPlaceChoice.virageExt), 0);
  });
}
