import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Visiteurs uniques par heure (foreground + scroll actif).
///
/// Coût : **1 write max / user / heure** (souvent 0 grâce au cache local).
/// Pas de heartbeat continu.
class AppHourlyPresenceService {
  AppHourlyPresenceService._();
  static final instance = AppHourlyPresenceService._();

  static const _prefsKey = 'app_hourly_presence_last';
  static const _parisLocationName = 'Europe/Paris';
  static const _scrollThrottle = Duration(seconds: 30);
  static bool _tzReady = false;

  final _db = FirebaseFirestore.instance;
  String? _memoryHourKey;
  DateTime? _lastScrollCheckAt;

  static void _ensureParisTz() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  static tz.Location get _paris {
    _ensureParisTz();
    return tz.getLocation(_parisLocationName);
  }

  /// Instant courant en heure de Paris (cohérent avec live `viewersByHour`).
  static tz.TZDateTime parisNow([DateTime? instant]) {
    return tz.TZDateTime.from(instant ?? DateTime.now(), _paris);
  }

  /// Clé `yyyyMMddHH` en heure de Paris (pas fuseau appareil / navigateur admin).
  static String hourKey([DateTime? at]) {
    final d = at == null ? tz.TZDateTime.now(_paris) : parisNow(at);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}${two(d.hour)}';
  }

  /// Préfixe jour civil Paris (`yyyyMMdd`) pour filtres admin.
  static String todayPrefix([DateTime? at]) {
    final key = hourKey(at);
    return key.length >= 8 ? key.substring(0, 8) : key;
  }

  static String formatHourLabel(String key) {
    if (key.length != 10) return key;
    final y = key.substring(0, 4);
    final m = key.substring(4, 6);
    final d = key.substring(6, 8);
    final h = key.substring(8, 10);
    return '$d/$m/$y · ${h}h';
  }

  CollectionReference<Map<String, dynamic>> get _hours =>
      _db.collection('app_hourly_visitors');

  /// Scroll actif — throttle 30 s + sortie immédiate si heure déjà en cache.
  void onScrollActivity() {
    final key = hourKey();
    if (_memoryHourKey == key) return;

    final now = DateTime.now();
    final last = _lastScrollCheckAt;
    if (last != null && now.difference(last) < _scrollThrottle) return;
    _lastScrollCheckAt = now;

    unawaited(pingIfNeeded(reason: 'scroll'));
  }

  /// À appeler au démarrage / retour foreground si connecté.
  Future<void> ping() => pingIfNeeded(reason: 'foreground');

  /// 1 write Firestore max / user / heure Paris (cache mémoire + prefs).
  Future<void> pingIfNeeded({String? reason}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final key = hourKey();
    if (_memoryHourKey == key) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsKey) == key) {
        _memoryHourKey = key;
        return;
      }

      final ref = _hours.doc(key).collection('uids').doc(uid);
      // set merge : 1 doc / user / heure — idempotent
      await ref.set({
        'uid': uid,
        'seenAt': FieldValue.serverTimestamp(),
        if (reason != null) 'reason': reason,
      }, SetOptions(merge: true));

      // Métadonnée heure (admin liste) — write rare
      await _hours.doc(key).set({
        'hourKey': key,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await prefs.setString(_prefsKey, key);
      _memoryHourKey = key;
    } catch (_) {
      // Présence non critique
    }
  }

  /// Dernières [hours] heures Paris avec comptage unique (admin).
  Future<List<AppHourlyPresenceBucket>> loadRecent({int hours = 24}) async {
    final keys = <String>[];
    var cursor = tz.TZDateTime.now(_paris);
    for (var i = 0; i < hours; i++) {
      keys.add(hourKey(cursor));
      cursor = cursor.subtract(const Duration(hours: 1));
    }

    final out = <AppHourlyPresenceBucket>[];
    // Lectures limitées : 1 count aggregation / heure (pas N docs uids).
    await Future.wait(keys.map((key) async {
      try {
        final agg = await _hours.doc(key).collection('uids').count().get();
        out.add(AppHourlyPresenceBucket(
          hourKey: key,
          uniqueVisitors: agg.count ?? 0,
        ));
      } catch (_) {
        out.add(AppHourlyPresenceBucket(hourKey: key, uniqueVisitors: 0));
      }
    }));

    out.sort((a, b) => b.hourKey.compareTo(a.hourKey));
    return out;
  }
}

class AppHourlyPresenceBucket {
  final String hourKey;
  final int uniqueVisitors;

  const AppHourlyPresenceBucket({
    required this.hourKey,
    required this.uniqueVisitors,
  });

  String get label => AppHourlyPresenceService.formatHourLabel(hourKey);
}
