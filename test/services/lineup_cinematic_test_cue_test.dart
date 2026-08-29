import 'dart:math';

import 'package:dvcr/models/lineup_cinematic_plan.dart';
import 'package:dvcr/services/lineup_cinematic_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TEST ping needs nonce + force, no freshness window', () {
    expect(LineupCinematicService.testNonce(null), isNull);
    expect(LineupCinematicService.isForceTest(null), isFalse);
    expect(
      LineupCinematicService.isForceTest({'nonce': 'abc'}),
      isFalse,
    );
    expect(
      LineupCinematicService.isForceTest({'force': true}),
      isFalse,
    );
    expect(
      LineupCinematicService.isForceTest({
        'nonce': '  99  ',
        'force': true,
      }),
      isTrue,
    );
    expect(
      LineupCinematicService.testNonce({'nonce': '  99  '}),
      '99',
    );
  });

  test('TEST doc id is dedicated app_config ping', () {
    expect(LineupCinematicService.testDocId, 'lineup_cinematic_test');
  });

  test('force TEST show is marked force (live non requis)', () {
    expect(LineupCinematicShow.randomTest(random: Random(1)).force, isTrue);
  });
}
