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

  test('R2 FFF est off par défaut (pas d’id inventé)', () {
    expect(FffSeasonConfig.defaults.hasR2FffSource, isFalse);
    expect(FffSeasonConfig.defaults.fffR2CompetitionId, 0);
    expect(
      FffSeasonConfig.defaults.r2CompetitionDisplayName,
      'Régional 2',
    );
  });

  test('fromFirestoreData lit fffR2CompetitionId', () {
    final cfg = FffSeasonConfig.fromFirestoreData({
      'fffR2CompetitionId': 436258,
      'fffR2PhaseId': 1,
      'fffR2PouleId': 1,
    });
    expect(cfg.hasR2FffSource, isTrue);
    expect(cfg.fffR2CompetitionId, 436258);
  });

  test('r2CompetitionDisplayName est le nom de compétition, pas le club', () {
    expect(
      FffSeasonConfig.fromFirestoreData({
        'r2CompetitionDisplayName': 'Régional 2 · CS Sedan Ardennes',
      }).r2CompetitionDisplayName,
      'Régional 2',
    );
    expect(FffSeasonConfig.r2CompetitionTitle('R2'), 'Régional 2');
    expect(
      FffSeasonConfig.r2CompetitionTitle('Régional 2 Grand Est'),
      'Régional 2 Grand Est',
    );
  });
}
