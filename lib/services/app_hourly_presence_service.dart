import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visiteurs uniques par heure (ping léger au foreground).
///
/// Coût : **1 write max / user / heure** (souvent 0 grâce au cache local).
/// Pas de heartbeat continu.
class AppHourlyPresenceService {
  AppHourlyPresenceService._();
  static final instance = AppHourlyPresenceService._();

  static const _prefsKey = 'app_hourly_presence_last';

  final _db = FirebaseFirestore.instance;

  /// Clé locale `yyyyMMddHH` (fuseau appareil).
  static String hourKey([DateTime? at]) {
    final d = at ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}${two(d.hour)}';
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

  /// À appeler au démarrage / retour foreground si connecté.
  Future<void> ping() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final key = hourKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsKey) == key) return;

      final ref = _hours.doc(key).collection('uids').doc(uid);
      // set merge : 1 doc / user / heure — idempotent
      await ref.set({
        'uid': uid,
        'seenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Métadonnée heure (admin liste) — write rare
      await _hours.doc(key).set({
        'hourKey': key,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await prefs.setString(_prefsKey, key);
    } catch (_) {
      // Présence non critique
    }
  }

  /// Dernières [hours] heures avec comptage unique (admin).
  Future<List<AppHourlyPresenceBucket>> loadRecent({int hours = 24}) async {
    final now = DateTime.now();
    final keys = <String>[];
    for (var i = 0; i < hours; i++) {
      keys.add(hourKey(now.subtract(Duration(hours: i))));
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
