import 'package:dvcr/models/fff_season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frenchFootballSeasonLabel', () {
    test('août 2026 → 2026-2027', () {
      expect(
        FffSeasonConfig.frenchFootballSeasonLabel(DateTime(2026, 8, 27)),
        '2026-2027',
      );
    });

    test('juin 2026 → 2025-2026', () {
      expect(
        FffSeasonConfig.frenchFootballSeasonLabel(DateTime(2026, 6, 15)),
        '2025-2026',
      );
    });

    test('juillet 2027 → 2027-2028', () {
      expect(
        FffSeasonConfig.frenchFootballSeasonLabel(DateTime(2027, 7, 1)),
        '2027-2028',
      );
    });
  });

  group('arrivalSeason', () {
    test('préfère la saison calendaire même si 2025-2026 est en tête', () {
      expect(
        FffSeasonConfig.arrivalSeason(
          available: const ['2025-2026', '2026-2027'],
          configSeasonLabel: '2025-2026',
          now: DateTime(2026, 8, 27),
        ),
        '2026-2027',
      );
    });

    test('si la saison calendaire n’est pas dans la liste, prend la plus récente',
        () {
      expect(
        FffSeasonConfig.arrivalSeason(
          available: const ['2024-2025', '2025-2026'],
          configSeasonLabel: '2025-2026',
          now: DateTime(2026, 8, 27),
        ),
        '2025-2026',
      );
    });
  });

  test('seasonChips trie du plus récent au plus ancien', () {
    const cfg = FffSeasonConfig.defaults;
    final chips = FffSeasonConfig.seasonChips(
      cfg,
      const ['2025-2026', '2024-2025'],
      now: DateTime(2026, 8, 27),
    );
    expect(chips.first, '2026-2027');
    expect(chips.contains('2025-2026'), isTrue);
  });
}
