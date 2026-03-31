import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import 'match_service.dart';

class MatchController extends ChangeNotifier {
  MatchController._();
  static final instance = MatchController._();

  List<MatchModel> upcoming = [];
  List<MatchModel> results  = [];
  bool _initialized = false;
  bool _enrichedReceived = false;

  static const _keyUpcoming = 'cache_upcoming_v1';
  static const _keyResults  = 'cache_results_v1';

  /// Charge le cache local puis démarre les streams Firestore.
  /// À appeler dans main() avant runApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Charger immédiatement depuis le cache local (si dispo)
    await _loadFromCache();

    // 2. Abonnement rapide (brut, sans stats) → données fraîches rapidement
    MatchService.upcoming().listen((data) {
      if (!_enrichedReceived) {
        upcoming = data;
        notifyListeners();
        _saveUpcoming(data);
      }
    }, onError: (_) {});

    // 3. Abonnement enrichi (forme + rang) → complète les stats
    MatchService.upcomingEnriched().listen((data) {
      _enrichedReceived = true;
      upcoming = data;
      notifyListeners();
      _saveUpcoming(data);
    }, onError: (_) {});

    // 4. Résultats
    MatchService.results().listen((data) {
      results = data;
      notifyListeners();
      _saveResults(data);
    }, onError: (_) {});
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
        if (list.isNotEmpty) upcoming = list;
      }
      if (reJson != null) {
        final list = (jsonDecode(reJson) as List)
            .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) results = list;
      }
      if (upcoming.isNotEmpty || results.isNotEmpty) notifyListeners();
    } catch (e) {
      debugPrint('[MatchController] cache load error: $e');
    }
  }

  Future<void> _saveUpcoming(List<MatchModel> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUpcoming, jsonEncode(data.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _saveResults(List<MatchModel> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyResults, jsonEncode(data.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }
}
