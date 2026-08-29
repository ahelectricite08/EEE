import 'package:dvcr/services/dugauguez_place_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TEST toggle is force flag only — no nonce ping', () {
    expect(DugauguezPlaceService.isForceTest(null), isFalse);
    expect(DugauguezPlaceService.isForceTest({'nonce': 'abc'}), isFalse);
    expect(DugauguezPlaceService.isForceTest({'force': false}), isFalse);
    expect(DugauguezPlaceService.isForceTest({'force': true}), isTrue);
  });

  test('TEST writes go to dedicated match id exempt from date window', () {
    expect(DugauguezPlaceService.testDocId, 'dugauguez_place_test');
    expect(DugauguezPlaceService.testMatchId, 'dugauguez_test');
  });
}
