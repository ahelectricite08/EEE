import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/benevole_posts.dart';

void main() {
  test('missing rights (legacy) see every type', () {
    for (final type in BenevolePosts.eventTypes) {
      expect(
        BenevolePosts.canSeeEventType(type: type, rights: null),
        isTrue,
      );
    }
  });

  test('empty rights see nothing unless admin', () {
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeR1,
        rights: const [],
      ),
      isFalse,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeR1,
        rights: const [],
        isAdmin: true,
      ),
      isTrue,
    );
  });

  test('R1 right opens R1 and Coupe, not Flammes / réserve / perso', () {
    const rights = [BenevolePosts.rightR1];
    expect(
      BenevolePosts.canSeeEventType(type: BenevolePosts.typeR1, rights: rights),
      isTrue,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeCoupe,
        rights: rights,
      ),
      isTrue,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeFlammes,
        rights: rights,
      ),
      isFalse,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeReserve,
        rights: rights,
      ),
      isFalse,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typePerso,
        rights: rights,
      ),
      isFalse,
    );
  });

  test('Flammes-only volunteer does not see R1', () {
    const rights = [BenevolePosts.rightFlammes];
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeFlammes,
        rights: rights,
      ),
      isTrue,
    );
    expect(
      BenevolePosts.canSeeEventType(type: BenevolePosts.typeR1, rights: rights),
      isFalse,
    );
  });

  test('optional coupe flag still opens Coupe if R1 is absent', () {
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeCoupe,
        rights: const [BenevolePosts.rightCoupe],
      ),
      isTrue,
    );
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typeR1,
        rights: const [BenevolePosts.rightCoupe],
      ),
      isFalse,
    );
  });

  test('extérieur right only for perso', () {
    const rights = [BenevolePosts.rightExterieur];
    expect(
      BenevolePosts.canSeeEventType(
        type: BenevolePosts.typePerso,
        rights: rights,
      ),
      isTrue,
    );
    expect(
      BenevolePosts.canSeeEventType(type: BenevolePosts.typeR1, rights: rights),
      isFalse,
    );
  });
}
