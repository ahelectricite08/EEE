import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/services/favorite_team_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({
  required String id,
  required DateTime date,
  String team1 = 'CSSA',
  String team2 = 'AS Test',
  MatchStatus status = MatchStatus.upcoming,
  String? fffSeason,
  String competition = 'Régional 1',
}) {
  return MatchModel(
    id: id,
    team1: team1,
    team2: team2,
    date: date,
    competition: competition,
    status: status,
    fffSeason: fffSeason,
  );
}

void main() {
  const season = '2026-2027';
  final now = DateTime(2026, 10, 11, 12);

  test('skip terminés, live, autre club, saison précédente', () {
    final selected = FavoriteTeamCalendarService.selectExportable(
      matches: [
        _match(
          id: 'done',
          date: DateTime(2026, 10, 18, 18),
          status: MatchStatus.finished,
        ),
        _match(
          id: 'live',
          date: DateTime(2026, 10, 11, 11),
          status: MatchStatus.live,
        ),
        _match(
          id: 'other',
          date: DateTime(2026, 10, 18, 18),
          team1: 'Reims Sainte-Anne',
          team2: 'Troyes',
        ),
        _match(
          id: 'old-season',
          date: DateTime(2025, 11, 8, 18),
          fffSeason: '2025-2026',
        ),
        _match(
          id: 'ok',
          date: DateTime(2026, 10, 18, 18),
          team2: 'Sarreguemines FC',
        ),
      ],
      favoriteTeam: 'CS Sedan Ardennes',
      seasonLabel: season,
      now: now,
    );
    expect(selected.map((m) => m.id), ['ok']);
  });

  test('équipe non-Sedan : uniquement ses fiches, R2 ignoré si absent', () {
    final selected = FavoriteTeamCalendarService.selectExportable(
      matches: [
        _match(
          id: 'r1',
          date: DateTime(2026, 11, 2, 15),
          team1: 'Reims Sainte-Anne',
          team2: 'Épernay',
        ),
        _match(
          id: 'sedan-r2',
          date: DateTime(2026, 11, 2, 15),
          team1: 'CSSA',
          team2: 'Réserve X',
          competition: 'Régional 2',
        ),
      ],
      favoriteTeam: 'Reims Sainte-Anne',
      seasonLabel: season,
      now: now,
    );
    expect(selected.map((m) => m.id), ['r1']);
  });

  test('minuit (heure inconnue) un jour futur → exportable', () {
    final selected = FavoriteTeamCalendarService.selectExportable(
      matches: [
        _match(id: 'tba', date: DateTime(2026, 11, 8)),
      ],
      favoriteTeam: 'CSSA',
      seasonLabel: season,
      now: now,
    );
    expect(selected, hasLength(1));
  });

  test('jour passé même si statut upcoming → ignoré', () {
    final selected = FavoriteTeamCalendarService.selectExportable(
      matches: [
        _match(id: 'stale', date: DateTime(2026, 10, 4, 18)),
      ],
      favoriteTeam: 'CSSA',
      seasonLabel: season,
      now: now,
    );
    expect(selected, isEmpty);
  });

  test('messages FR', () {
    expect(
      FavoriteTeamCalendarService.successMessage(3),
      contains('3 matchs ajoutés au calendrier.'),
    );
    expect(
      FavoriteTeamCalendarService.successMessage(3),
      contains('doublons'),
    );
    expect(
      FavoriteTeamCalendarService.emptyMessage('CSSA'),
      contains('CSSA'),
    );
  });

  test('fenêtre fetch = aujourd’hui → 1er juillet saison suivante', () {
    expect(
      FavoriteTeamCalendarService.fetchStart(now: now, seasonLabel: season),
      DateTime(2026, 10, 11),
    );
    expect(
      FavoriteTeamCalendarService.seasonEndExclusive(season),
      DateTime(2027, 7, 1),
    );
  });
}
