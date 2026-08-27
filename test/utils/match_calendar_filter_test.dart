import 'package:dvcr/models/fff_season_config.dart';
import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/utils/match_calendar_filter.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({
  required DateTime date,
  String? fffSeason,
  MatchStatus status = MatchStatus.upcoming,
  String team1 = 'CSSA',
  String team2 = 'AS Test',
  String competition = 'Régional 1',
}) {
  return MatchModel(
    id: 't-${date.toIso8601String()}',
    team1: team1,
    team2: team2,
    date: date,
    competition: competition,
    status: status,
    fffSeason: fffSeason,
  );
}

void main() {
  group('août 2026 vs config 2025-2026', () {
    final august = DateTime(2026, 8, 15, 18);
    final monthSeason =
        FffSeasonConfig.frenchFootballSeasonLabel(DateTime(2026, 8, 1));

    test('saison du mois = 2026-2027', () {
      expect(monthSeason, '2026-2027');
    });

    test('match août 2026 visible même si fffSeason = 2026-2027 et config 2025-2026',
        () {
      final m = _match(
        date: DateTime(2026, 8, 29, 18),
        fffSeason: '2026-2027',
      );
      expect(
        MatchCalendarFilter.belongsToSeason(
          m,
          displaySeason: monthSeason,
          activeSeasonLabel: FffSeasonConfig.defaults.seasonLabel,
        ),
        isTrue,
      );
      expect(
        MatchCalendarFilter.visibleInAppCalendar(
          m,
          displaySeason: monthSeason,
          activeSeasonLabel: '2025-2026',
        ),
        isTrue,
      );
    });

    test('match août 2026 visible même si fffSeason resté sur 2025-2026', () {
      final m = _match(date: august, fffSeason: '2025-2026');
      expect(
        MatchCalendarFilter.belongsToSeason(
          m,
          displaySeason: monthSeason,
          activeSeasonLabel: '2025-2026',
        ),
        isTrue,
      );
    });

    test('match août 2026 sans fffSeason visible pour la saison du mois', () {
      final m = _match(date: august);
      expect(
        MatchCalendarFilter.belongsToSeason(
          m,
          displaySeason: monthSeason,
        ),
        isTrue,
      );
    });

    test('filtre config 2025-2026 ne doit plus exclure août 2026 si on filtre le mois',
        () {
      final m = _match(
        date: august,
        fffSeason: '2026-2027',
        status: MatchStatus.finished,
      );
      final kept = MatchCalendarFilter.apply(
        [m],
        displaySeason: monthSeason,
        activeSeasonLabel: '2025-2026',
      );
      expect(kept, hasLength(1));
    });

    test('un match de mars 2026 n’appartient pas à 2026-2027', () {
      final m = _match(date: DateTime(2026, 3, 10), fffSeason: '2025-2026');
      expect(
        MatchCalendarFilter.belongsToSeason(
          m,
          displaySeason: '2026-2027',
        ),
        isFalse,
      );
    });
  });
}
