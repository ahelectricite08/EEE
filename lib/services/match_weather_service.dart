import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_model.dart';
import 'match_controller.dart';

/// Modes d’animation météo (codes WMO Open-Meteo → UI).
enum MatchWeatherMode {
  none,
  clear,
  sunClouds,
  clouds,
  rain,
  storm,
  snow,
  fog,
}

/// Météo du prochain match (carte home) — **prévision au jour / heure du match**.
///
/// - Cold start / resume → [refreshFromAppOpen] → Open-Meteo
/// - Écoute [MatchController] : refetch si match / ville change
/// - Prefs = affichage immédiat / fallback offline
/// - La carte featured **lit** [mode] uniquement (pas de requête HTTP)
class MatchWeatherService extends ChangeNotifier {
  MatchWeatherService._();
  static final instance = MatchWeatherService._();

  /// Local preview only — keep `null` for live weather.
  static const MatchWeatherMode? kDebugForceMode = null;

  static const Duration cacheTtl = Duration(minutes: 45);
  static const Duration openDebounce = Duration(seconds: 3);
  static const int forecastHorizonDays = 16;

  static const String _prefsMode = 'match_weather_mode_v2';
  static const String _prefsCity = 'match_weather_city_v2';
  static const String _prefsMatchDay = 'match_weather_day_v2';
  static const String _prefsAt = 'match_weather_at_v2';

  MatchWeatherMode _mode = MatchWeatherMode.none;
  String? _city;
  String? _matchDayKey;
  String? _lastFetchKey;
  DateTime? _fetchedAt;
  DateTime? _lastNetworkAttemptAt;
  Future<void>? _inFlight;
  bool _prefsHydrated = false;
  bool _matchListenerArmed = false;

  MatchWeatherMode? debugOverrideMode;

  MatchWeatherMode get mode => debugOverrideMode ?? _mode;
  String? get city => _city;

  void debugForceMode(MatchWeatherMode? mode) {
    assert(() {
      debugOverrideMode = mode;
      notifyListeners();
      return true;
    }());
  }

