import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/services/benevole_availability_service.dart';

void main() {
  test('uniquePostOptions drops duplicates and keeps current if missing', () {
    final out = BenevoleAvailabilityService.uniquePostOptions(
      allowed: const [
        'Cadreur plan large',
        'Cadreur plan large',
        'Réalisateur',
      ],
      current: 'Commentateur match 1',
      taken: const {'Réalisateur'},
    );
    expect(out, [
      'Commentateur match 1',
      'Cadreur plan large',
    ]);
  });

  test('filterPostsForUser Coupe uses 1ère list, unique', () {
    final out = BenevoleAvailabilityService.filterPostsForUser(
      authorized: const [
        'Cadreur plan large',
        'Cadreur plan large',
        'Vidéo (Réserve)',
      ],
      benevoleType: 'Coupe',
    );
    expect(out, ['Cadreur plan large']);
  });

  test('friendlyError never dumps cloud_firestore', () {
    expect(
      BenevoleAvailabilityService.friendlyError(
        '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
      ),
      isNot(contains('cloud_firestore')),
    );
    expect(
      BenevoleAvailabilityService.friendlyError(
        '[firebase_functions/invalid-argument] Poste non autorisé : Foo',
      ),
      'Ce poste n’est pas autorisé pour cet événement.',
    );
  });
}
