import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/services/match_weather_service.dart';

void main() {
  test('WMO codes map to soleil / pluie / orage / brouillard', () {
    expect(MatchWeatherService.modeFromWmo(0), MatchWeatherMode.clear);
    expect(MatchWeatherService.modeFromWmo(1), MatchWeatherMode.clear);
    expect(MatchWeatherMode.clear.labelFr, 'Soleil');

    expect(MatchWeatherService.modeFromWmo(61), MatchWeatherMode.rain);
    expect(MatchWeatherService.modeFromWmo(80), MatchWeatherMode.rain);
    expect(MatchWeatherMode.rain.labelFr, 'Pluie');

    expect(MatchWeatherService.modeFromWmo(95), MatchWeatherMode.storm);
    expect(MatchWeatherService.modeFromWmo(99), MatchWeatherMode.storm);
    expect(MatchWeatherMode.storm.labelFr, 'Orage');

    expect(MatchWeatherService.modeFromWmo(45), MatchWeatherMode.fog);
    expect(MatchWeatherService.modeFromWmo(48), MatchWeatherMode.fog);
    expect(MatchWeatherMode.fog.labelFr, 'Brouillard');
  });

  test('unknown / invalid codes stay honest', () {
    expect(MatchWeatherService.modeFromWmo(-1), MatchWeatherMode.none);
    expect(MatchWeatherService.modeFromWmo(3).labelFr, 'Nuageux');
  });

  test('forecast horizon is match day, not now+16+', () {
    final now = DateTime(2026, 8, 22, 10);
    expect(
      MatchWeatherService.isWithinForecastHorizon(
        DateTime(2026, 8, 25, 18),
        now: now,
      ),
      isTrue,
    );
    expect(
      MatchWeatherService.isWithinForecastHorizon(
        DateTime(2026, 9, 20, 18),
        now: now,
      ),
      isFalse,
    );
    expect(
      MatchWeatherService.isWithinForecastHorizon(
        DateTime(2026, 8, 21, 18),
        now: now,
      ),
      isFalse,
    );
  });

  test('fiche météo = prochain CSSA, dès la prévision, pas H-4', () {
    MatchModel m(
      String id,
      DateTime date,
      MatchStatus status, {
      String team1 = 'CSSA',
    }) =>
        MatchModel(
          id: id,
          team1: team1,
          team2: 'Visiteur',
          date: date,
          competition: 'N2',
          status: status,
        );

    final nextKick = DateTime(2026, 8, 28, 19, 30);
    final laterKick = DateTime(2026, 9, 12, 19, 30);
    final next = m('next', nextKick, MatchStatus.upcoming);
    final later = m('later', laterKick, MatchStatus.upcoming);
    final finished = m('old', DateTime(2026, 8, 14, 20), MatchStatus.finished);
    final catalog = [next, later, finished];
    final morningOf = DateTime(2026, 8, 28, 0, 5);

    expect(
      MatchWeatherService.isMatchDayWindow(
        next,
        now: morningOf,
        catalog: catalog,
      ),
      isTrue,
    );
    expect(
      MatchWeatherService.isMatchDayWindow(
        later,
        now: morningOf,
        catalog: catalog,
      ),
      isFalse,
    );
    expect(
      MatchWeatherService.isMatchDayWindow(
        finished,
        now: morningOf,
        catalog: catalog,
      ),
      isFalse,
    );
    expect(
      MatchWeatherService.isMatchDayWindow(
        m('live', nextKick, MatchStatus.live),
        now: DateTime(2026, 8, 28, 21, 10),
        catalog: [m('live', nextKick, MatchStatus.live), later],
      ),
      isTrue,
    );
    expect(
      MatchWeatherService.isMatchDayWindow(
        next,
        now: DateTime(2026, 8, 20, 10),
        catalog: catalog,
      ),
      isTrue,
    );
    expect(
      MatchWeatherService.isMatchDayWindow(
        m('far', DateTime(2026, 9, 20, 18), MatchStatus.upcoming),
        now: DateTime(2026, 8, 22, 10),
        catalog: [
          m('far', DateTime(2026, 9, 20, 18), MatchStatus.upcoming),
        ],
      ),
      isFalse,
    );
  });

  test('pickNextSedanMatch = live CSSA sinon le plus proche upcoming', () {
    final now = DateTime(2026, 8, 22, 10);
    final soon = MatchModel(
      id: 'soon',
      team1: 'CSSA',
      team2: 'Rouen',
      date: DateTime(2026, 8, 28, 19, 30),
      competition: 'N2',
      status: MatchStatus.upcoming,
    );
    final far = MatchModel(
      id: 'far',
      team1: 'CSSA',
      team2: 'Paris',
      date: DateTime(2026, 9, 12, 19, 30),
      competition: 'N2',
      status: MatchStatus.upcoming,
    );
    final other = MatchModel(
      id: 'other',
      team1: 'Rouen',
      team2: 'Paris',
      date: DateTime(2026, 8, 23, 18),
      competition: 'N2',
      status: MatchStatus.upcoming,
    );
    expect(
      MatchWeatherService.pickNextSedanMatch(
        [far, soon, other],
        now: now,
      )?.id,
      'soon',
    );

    final live = MatchModel(
      id: 'live',
      team1: 'CSSA',
      team2: 'Quevilly',
      date: DateTime(2026, 8, 22, 19),
      competition: 'N2',
      status: MatchStatus.live,
    );
    expect(
      MatchWeatherService.pickNextSedanMatch(
        [soon, live],
        now: now,
      )?.id,
      'live',
    );
  });

  test('club lines: doudoune / casquette / K-way / orage / neige', () {
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.clouds, 8),
      'Sort le doudoune',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.clear, 22),
      'Casquette',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.rain, 14),
      'Sors le K-way',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.storm, 18),
      'Ça va péter',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.snow, 0),
      'Dugauguez sous la neige',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.clear, 28),
      'Ça va cramer',
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.clouds, 16),
      isNull,
    );
    expect(
      MatchWeatherService.clubLineFor(MatchWeatherMode.fog, 10),
      isNull,
    );
  });
}
