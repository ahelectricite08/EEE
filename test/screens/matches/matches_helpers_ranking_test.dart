import 'package:dvcr/screens/matches/matches_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('liveRankingDocsForSeason', () {
    test('filtre sur le libellé saison courant quand la poule est complète', () {
      final docs = [
        for (var i = 0; i < 14; i++)
          {'season': '2026-2027', 'team': 'A$i'},
        {'season': '2025-2026', 'team': 'OLD'},
      ];
      final picked = liveRankingDocsForSeason(
        docs,
        '2026-2027',
        (d) => d['season'],
      );
      expect(picked.length, 14);
      expect(picked.every((d) => d['season'] == '2026-2027'), isTrue);
    });

    test('si trop peu de lignes matchent, montre toute la poule', () {
      final docs = [
        for (var i = 0; i < 13; i++)
          {'season': '2025-2026', 'team': 'T$i'},
        {'season': '2026-2027', 'team': 'SEDAN ARDENNES CS'},
      ];
      final picked = liveRankingDocsForSeason(
        docs,
        '2026-2027',
        (d) => d['season'],
      );
      expect(picked.length, 14);
    });

    test('season null compte comme live', () {
      final docs = [
        for (var i = 0; i < 14; i++) {'season': null, 'team': 'T$i'},
      ];
      final picked = liveRankingDocsForSeason(
        docs,
        '2026-2027',
        (d) => d['season'],
      );
      expect(picked.length, 14);
    });
  });
}
