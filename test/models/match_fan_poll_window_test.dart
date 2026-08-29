import 'package:dvcr/models/match_fan_poll_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = DateTime(2026, 8, 28, 20);

  test('place opens H-30, k-way is already open hours before', () {
    final noon = DateTime(2026, 8, 28, 12);
    expect(MatchFanPollWindow.isPlaceOpen(kickoff: ko, now: noon), isFalse);
    expect(MatchFanPollWindow.isKwayOpen(kickoff: ko, now: noon), isTrue);
    expect(
      MatchFanPollWindow.isPlaceOpen(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 19, 30),
      ),
      isTrue,
    );
  });

  test('both close at KO+20 exclusive', () {
    final lastTick = DateTime(2026, 8, 28, 20, 19, 59);
    final closed = DateTime(2026, 8, 28, 20, 20);
    expect(MatchFanPollWindow.isPlaceOpen(kickoff: ko, now: lastTick), isTrue);
    expect(MatchFanPollWindow.isKwayOpen(kickoff: ko, now: lastTick), isTrue);
    expect(MatchFanPollWindow.isPlaceOpen(kickoff: ko, now: closed), isFalse);
    expect(MatchFanPollWindow.isKwayOpen(kickoff: ko, now: closed), isFalse);
  });
}
