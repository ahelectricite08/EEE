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
        status: MatchStatus.finished,
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

    test('poule hors Sedan masquée par défaut, visible sur le calendrier poule', () {
      final j6 = _match(
        date: DateTime(2026, 10, 4, 15, 0),
        team1: 'Reims Sainte-Anne',
        team2: 'Étain Buzy',
        status: MatchStatus.finished,
      );
      expect(
        MatchCalendarFilter.visibleInAppCalendar(
          j6,
          displaySeason: monthSeason,
        ),
        isFalse,
      );
      expect(
        MatchCalendarFilter.visibleInAppCalendar(
          j6,
          displaySeason: monthSeason,
          requireSedan: false,
          hideStaleUpcoming: false,
        ),
        isTrue,
      );
      expect(
        MatchCalendarFilter.apply(
          [j6],
          displaySeason: monthSeason,
          hideStaleUpcoming: false,
          requireSedan: false,
        ),
        hasLength(1),
      );
    });

    test('journée passée encore upcoming → résultats, pas à venir', () {
      final now = DateTime(2026, 10, 8, 1, 30);
      final j6 = _match(
        date: DateTime(2026, 10, 4, 15, 0),
        team1: 'Reims Sainte-Anne',
        team2: 'Étain Buzy',
        status: MatchStatus.upcoming,
      );
      expect(MatchCalendarFilter.belongsInResults(j6, now: now), isTrue);
      expect(MatchCalendarFilter.belongsInUpcoming(j6, now: now), isFalse);
      expect(MatchCalendarFilter.isStaleUpcoming(j6, now: now), isTrue);
    });

    test('match à venir reste dans l’onglet calendrier à venir', () {
      final now = DateTime(2026, 10, 8, 1, 30);
      final next = _match(
        date: DateTime(2026, 10, 18, 18, 0),
        status: MatchStatus.upcoming,
      );
      expect(MatchCalendarFilter.belongsInUpcoming(next, now: now), isTrue);
      expect(MatchCalendarFilter.belongsInResults(next, now: now), isFalse);
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

  group('Admin Live picker', () {
    final kickoff = DateTime(2026, 9, 12, 18);

    test('Sedan / CSSA / CS Sedan Ardennes → visibles', () {
      for (final name in ['Sedan', 'CSSA', 'CS Sedan Ardennes', 'SEDAN ARDENNES CS']) {
        expect(
          MatchCalendarFilter.isLivePickerCandidate(
            _match(date: kickoff, team1: name, team2: 'FC Test'),
          ),
          isTrue,
          reason: name,
        );
        expect(
          MatchCalendarFilter.isLivePickerCandidate(
            _match(date: kickoff, team1: 'FC Test', team2: name),
          ),
          isTrue,
          reason: 'away $name',
        );
      }
    });

    test('autre club vs autre club → masqué, sauf manuel', () {
      final league = _match(
        date: kickoff,
        team1: 'Reims Sainte-Anne',
        team2: 'Étain Buzy',
      );
      expect(MatchCalendarFilter.involvesSedan(league), isFalse);
      expect(MatchCalendarFilter.isLivePickerCandidate(league), isFalse);

      final manual = MatchModel(
        id: 'manual-1',
        team1: 'Reims Sainte-Anne',
        team2: 'Étain Buzy',
        date: kickoff,
        competition: 'Régional 1',
        status: MatchStatus.upcoming,
        manual: true,
      );
      expect(MatchCalendarFilter.isLivePickerCandidate(manual), isTrue);
    });
  });
}