  /// Cold start + resume : vérifier Open-Meteo (debounce anti-spam).
  Future<void> refreshFromAppOpen() {
    if (kDebugMode && kDebugForceMode != null) {
      debugForceMode(kDebugForceMode);
    }
    _ensureMatchListener();

    final pending = _inFlight;
    if (pending != null) return pending;

    final last = _lastNetworkAttemptAt;
    if (last != null &&
        DateTime.now().difference(last) < openDebounce) {
      return Future.value();
    }

    final future = _refreshInternal(forceNetwork: true);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  void _ensureMatchListener() {
    if (_matchListenerArmed) return;
    _matchListenerArmed = true;
    void listener() {
      // Ville ajoutée / match featured changé → refetch (ignore debounce).
      unawaited(_refreshInternal(forceNetwork: false));
    }

    MatchController.instance.addListener(listener);
  }

  Future<void> _refreshInternal({required bool forceNetwork}) async {
    await _hydratePrefs();
    _ensureMatchListener();

    final match = _resolveFeaturedMatch();
    final queries = match == null ? const <String>[] : geocodeCandidates(match);
    if (match == null || queries.isEmpty) {
      if (_mode != MatchWeatherMode.none && _city == null) {
        _mode = MatchWeatherMode.none;
        notifyListeners();
      }
      return;
    }

    final dayKey = _dayKey(match.date);
    final fetchKey = '${match.id}|${queries.first}|$dayKey';
    if (!forceNetwork &&
        fetchKey == _lastFetchKey &&
        _mode != MatchWeatherMode.none &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < cacheTtl) {
      return;
    }

    // Évite les doubles appels parallèles (listener + resume).
    if (_inFlight != null && !forceNetwork) return;

    Future<void> run() async {
      _lastNetworkAttemptAt = DateTime.now();
      try {
        final next = await _fetchOpenMeteo(queries, match.date);
        _city = queries.first;
        _matchDayKey = dayKey;
        _lastFetchKey = fetchKey;
        _mode = next;
        _fetchedAt = DateTime.now();
        await _persist();
        notifyListeners();
      } catch (e) {
        debugPrint('[MatchWeather] fetch error: $e');
        if (_city != queries.first || _mode == MatchWeatherMode.none) {
          _city = queries.first;
          _matchDayKey = dayKey;
        }
        notifyListeners();
      }
    }

    if (_inFlight != null) {
      await _inFlight;
      if (!forceNetwork && fetchKey == _lastFetchKey) return;
    }
    final future = run();
    _inFlight = future.whenComplete(() => _inFlight = null);
    await future;
  }

  /// Prochain match Sedan (upcoming), sinon live / résultat récent utile.
  MatchModel? _resolveFeaturedMatch() {
    final ctrl = MatchController.instance;
    final now = DateTime.now();
    final sedanUpcoming = ctrl.upcoming.where((m) {
      return _isSedanMatch(m) &&
          m.status == MatchStatus.upcoming &&
          m.date.isAfter(now);
    });
    for (final m in sedanUpcoming) {
      if (geocodeCandidates(m).isNotEmpty) return m;
    }
    for (final m in [...ctrl.upcoming, ...ctrl.results]) {
      if (!_isSedanMatch(m)) continue;
      if (geocodeCandidates(m).isNotEmpty) return m;
    }
    return null;
  }

  static bool _isSedanMatch(MatchModel m) {
    final t1 = m.team1.toUpperCase();
    final t2 = m.team2.toUpperCase();
    return t1.contains('SEDAN') ||
        t1.contains('CSSA') ||
        t2.contains('SEDAN') ||
        t2.contains('CSSA');
  }

  /// Requêtes geocode : ville, lieu, hint équipe domicile (extérieur).
  /// « OCPAM » seul échoue — préférer « Charleville-Mézières ».
  static List<String> geocodeCandidates(MatchModel match) {
    final out = <String>[];
    void add(String? raw) {
      final t = (raw ?? '').trim();
      if (t.isEmpty) return;
      if (out.any((e) => e.toLowerCase() == t.toLowerCase())) return;
      // Sigles courts (OCPAM, CSSA…) → Open-Meteo ne géocode pas.
      final compact = t.replaceAll(RegExp(r'[\s\-.]'), '');
      if (RegExp(r'^[A-Za-z]{2,6}$').hasMatch(compact) &&
          compact.toUpperCase() == compact) {
        return;
      }
      out.add(t);
    }

    add(match.ville ?? match.city);
    add(match.lieu);
    if (!match.isSedanHome) {
      add(_cityHintFromTeam(match.team1));
    } else {
      add('Sedan');
    }
    return out;
  }

  static String? _cityHintFromTeam(String team) {
    var t = team.trim();
    if (t.isEmpty) return null;
    const drop = [
      'OLYMPIQUE',
      'FOOTBALL',
      'CLUB',
      'SPORTIF',
      'ASSOCIATION',
      'UNION',
      'ENTENTE',
      'STADE',
      'FC',
      'AS',
      'US',
      'CS',
      'CSO',
      'CSSA',
      'SC',
      'AC',
      'RC',
      'ES',
    ];
    for (final w in drop) {
      t = t.replaceAll(RegExp('\\b$w\\b', caseSensitive: false), ' ');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length < 3) return null;
    final compact = t.replaceAll(RegExp(r'[\s\-.]'), '');
    if (RegExp(r'^[A-Za-z]{2,6}$').hasMatch(compact) &&
        compact.toUpperCase() == compact) {
      return null;
    }
    return t;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _hydratePrefs() async {
    if (_prefsHydrated) return;
    _prefsHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(_prefsCity);
      final atRaw = prefs.getString(_prefsAt);
      final modeRaw = prefs.getString(_prefsMode);
      final day = prefs.getString(_prefsMatchDay);
      if (city == null || atRaw == null || modeRaw == null) return;
      final at = DateTime.tryParse(atRaw);
      if (at == null) return;
      if (DateTime.now().difference(at) > cacheTtl) return;
      _city = city;
      _matchDayKey = day;
      _fetchedAt = at;
      _mode = MatchWeatherMode.values.firstWhere(
        (m) => m.name == modeRaw,
        orElse: () => MatchWeatherMode.none,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMode, _mode.name);
      await prefs.setString(_prefsCity, _city ?? '');
      await prefs.setString(_prefsMatchDay, _matchDayKey ?? '');
      await prefs.setString(
        _prefsAt,
        (_fetchedAt ?? DateTime.now()).toIso8601String(),
      );
    } catch (_) {}
  }

  Future<MatchWeatherMode> _fetchOpenMeteo(
    List<String> queries,
    DateTime kickoff,
  ) async {
    final coords = await _geocodeFirst(queries);
    final lat = coords.$1;
    final lon = coords.$2;

    final now = DateTime.now();
    final day = _dayKey(kickoff);
    final daysAhead = DateTime(kickoff.year, kickoff.month, kickoff.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    final useCurrent = kickoff.isBefore(now) ||
        (daysAhead == 0 &&
            kickoff.difference(now).abs() < const Duration(hours: 2));

    if (useCurrent || daysAhead > forecastHorizonDays) {
      return modeFromWmo(await _fetchCurrentCode(lat, lon));
    }

    final wxUri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'hourly': 'weather_code',
        'daily': 'weather_code',
        'timezone': 'auto',
        'start_date': day,
        'end_date': day,
      },
    );
    final wxRes = await http.get(wxUri).timeout(const Duration(seconds: 8));
    if (wxRes.statusCode != 200) {
      throw StateError('weather ${wxRes.statusCode}');
    }
    final wxJson = jsonDecode(wxRes.body) as Map<String, dynamic>;
    final hourlyCode = _pickHourlyCode(wxJson, kickoff);
    if (hourlyCode != null) return modeFromWmo(hourlyCode);

    final daily = wxJson['daily'] as Map<String, dynamic>?;
    final dailyCodes = daily?['weather_code'] as List<dynamic>?;
    if (dailyCodes != null && dailyCodes.isNotEmpty) {
      final code = (dailyCodes.first as num?)?.toInt();
      if (code != null) return modeFromWmo(code);
    }

    return modeFromWmo(await _fetchCurrentCode(lat, lon));
  }

