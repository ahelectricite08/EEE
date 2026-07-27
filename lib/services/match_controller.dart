import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fff_season_config.dart';
import '../models/match_model.dart';
import '../utils/match_calendar_filter.dart';
import 'match_service.dart';
import 'match_stats_service.dart';
import 'season_config_service.dart';

class MatchController extends ChangeNotifier {
  MatchController._();
  static final instance = MatchController._();

  List<MatchModel> upcoming = [];
  List<MatchModel> results = [];

  bool _initialized = false;
  bool _enrichedReceived = false;
  bool _resultsEnrichedReceived = false;
  Future<void>? _initFuture;
  Future<void>? _refreshFuture;

  StreamSubscription<List<MatchModel>>? _upcomingSub;
  StreamSubscription<List<MatchModel>>? _upcomingEnrichedSub;
  StreamSubscription<List<MatchModel>>? _resultsSub;
  StreamSubscription<List<MatchModel>>? _resultsEnrichedSub;
  StreamSubscription<FffSeasonConfig>? _seasonSub;

  String _seasonLabel = FffSeasonConfig.defaults.seasonLabel;

  static const _keyUpcoming = 'cache_upcoming_v4_sedan';
  static const _keyResults = 'cache_results_v4_sedan_any_season';

  Future<void> init() {
    final pending = _initFuture;
    if (pending != null) {
      return pending;
    }
    final future = _initInternal();
    _initFuture = future.catchError((Object error) {
      _initFuture = null;
      throw error;
    });
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      _seasonLabel = (await SeasonConfigService.getCurrent()).seasonLabel;
    } catch (_) {}

    await _loadFromCache();

    await _upcomingSub?.cancel();
    await _upcomingEnrichedSub?.cancel();
    await _resultsSub?.cancel();
    await _resultsEnrichedSub?.cancel();
    await _seasonSub?.cancel();

    _seasonSub = SeasonConfigService.stream().listen((cfg) {
      final next = cfg.seasonLabel;
      if (next == _seasonLabel) return;
      _seasonLabel = next;
      _replaceUpcoming(_filterUpcoming(upcoming), save: true);
      // Résultats : pas de filtre saison — garder les derniers matchs terminés Sedan.
      _replaceResults(_filterResults(results), save: true);
    });

    _upcomingSub = MatchService.upcoming().listen(
      (data) {
        if (_enrichedReceived) {
          return;
        }
        _replaceUpcoming(_filterUpcoming(data));
      },
      onError: (_) {},
    );

    _upcomingEnrichedSub = MatchService.upcomingEnriched().listen(
      (data) {
        _enrichedReceived = true;
        _replaceUpcoming(_filterUpcoming(data), save: true);
      },
      onError: (_) {},
    );

    _resultsSub = MatchService.results().listen(
      (data) {
        if (_resultsEnrichedReceived) {
          return;
        }
        _replaceResults(_filterResults(data));
      },
      onError: (_) {},
    );

    _resultsEnrichedSub = MatchService.resultsEnriched().listen(
      (data) {
        _resultsEnrichedReceived = true;
        _replaceResults(_filterResults(data), save: true);
      },
      onError: (_) {},
    );
  }

  List<MatchModel> _filterUpcoming(List<MatchModel> data) {
    return MatchCalendarFilter.apply(
      data,
      displaySeason: _seasonLabel,
      activeSeasonLabel: _seasonLabel,
    );
  }

  List<MatchModel> _filterResults(List<MatchModel> data) {
    return MatchCalendarFilter.applyFinishedAcrossSeasons(data);
  }

  Future<void> forceRefresh() {
    final pending = _refreshFuture;
    if (pending != null) {
      return pending;
    }

    final future = _forceRefreshInternal();
    _refreshFuture = future.whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<void> _forceRefreshInternal() async {
    MatchStatsService.clearCache();
    _enrichedReceived = false;
    _resultsEnrichedReceived = false;

    try {
      final fresh = await MatchService.upcomingEnriched().first;
      final freshResults = await MatchService.resultsEnriched().first;
      _enrichedReceived = true;
      _resultsEnrichedReceived = true;
      _replaceUpcoming(_filterUpcoming(fresh), save: true);
      _replaceResults(_filterResults(freshResults), save: true);
    } catch (e) {
      debugPrint('[MatchController] forceRefresh error: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final upJson = prefs.getString(_keyUpcoming);
      final reJson = prefs.getString(_keyResults);
      if (upJson != null) {
        final list = (jsonDecode(upJson) as List)
            .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          upcoming = _filterUpcoming(list);
        }
      }
      if (reJson != null) {
        final list = (jsonDecode(reJson) as List)
            .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          results = _filterResults(list);
        }
      }
      if (upcoming.isNotEmpty || results.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MatchController] cache load error: $e');
    }
  }

  void _replaceUpcoming(List<MatchModel> data, {bool save = false}) {
    if (_sameMatches(upcoming, data)) {
      if (save) {
        unawaited(_saveUpcoming(data));
      }
      return;
    }
    upcoming = data;
    if (save) {
      unawaited(_saveUpcoming(data));
    }
    notifyListeners();
  }

  void _replaceResults(List<MatchModel> data, {bool save = false}) {
    if (_sameMatches(results, data)) {
      if (save) {
        unawaited(_saveResults(data));
      }
      return;
    }
    results = data;
    if (save) {
      unawaited(_saveResults(data));
    }
    notifyListeners();
  }

  bool _sameMatches(List<MatchModel> left, List<MatchModel> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!_sameMatch(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }

  bool _sameMatch(MatchModel a, MatchModel b) {
    return mapEquals(a.toJson(), b.toJson());
  }

  Future<void> _saveUpcoming(List<MatchModel> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyUpcoming,
        jsonEncode(data.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _saveResults(List<MatchModel> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyResults,
        jsonEncode(data.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }
}
