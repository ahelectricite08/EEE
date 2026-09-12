import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/live_event_player_source.dart';

void main() {
  group('LiveEventPlayerSource.fromLive', () {
    test('uses that side lineup, not the full club roster', () {
      final src = LiveEventPlayerSource.fromLive(
        live: {
          'team1': 'CSSA Sedan',
          'team2': 'Épinal',
          'lineupHome': {
            'coach': 'Tissier',
            'starters': ['9 Koffi', 'Entraîneur', '10 Lopez'],
            'substitutes': ['16 Ndiaye'],
          },
          'lineupAway': {
            'starters': ['Martin'],
            'substitutes': <String>[],
          },
        },
        selectedTeam: 'CSSA Sedan',
      );

      expect(src.fromLineup, isTrue);
      expect(src.useSedanSquadFallback, isFalse);
      expect(src.names, ['9 Koffi', '10 Lopez', '16 Ndiaye']);
    });

    test('opponent goal uses away composition when present', () {
      final src = LiveEventPlayerSource.fromLive(
        live: {
          'team1': 'CSSA Sedan',
          'team2': 'Épinal',
          'lineupHome': {
            'starters': ['9 Koffi', '10 Lopez'],
            'substitutes': <String>[],
          },
          'lineupAway': {
            'starters': ['7 Martin', '9 Durand'],
            'substitutes': ['12 Bernard'],
          },
        },
        selectedTeam: 'Épinal',
      );

      expect(src.fromLineup, isTrue);
      expect(src.useSedanSquadFallback, isFalse);
      expect(src.opponentWithoutLineup, isFalse);
      expect(src.names, ['7 Martin', '9 Durand', '12 Bernard']);
    });

    test('opponent without XI keeps free text, never Sedan roster', () {
      final src = LiveEventPlayerSource.fromLive(
        live: {
          'team1': 'CSSA Sedan',
          'team2': 'Épinal',
          'lineupHome': {
            'starters': ['9 Koffi'],
            'substitutes': <String>[],
          },
        },
        selectedTeam: 'Épinal',
      );

      expect(src.fromLineup, isFalse);
      expect(src.useSedanSquadFallback, isFalse);
      expect(src.opponentWithoutLineup, isTrue);
      expect(src.names, isEmpty);
    });

    test('Sedan without lineup falls back to club squad', () {
      final src = LiveEventPlayerSource.fromLive(
        live: {
          'team1': 'CSSA Sedan',
          'team2': 'Épinal',
        },
        selectedTeam: 'CSSA Sedan',
      );

      expect(src.fromLineup, isFalse);
      expect(src.useSedanSquadFallback, isTrue);
      expect(src.opponentWithoutLineup, isFalse);
    });
  });

  test('quiet opponent hint is not a branded But adverse product', () {
    expect(LiveEventPlayerSource.quietOpponentHint, isNot(contains('But adverse')));
    expect(LiveEventPlayerSource.quietOpponentHint.toLowerCase(), contains('saisie libre'));
  });
}
