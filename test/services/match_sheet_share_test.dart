import 'package:dvcr/models/benevole_posts.dart';
import 'package:dvcr/screens/profile/match_sheet_share_visual.dart';
import 'package:dvcr/services/match_sheet_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 29, 20, 0);

  group('isPremiereLiveMatch', () {
    test('R1 and Coupe are 1ère', () {
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'benevoleType': BenevolePosts.typeR1,
        }),
        isTrue,
      );
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'benevoleType': BenevolePosts.typeCoupe,
        }),
        isTrue,
      );
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'competition': 'National 3',
        }),
        isTrue,
      );
    });

    test('R2 / réserve / Flammes are excluded', () {
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'benevoleType': BenevolePosts.typeReserve,
        }),
        isFalse,
      );
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'benevoleType': BenevolePosts.typeFlammes,
        }),
        isFalse,
      );
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'competition': 'Équipe réserve',
        }),
        isFalse,
      );
      expect(
        MatchSheetShareService.isPremiereLiveMatch({
          'competition': 'Régional 2',
        }),
        isFalse,
      );
    });
  });

  group('hasShareVisual', () {
    test('opens from liveEndedAt for 48 hours without a note', () {
      expect(
        MatchSheetShareService.hasShareVisual({
          'benevoleType': BenevolePosts.typeR1,
          'liveEndedAt': now.subtract(const Duration(hours: 2)),
          'team1': 'CSSA',
          'team2': 'Pau',
        }, now),
        isTrue,
      );
    });

    test('hides after 48 hours and on R2', () {
      expect(
        MatchSheetShareService.hasShareVisual({
          'benevoleType': BenevolePosts.typeR1,
          'liveEndedAt': now.subtract(const Duration(hours: 50)),
        }, now),
        isFalse,
      );
      expect(
        MatchSheetShareService.hasShareVisual({
          'benevoleType': BenevolePosts.typeReserve,
          'liveEndedAt': now.subtract(const Duration(hours: 1)),
        }, now),
        isFalse,
      );
    });
  });

  test('payload reads score and CSSA / opponent scorers', () {
    final payload = MatchSheetSharePayload.fromDoc(
      'm1',
      {
        'team1': 'CSSA',
        'team2': 'Pau',
        'score1': 2,
        'score2': 1,
        'date': now.subtract(const Duration(hours: 3)),
        'liveEndedAt': now.subtract(const Duration(hours: 1)),
        'competition': 'N3',
        'benevoleType': BenevolePosts.typeR1,
        'events': [
          {
            'type': 'goal',
            'team': 'CSSA',
            'player': 'Dupont',
            'minute': 12,
          },
          {
            'type': 'goal',
            'team': 'Pau',
            'player': 'Martin',
            'minute': 44,
          },
          {
            'type': 'goal',
            'team': 'CSSA',
            'player': 'Durand',
            'minute': 67,
          },
        ],
      },
      now: now,
    );
    expect(payload, isNotNull);
    expect(payload!.scoreLabel, '2 – 1');
    expect(payload.cssaScorers.map((s) => s.player).toList(), ['Dupont', 'Durand']);
    expect(payload.opponentScorers.map((s) => s.player).toList(), ['Martin']);
  });

  test('own goal counts for the other side', () {
    final cssa = MatchSheetShareService.scorersFromDoc({
      'team1': 'CSSA',
      'team2': 'Pau',
      'events': [
        {
          'type': 'own_goal',
          'team': 'Pau',
          'player': 'Lopez',
          'minute': 9,
        },
      ],
    }, cssa: true);
    expect(cssa.single.player, 'Lopez');
    expect(cssa.single.ownGoal, isTrue);
  });

  test('seen key is per match so stop-live does not re-open the card', () {
    expect(
      MatchSheetShareService.seenKey('m1'),
      'match_sheet_share_seen_m1',
    );
  });
}