  Future<(double, double)> _geocodeFirst(List<String> queries) async {
    StateError? last;
    for (final q in queries) {
      try {
        return await _geocode(q);
      } catch (e) {
        last = e is StateError ? e : StateError('$e');
        debugPrint('[MatchWeather] geocode miss "$q": $e');
      }
    }
    throw last ?? StateError('geocode empty');
  }

  Future<(double, double)> _geocode(String city) async {
    final geoUri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': city,
        'count': '1',
        'language': 'fr',
        'format': 'json',
      },
    );
    final geoRes = await http.get(geoUri).timeout(const Duration(seconds: 8));
    if (geoRes.statusCode != 200) {
      throw StateError('geocode ${geoRes.statusCode}');
    }
    final geoJson = jsonDecode(geoRes.body) as Map<String, dynamic>;
    final results = geoJson['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw StateError('geocode empty for $city');
    }
    final first = results.first as Map<String, dynamic>;
    final lat = (first['latitude'] as num?)?.toDouble();
    final lon = (first['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      throw StateError('geocode coords');
    }
    return (lat, lon);
  }

  Future<int> _fetchCurrentCode(double lat, double lon) async {
    final wxUri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current': 'weather_code',
        'timezone': 'auto',
      },
    );
    final wxRes = await http.get(wxUri).timeout(const Duration(seconds: 8));
    if (wxRes.statusCode != 200) {
      throw StateError('weather current ${wxRes.statusCode}');
    }
    final wxJson = jsonDecode(wxRes.body) as Map<String, dynamic>;
    final current = wxJson['current'] as Map<String, dynamic>?;
    return (current?['weather_code'] as num?)?.toInt() ?? -1;
  }

  static int? _pickHourlyCode(Map<String, dynamic> wxJson, DateTime kickoff) {
    final hourly = wxJson['hourly'] as Map<String, dynamic>?;
    final times = hourly?['time'] as List<dynamic>?;
    final codes = hourly?['weather_code'] as List<dynamic>?;
    if (times == null || codes == null || times.isEmpty || codes.isEmpty) {
      return null;
    }
    final n = times.length < codes.length ? times.length : codes.length;
    var bestIdx = 0;
    var bestDiff = const Duration(days: 365);
    for (var i = 0; i < n; i++) {
      final raw = times[i]?.toString();
      if (raw == null || raw.isEmpty) continue;
      final t = DateTime.tryParse(raw);
      if (t == null) continue;
      final diff = t.difference(kickoff).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIdx = i;
      }
    }
    return (codes[bestIdx] as num?)?.toInt();
  }

  static MatchWeatherMode modeFromWmo(int code) {
    if (code == 0 || code == 1) return MatchWeatherMode.clear;
    if (code == 2) return MatchWeatherMode.sunClouds;
    if (code == 3) return MatchWeatherMode.clouds;
    if (code == 45 || code == 48) return MatchWeatherMode.fog;
    if (code >= 51 && code <= 67) return MatchWeatherMode.rain;
    if (code >= 80 && code <= 82) return MatchWeatherMode.rain;
    if (code >= 71 && code <= 77) return MatchWeatherMode.snow;
    if (code >= 85 && code <= 86) return MatchWeatherMode.snow;
    if (code >= 95 && code <= 99) return MatchWeatherMode.storm;
    if (code < 0) return MatchWeatherMode.none;
    return MatchWeatherMode.clouds;
  }
}
