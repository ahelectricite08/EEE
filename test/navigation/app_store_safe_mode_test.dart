import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/navigation/app_store_safe_mode.dart';

void main() {
  group('AppStoreSafeMode', () {
    test('flag key is stable', () {
      expect(
        AppStoreSafeMode.flagKey,
        'hideMonetizationForAppStore',
      );
    });

    test('absent or false keeps the normal app', () {
      expect(AppStoreSafeMode.hidesUserMonetization(null), isFalse);
      expect(AppStoreSafeMode.hidesUserMonetization(const {}), isFalse);
      expect(
        AppStoreSafeMode.hidesUserMonetization(const {
          'hideMonetizationForAppStore': false,
        }),
        isFalse,
      );
    });

    test('true hides user-facing monetization', () {
      expect(
        AppStoreSafeMode.hidesUserMonetization(const {
          'hideMonetizationForAppStore': true,
        }),
        isTrue,
      );
    });
  });
}
