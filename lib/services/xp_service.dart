import 'package:cloud_firestore/cloud_firestore.dart';

/// Source unique XP / niveaux — alignée sur `app_settings/xp_config` + `xp_levels`
/// et `users.xp` / `users.level` (Cloud Functions `awardXp`).
class XpService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _levelsRef =>
      _db.collection('app_settings').doc('xp_levels');

  static DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('app_settings').doc('xp_config');

  /// Paliers par défaut (identiques admin + Cloud Functions).
  static const defaultLevels = [
    {'level': 1, 'name': 'Recrue', 'xpRequired': 0, 'imageUrl': ''},
    {'level': 2, 'name': 'Fan', 'xpRequired': 150, 'imageUrl': ''},
    {'level': 3, 'name': 'Supporter', 'xpRequired': 400, 'imageUrl': ''},
    {'level': 4, 'name': 'Ultra', 'xpRequired': 900, 'imageUrl': ''},
    {'level': 5, 'name': 'Capitaine', 'xpRequired': 1800, 'imageUrl': ''},
    {'level': 6, 'name': 'Legende', 'xpRequired': 3500, 'imageUrl': ''},
  ];

  static Stream<DocumentSnapshot<Map<String, dynamic>>> levelsDocStream() =>
      _levelsRef.snapshots();

  static Stream<DocumentSnapshot<Map<String, dynamic>>> configDocStream() =>
      _configRef.snapshots();

  /// Parse `levels` depuis `app_settings/xp_levels` ou legacy `app_config/prono_social`.
  static List<Map<String, dynamic>> parseLevels(Map<String, dynamic>? doc) {
    final raw = doc?['levels'];
    if (raw is! List || raw.isEmpty) {
      return defaultLevels.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final list = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        list.add(e);
      } else if (e is Map) {
        list.add(Map<String, dynamic>.from(e));
      }
    }
    list.sort(
      (a, b) => ((a['xpRequired'] as num?) ?? 0).compareTo(
        (b['xpRequired'] as num?) ?? 0,
      ),
    );
    for (var i = 0; i < list.length; i++) {
      list[i]['level'] = i + 1;
    }
    return list;
  }

  /// XP affiché partout : uniquement `users.xp` (plus de calcul depuis stats prono).
  static int displayXp(Map<String, dynamic>? userDoc) =>
      (userDoc?['xp'] as num?)?.toInt() ?? 0;

  /// Même algorithme que `_computeLevel` côté Cloud Functions.
  static int levelFromXp(int xp, {List<Map<String, dynamic>>? levels}) {
    final lvls = levels ?? parseLevels(null);
    var current = 1;
    for (final lvl in lvls) {
      final req = (lvl['xpRequired'] as num?)?.toInt() ?? 0;
      if (xp >= req) {
        current = (lvl['level'] as num?)?.toInt() ?? current;
      }
    }
    return current;
  }

  static Map<String, dynamic>? _levelRowForXp(
    int xp,
    List<Map<String, dynamic>> levels,
  ) {
    Map<String, dynamic>? current;
    for (final lvl in levels) {
      final req = (lvl['xpRequired'] as num?)?.toInt() ?? 0;
      if (xp >= req) current = lvl;
    }
    return current;
  }

  static String levelLabelFromXp(int xp, {List<Map<String, dynamic>>? levels}) {
    final lvls = levels ?? parseLevels(null);
    return _levelRowForXp(xp, lvls)?['name'] as String? ??
        (lvls.isNotEmpty ? lvls.first['name'] as String? ?? 'Recrue' : 'Recrue');
  }

  /// Tampon supporter (profil / chat) : palier XP une fois gravé, sinon « Supporter ».
  ///
  /// 0 XP = pas encore de palier. Ensuite les noms admin / défaut
  /// (Recrue, Fan, Supporter, Ultra, Capitaine, Legende).
  static String supporterStampLabel(
    int xp, {
    List<Map<String, dynamic>>? levels,
  }) {
    if (xp <= 0) return 'Supporter';
    final lvls =
        (levels == null || levels.isEmpty) ? parseLevels(null) : levels;
    final name = levelLabelFromXp(xp, levels: lvls).trim();
    return name.isEmpty ? 'Supporter' : name;
  }

  static String? levelImageFromXp(int xp, {List<Map<String, dynamic>>? levels}) {
    final url =
        _levelRowForXp(xp, levels ?? parseLevels(null))?['imageUrl'] as String? ??
            '';
    return url.isNotEmpty ? url : null;
  }

  static int? xpToNextLevel(int xp, {List<Map<String, dynamic>>? levels}) {
    final lvls = levels ?? parseLevels(null);
    for (final lvl in lvls) {
      final req = (lvl['xpRequired'] as num?)?.toInt() ?? 0;
      if (xp < req) return req - xp;
    }
    return null;
  }

  static double progressInLevel(int xp, {List<Map<String, dynamic>>? levels}) {
    final lvls = levels ?? parseLevels(null);
    var floorXp = 0;
    var ceilXp = -1;
    for (final lvl in lvls) {
      final req = (lvl['xpRequired'] as num?)?.toInt() ?? 0;
      if (xp >= req) floorXp = req;
      if (xp < req && ceilXp == -1) ceilXp = req;
    }
    if (ceilXp == -1) return 1.0;
    final span = ceilXp - floorXp;
    if (span <= 0) return 1.0;
    return ((xp - floorXp) / span).clamp(0.0, 1.0);
  }

  /// Copie legacy `app_config/prono_social.levels` → `app_settings/xp_levels`.
  static Future<bool> migrateLevelsFromPronoSocialIfEmpty() async {
    final levelsSnap = await _levelsRef.get();
    final existing = levelsSnap.data()?['levels'];
    if (existing is List && existing.isNotEmpty) return false;

    final pronoSnap =
        await _db.collection('app_config').doc('prono_social').get();
    final legacy = pronoSnap.data()?['levels'];
    if (legacy is! List || legacy.isEmpty) return false;

    await _levelsRef.set({'levels': legacy}, SetOptions(merge: true));
    return true;
  }
}
