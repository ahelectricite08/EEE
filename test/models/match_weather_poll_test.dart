import 'package:dvcr/models/match_fan_poll_window.dart';
import 'package:dvcr/models/match_weather_poll.dart';
import 'package:dvcr/services/match_weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = DateTime(2026, 8, 28, 20);

  test('k-way has no H-30 open — visible before H-30, closed at KO+20', () {
    expect(
      MatchWeatherPoll.isOpen(ko, now: DateTime(2026, 8, 20, 12)),
      isTrue,
    );
    expect(
      MatchWeatherPoll.isOpen(ko, now: DateTime(2026, 8, 28, 19, 29)),
      isTrue,
    );
    expect(
      MatchWeatherPoll.isOpen(ko, now: ko),
      isTrue,
    );
    expect(
      MatchWeatherPoll.isOpen(ko, now: DateTime(2026, 8, 28, 20, 19, 59)),
      isTrue,
    );
    expect(
      MatchWeatherPoll.isOpen(ko, now: DateTime(2026, 8, 28, 20, 20)),
      isFalse,
    );
  });

  test('one vote per uid — second choice replaces the first', () {
    var votes = <String, String>{};
    votes = MatchWeatherPoll.applyVote(
      votesByUid: votes,
      uid: 'axel',
      optionId: MatchWeatherPoll.kway.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 12),
    );
    votes = MatchWeatherPoll.applyVote(
      votesByUid: votes,
      uid: 'axel',
      optionId: MatchWeatherPoll.ardennais.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 13),
    );
    votes = MatchWeatherPoll.applyVote(
      votesByUid: votes,
      uid: 'lea',
      optionId: MatchWeatherPoll.doudoune.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 13),
    );

    expect(votes.length, 2);
    expect(votes['axel'], MatchWeatherPoll.ardennais.id);
    expect(votes['lea'], MatchWeatherPoll.doudoune.id);

    final counts = MatchWeatherPoll.countsFromVotes(votes);
    expect(counts[MatchWeatherPoll.kway.id], isNull);
    expect(counts[MatchWeatherPoll.ardennais.id], 1);
    expect(counts[MatchWeatherPoll.doudoune.id], 1);
  });

  test('vote after kickoff is still accepted until KO+20', () {
    final atKo = MatchWeatherPoll.applyVote(
      votesByUid: {'axel': MatchWeatherPoll.kway.id},
      uid: 'axel',
      optionId: MatchWeatherPoll.ardennais.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 20),
    );
    expect(atKo['axel'], MatchWeatherPoll.ardennais.id);

    final afterClose = MatchWeatherPoll.applyVote(
      votesByUid: {'axel': MatchWeatherPoll.kway.id},
      uid: 'axel',
      optionId: MatchWeatherPoll.ardennais.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 20, 20),
    );
    expect(afterClose['axel'], MatchWeatherPoll.kway.id);
  });

  test('invalid option is ignored', () {
    final votes = MatchWeatherPoll.applyVote(
      votesByUid: const {},
      uid: 'axel',
      optionId: 'parapluie',
      kickoff: ko,
      now: DateTime(2026, 8, 28, 12),
    );
    expect(votes, isEmpty);
  });

  test('tally copy is club, not corporate', () {
    expect(
      MatchWeatherPoll.saidLine(MatchWeatherPoll.doudoune, 4),
      '4 ont dit doudoune',
    );
    expect(
      MatchWeatherPoll.saidLine(MatchWeatherPoll.kway, 1),
      '1 a dit k-way',
    );
    expect(
      MatchWeatherPoll.tallyLine({
        'kway': 4,
        'ardennais': 2,
      }),
      '4 ont dit k-way  ·  2 ont dit vrai Ardennais',
    );
  });

  test('tally only names options shown that day', () {
    final kwayDay = MatchWeatherPoll.optionsFor(MatchWeatherMode.rain, 14);
    expect(
      MatchWeatherPoll.tallyLine(
        {
          'kway': 3,
          'doudoune': 8,
          'casquette': 5,
          'ardennais': 1,
        },
        visible: kwayDay,
      ),
      '3 ont dit k-way  ·  1 a dit vrai Ardennais',
    );
  });

  test('prompt follows club weather lines', () {
    expect(
      MatchWeatherPoll.promptFor(MatchWeatherMode.rain, 14),
      'Qui amène le k-way ?',
    );
    expect(
      MatchWeatherPoll.promptFor(MatchWeatherMode.clouds, 8),
      'Qui sort la doudoune ?',
    );
    expect(
      MatchWeatherPoll.promptFor(MatchWeatherMode.clear, 24),
      'Casquette ou rien ?',
    );
  });

  test('options follow the prompt — two choices, not the four-way list', () {
    List<String> ids(MatchWeatherMode mode, int? temp) =>
        MatchWeatherPoll.optionsFor(mode, temp).map((o) => o.id).toList();

    expect(ids(MatchWeatherMode.rain, 14), ['kway', 'ardennais']);
    expect(ids(MatchWeatherMode.storm, 16), ['kway', 'ardennais']);
    expect(ids(MatchWeatherMode.fog, 15), ['kway', 'ardennais']);
    expect(ids(MatchWeatherMode.none, null), ['kway', 'ardennais']);
    expect(ids(MatchWeatherMode.clouds, 15), ['kway', 'ardennais']);

    expect(ids(MatchWeatherMode.snow, 0), ['doudoune', 'ardennais']);
    expect(ids(MatchWeatherMode.clouds, 8), ['doudoune', 'ardennais']);
    expect(ids(MatchWeatherMode.clear, 10), ['doudoune', 'ardennais']);

    expect(ids(MatchWeatherMode.clear, 24), ['casquette', 'ardennais']);
    expect(ids(MatchWeatherMode.sunClouds, 20), ['casquette', 'ardennais']);

    expect(ids(MatchWeatherMode.rain, 8), ['kway', 'doudoune', 'ardennais']);
    expect(ids(MatchWeatherMode.storm, 12), ['kway', 'doudoune', 'ardennais']);

    expect(
      MatchWeatherPoll.optionsFor(MatchWeatherMode.clear, 24)
          .map((o) => o.label)
          .toList(),
      ['Casquette et basta', 'Rien, je suis un vrai Ardennais'],
    );
    expect(
      MatchWeatherPoll.optionsFor(MatchWeatherMode.rain, 14)
          .map((o) => o.label)
          .toList(),
      ['Oui, obligatoire', 'Non, je suis un vrai Ardennais'],
    );
  });

  test('applyVote rejects an option that is not on today’s card', () {
    final rejected = MatchWeatherPoll.applyVote(
      votesByUid: const {},
      uid: 'axel',
      optionId: MatchWeatherPoll.casquette.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 12),
      mode: MatchWeatherMode.rain,
      tempC: 14,
    );
    expect(rejected, isEmpty);

    final accepted = MatchWeatherPoll.applyVote(
      votesByUid: const {},
      uid: 'axel',
      optionId: MatchWeatherPoll.kway.id,
      kickoff: ko,
      now: DateTime(2026, 8, 28, 12),
      mode: MatchWeatherMode.rain,
      tempC: 14,
    );
    expect(accepted['axel'], MatchWeatherPoll.kway.id);
  });
}
