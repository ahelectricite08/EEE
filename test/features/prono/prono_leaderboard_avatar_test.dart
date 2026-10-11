import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/services/prono_social_service.dart';

void main() {
  test('GlobalLeaderboardRow inclut avatarUrl dans l’égalité', () {
    const a = GlobalLeaderboardRow(
      uid: 'u1',
      displayName: 'Axel',
      points: 12,
      exactScores: 2,
      rank: 1,
      avatarUrl: 'https://x.test/profile_avatars/a.png',
    );
    const b = GlobalLeaderboardRow(
      uid: 'u1',
      displayName: 'Axel',
      points: 12,
      exactScores: 2,
      rank: 1,
      avatarUrl: 'https://x.test/profile_avatars/a.png',
    );
    const c = GlobalLeaderboardRow(
      uid: 'u1',
      displayName: 'Axel',
      points: 12,
      exactScores: 2,
      rank: 1,
    );
    expect(a, b);
    expect(a == c, isFalse);
  });
}
