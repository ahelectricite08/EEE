import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/live_entry_error.dart';
import 'package:dvcr/models/match_stats_schema.dart';
import 'package:dvcr/services/live_banner_format.dart';
import 'package:dvcr/services/live_state_service.dart';

void main() {
  test('operator label is ERREUR SAISIE, public copy is OUPS', () {
    expect(LiveEntryError.uiLabel, 'ERREUR SAISIE');
    expect(LiveEntryError.confirmTitle, 'Erreur de saisie ?');
    expect(LiveEntryError.pushTitle, 'OUPS.');
    expect(
      LiveEntryError.pushBody,
      'DVCR s\'est emmêlé les crayons. On corrige.',
    );
    expect(LiveEntryError.tickerLine, 'OUPS.');
    expect(LiveEntryError.type, 'goal_cancelled');
  });

  test('goals, cards and subs can be marked as entry error', () {
    expect(LiveEntryError.canCorrect('goal'), isTrue);
    expect(LiveEntryError.canCorrect('yellow'), isTrue);
    expect(LiveEntryError.canCorrect('red'), isTrue);
    expect(LiveEntryError.canCorrect('substitution'), isTrue);
    expect(LiveEntryError.canCorrect('goal_disallowed'), isFalse);
    expect(LiveEntryError.canCorrect('offside'), isFalse);
    expect(LiveEntryError.canCorrect('goal_cancelled'), isFalse);
  });

  test('public event line says OUPS, not But annulé', () {
    final line = MatchStatsSchema.eventPlayerLine({
      'type': 'goal_cancelled',
      'player': 'Koffi',
      'minute': 12,
    });
    expect(line, contains('OUPS.'));
    expect(line, contains('Koffi'));
    expect(line.toLowerCase(), isNot(contains('annulé')));
  });

  test('live banner for entry error uses OUPS copy', () {
    const before = LiveHubState(
      isMatchLive: true,
      isEmissionLive: false,
      scoreHome: 1,
      scoreAway: 0,
    );
    final after = LiveHubState(
      isMatchLive: true,
      isEmissionLive: false,
      scoreHome: 0,
      scoreAway: 0,
      timelineEvents: const [
        {
          'type': 'goal_cancelled',
          'player': 'Koffi',
          'minute': 12,
          'team': 'CSSA Sedan',
        },
      ],
    );
    final banner = LiveBannerFormat.topBanner(after, before);
    expect(banner, isNotNull);
    expect(banner!.title, 'OUPS.');
    expect(banner.body, 'DVCR s\'est emmêlé les crayons. On corrige.');
  });
}
