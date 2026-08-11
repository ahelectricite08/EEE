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
  clouds,
  rain,
  storm,
  snow,
  fog,
}

/// Météo du prochain match (carte home) — **fetch uniquement à l’ouverture app**.
///
/// - Cold start / resume → [refreshFromAppOpen]
/// - TTL mémoire + SharedPreferences (~45 min) → pas de spam réseau
/// - La carte featured **lit** [mode] uniquement (pas de requête HTTP)
class MatchWeatherService extends ChangeNotifier {
  MatchWeatherService._();
  static final instance = MatchWeatherService._();

  static const Duration cacheTtl = Duration(minutes: 45);
  static const String _prefsMode = 'match_weather_mode_v1';
  static const String _prefsCity = 'match_weather_city_v1';
  static const String _prefsAt = 'match_weather_at_v1';

  MatchWeatherMode _mode = MatchWeatherMode.none;
  String? _city;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;
  bool _prefsHydrated = false;
  bool _waitingForMatches = false;
  VoidCallback? _matchListener;

  /// Debug only: force a mode for local preview (null = live/cache).
  MatchWeatherMode? debugOverrideMode;

  MatchWeatherMode get mode => debugOverrideMode ?? _mode;
  String? get city => _city;

  /// Force a weather animation locally (debug / flutter run). Pass null to clear.
  void debugForceMode(MatchWeatherMode? mode) {
    assert(() {
      debugOverrideMode = mode;
      notifyListeners();
      return true;
    }());
  }

  /// Appelé au cold start (deferred) et au resume — une seule requête si TTL expiré.
  Future<void> refreshFromAppOpen() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _refreshInternal();
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _refreshInternal() async {
    await _hydratePrefs();

    final city = _resolveFeaturedCity();
    if (city == null || city.isEmpty) {
      if (!_waitingForMatches) {
        _waitingForMatches = true;
        _armMatchListenerOnce();
      }
      if (_mode != MatchWeatherMode.none && _city == null) {
        _mode = MatchWeatherMode.none;
        notifyListeners();
      }
      return;
    }

    _detachMatchListener();
    _waitingForMatches = false;

    if (_isFreshFor(city)) {
      if (_city != city) {
        _city = city;
        notifyListeners();
      }
      return;
    }

    try {
      final next = await _fetchOpenMeteo(city);
      _city = city;
      _mode = next;
      _fetchedAt = DateTime.now();
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('[MatchWeather] fetch error: $e');
      // Garde le cache précédent si dispo ; sinon pas d’animation.
      if (_city != city || _mode == MatchWeatherMode.none) {
        _city = city;
        // ne force pas none si on avait déjà un mode frais pour une autre ville
      }
      notifyListeners();
    }
  }

  void _armMatchListenerOnce() {
    _detachMatchListener();
    void listener() {
      final city = _resolveFeaturedCity();
      if (city == null || city.isEmpty) return;
      _detachMatchListener();
      unawaited(refreshFromAppOpen());
    }

    _matchListener = listener;
    MatchController.instance.addListener(listener);
  }

  void _detachMatchListener() {
    final l = _matchListener;
    if (l == null) return;
    MatchController.instance.removeListener(l);
    _matchListener = null;
  }

  String? _resolveFeaturedCity() {
    final ctrl = MatchController.instance;
    final now = DateTime.now();
    final sedanUpcoming = ctrl.upcoming.where((m) {
      final t1 = m.team1.toUpperCase();
      final t2 = m.team2.toUpperCase();
      final sedan = t1.contains('SEDAN') ||
          t1.contains('CSSA') ||
          t2.contains('SEDAN') ||
          t2.contains('CSSA');
      return sedan &&
          m.status == MatchStatus.upcoming &&
          m.date.isAfter(now);
    });
    for (final m in sedanUpcoming) {
      final city = m.resolveWeatherCity();
      if (city != null && city.isNotEmpty) return city;
    }
    // Live / résultats récents : première entrée Sedan utile
    for (final m in [...ctrl.upcoming, ...ctrl.results]) {
      final t1 = m.team1.toUpperCase();
      final t2 = m.team2.toUpperCase();
      final sedan = t1.contains('SEDAN') ||
          t1.contains('CSSA') ||
          t2.contains('SEDAN') ||
          t2.contains('CSSA');
      if (!sedan) continue;
      final city = m.resolveWeatherCity();
      if (city != null && city.isNotEmpty) return city;
    }
    return null;
  }

  bool _isFreshFor(String city) {
    if (_fetchedAt == null) return false;
    if ((_city ?? '').toLowerCase() != city.toLowerCase()) return false;
    return DateTime.now().difference(_fetchedAt!) <= cacheTtl;
  }

  Future<void> _hydratePrefs() async {
    if (_prefsHydrated) return;
    _prefsHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(_prefsCity);
      final atRaw = prefs.getString(_prefsAt);
      final modeRaw = prefs.getString(_prefsMode);
      if (city == null || atRaw == null || modeRaw == null) return;
      final at = DateTime.tryParse(atRaw);
      if (at == null) return;
      if (DateTime.now().difference(at) > cacheTtl) return;
      _city = city;
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
      await prefs.setString(
        _prefsAt,
        (_fetchedAt ?? DateTime.now()).toIso8601String(),
      );
    } catch (_) {}
  }

  Future<MatchWeatherMode> _fetchOpenMeteo(String city) async {
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
      throw StateError('weather ${wxRes.statusCode}');
    }
    final wxJson = jsonDecode(wxRes.body) as Map<String, dynamic>;
    final current = wxJson['current'] as Map<String, dynamic>?;
    final code = (current?['weather_code'] as num?)?.toInt() ?? -1;
    return modeFromWmo(code);
  }

  /// Mapping codes WMO → animation.
  static MatchWeatherMode modeFromWmo(int code) {
    if (code == 0 || code == 1) return MatchWeatherMode.clear;
    if (code == 2 || code == 3) return MatchWeatherMode.clouds;
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
