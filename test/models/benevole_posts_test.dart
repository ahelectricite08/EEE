import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/benevole_posts.dart';

void main() {
  test('legacy type names normalize', () {
    expect(BenevolePosts.normalizeType('Équipe première'), BenevolePosts.typeR1);
    expect(BenevolePosts.normalizeType('Équipe réserve'), BenevolePosts.typeReserve);
    expect(
      BenevolePosts.normalizeType('Flammes Carolo'),
      BenevolePosts.typeFlammes,
    );
    expect(BenevolePosts.normalizeType('Autre'), BenevolePosts.typePerso);
    expect(
      BenevolePosts.inferTypeFromCompetition('Coupe de France'),
      BenevolePosts.typeCoupe,
    );
  });
}
