import 'package:dvcr/navigation/prono_championship_rollout.dart';
import 'package:dvcr/services/feature_flags_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    FeatureFlagsService.notifier.value = const {};
  });

  test('Pronos visibles si le flag est absent', () {
    FeatureFlagsService.notifier.value = const {};
    expect(PronoChampionshipRollout.isHubVisible, isTrue);
  });

  test('Pronos masqués seulement si le flag est false', () {
    FeatureFlagsService.notifier.value = const {
      'show_prono_championship_hub': false,
    };
    expect(PronoChampionshipRollout.isHubVisible, isFalse);
  });

  test('Pronos visibles si le flag est true', () {
    FeatureFlagsService.notifier.value = const {
      'show_prono_championship_hub': true,
    };
    expect(PronoChampionshipRollout.isHubVisible, isTrue);
  });
}
