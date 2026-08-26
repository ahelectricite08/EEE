import 'package:flutter_test/flutter_test.dart';

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
}
