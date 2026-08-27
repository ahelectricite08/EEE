import 'package:dvcr/screens/profile/match_rating_social_visual.dart';
import 'package:dvcr/services/match_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 27, 20, 0);

  group('Note du match social window', () {
    test('opens from liveEndedAt for 48 hours', () {
      final ended = now.subtract(const Duration(hours: 47, minutes: 59));
      expect(
        MatchRatingService.isWithinSocialVisualWindow(ended, now),
        isTrue,
      );
    });

    test('hides after 48 hours', () {
      final ended = now.subtract(const Duration(hours: 48, minutes: 1));
      expect(
        MatchRatingService.isWithinSocialVisualWindow(ended, now),
        isFalse,
      );
    });

    test('missing liveEndedAt is not downloadable', () {
      expect(
        MatchRatingService.isWithinSocialVisualWindow(null, now),
        isFalse,
      );
    });

    test('hasSocialVisual requires a real note and the 48h window', () {
      expect(
        MatchRatingService.hasSocialVisual({
          'liveEndedAt': now.subtract(const Duration(hours: 2)),
          'matchRatingAverage': 7.4,
          'matchRatingTotal': 128,
        }, now),
        isTrue,
      );
      expect(
        MatchRatingService.hasSocialVisual({
          'liveEndedAt': now.subtract(const Duration(hours: 2)),
          'matchRatingAverage': 0,
          'matchRatingTotal': 0,
        }, now),
        isFalse,
      );
      expect(
        MatchRatingService.hasSocialVisual({
          'liveEndedAt': now.subtract(const Duration(hours: 50)),
          'matchRatingAverage': 7.4,
          'matchRatingTotal': 128,
        }, now),
        isFalse,
      );
    });

    test('remaining label stays punchy', () {
      expect(
        MatchRatingService.socialVisualRemainingLabel(
          const Duration(hours: 36),
        ),
        'Encore 36 h',
      );
      expect(
        MatchRatingService.socialVisualRemainingLabel(
          const Duration(minutes: 12),
        ),
        'Encore 12 min',
      );
    });
  });

  test('payload reads score, note and liveEndedAt from the match doc', () {
    final payload = MatchRatingSocialPayload.fromDoc(
      'm1',
      {
        'team1': 'CSSA',
        'team2': 'Pau',
        'score1': 2,
        'score2': 1,
        'date': now.subtract(const Duration(hours: 3)),
        'liveEndedAt': now.subtract(const Duration(hours: 1)),
        'matchRatingAverage': 7.4,
        'matchRatingTotal': 12,
        'matchRatingSum': 89,
        'competition': 'N3',
      },
      now: now,
    );
    expect(payload, isNotNull);
    expect(payload!.team1, 'CSSA');
    expect(payload.scoreLabel, '2 – 1');
    expect(payload.rating.averageLabel, '7.4');
    expect(payload.rating.verdictLabel, 'Pas mal du tout');
  });
}
