import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/benevole_posts.dart';

void main() {
  // Match samedi 29 août 2026 18:00 → J-3 = mercredi 26 12:00, J-20 = 9 août.
  final kickoff = DateTime(2026, 8, 29, 18);

  test('opens at J-20 00:00 inclusive', () {
    expect(
      BenevolePosts.isFormOpenFor(
        kickoff,
        now: DateTime(2026, 8, 9),
      ),
      isTrue,
    );
    expect(
      BenevolePosts.isFormOpenFor(
        kickoff,
        now: DateTime(2026, 8, 8, 23, 59),
      ),
      isFalse,
    );
  });

  test('closes at J-3 12:00 exclusive', () {
    expect(
      BenevolePosts.isFormOpenFor(
        kickoff,
        now: DateTime(2026, 8, 26, 11, 59),
      ),
      isTrue,
    );
    expect(
      BenevolePosts.isFormOpenFor(
        kickoff,
        now: DateTime(2026, 8, 26, 12),
      ),
      isFalse,
    );
    expect(
      BenevolePosts.isFormOpenFor(
        kickoff,
        now: DateTime(2026, 8, 26, 12, 1),
      ),
      isFalse,
    );
  });

  test('visibility equals response window', () {
    final open = DateTime(2026, 8, 20, 10);
    final closed = DateTime(2026, 8, 26, 12);
    expect(BenevolePosts.isVisibleFor(kickoff, now: open), isTrue);
    expect(BenevolePosts.isFormOpenFor(kickoff, now: open), isTrue);
    expect(BenevolePosts.isVisibleFor(kickoff, now: closed), isFalse);
    expect(BenevolePosts.isFormOpenFor(kickoff, now: closed), isFalse);
  });

  test('old J-6 / J-4 days are still open (close is J-3 noon)', () {
    expect(
      BenevolePosts.isFormOpenFor(kickoff, now: DateTime(2026, 8, 23, 10)),
      isTrue,
    );
    expect(
      BenevolePosts.isFormOpenFor(kickoff, now: DateTime(2026, 8, 25, 10)),
      isTrue,
    );
  });
}
