import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/benevole_posts.dart';

void main() {
  test('équipe 1ère list is exact (R1 and Coupe share it)', () {
    const expected = [
      'Cadreur plan large',
      'Cadreur plan serré',
      'Cadreur 16m stabi',
      'Cadreur 16m',
      'Cadreur bord terrain stabi',
      'Cadreur bord terrain',
      'Réalisateur',
      'Responsable Post Prod',
      "Chef d'édition – Ralenti",
      'Commentateur match 1',
      'Commentateur match 2',
      'Commentateur bord terrain',
      'Consultant bord terrain et tribune',
      'Présentateur avant/mi-temps/après match',
      'Statisticien 1',
      'Statisticien 2',
      'Chef régisseur',
      'Régisseur 1 (tribune)',
      'Régisseur 2 (camion/édition)',
      'Régisseur 3 (pelouse 1)',
      'Régisseur 4 (pelouse 2)',
      'Community Manager',
      'Responsable buvette 1',
      'Responsable buvette 2',
      'Responsable buvette 3',
      'Responsable buvette 4',
    ];
    expect(BenevolePosts.premiere, expected);
    expect(BenevolePosts.forEventType(BenevolePosts.typeR1), expected);
    expect(BenevolePosts.forEventType(BenevolePosts.typeCoupe), expected);
    expect(BenevolePosts.forEventType(BenevolePosts.typePerso), expected);
    expect(BenevolePosts.premiere, isNot(contains('Autre')));
    expect(BenevolePosts.premiere, isNot(contains('Chroniqueur')));
    expect(BenevolePosts.premiere, isNot(contains('Buvette local')));
    expect(BenevolePosts.premiere, isNot(contains('Vidéo')));
    expect(BenevolePosts.premiere, isNot(contains('Régisseur 3 (pelouse)')));
  });

  test('réserve list is exact', () {
    expect(BenevolePosts.reserve, [
      'Vidéo (Réserve)',
      'Commentateur (Réserve)',
    ]);
    expect(BenevolePosts.forEventType(BenevolePosts.typeReserve), [
      'Vidéo (Réserve)',
      'Commentateur (Réserve)',
    ]);
  });

  test('Flammes list is exact', () {
    expect(BenevolePosts.flammes, [
      'Cadreur plan large',
      'Cadreur plan serré',
      'Cadreur 16m stabi',
      'Cadreur 16m',
      'Réalisateur',
      "Chef d'édition – Ralenti",
      'Régisseur 1 (tribune)',
    ]);
    expect(
      BenevolePosts.forEventType(BenevolePosts.typeFlammes),
      BenevolePosts.flammes,
    );
  });

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
