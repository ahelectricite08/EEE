import 'package:cloud_firestore/cloud_firestore.dart';

/// Agrégats publics 1-X-2 pour un match ([`match_prono_stats`], mis à jour par Cloud Function).
class MatchPronoStatsService {
  MatchPronoStatsService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<Map<String, int>> outcomeStream(String matchId) {
    return _db
        .collection('match_prono_stats')
        .doc(matchId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) {
        return const {'homeWin': 0, 'draw': 0, 'awayWin': 0, 'total': 0};
      }
      final d = snap.data() ?? {};
      final h = _asInt(d['homeWin']);
      final draw = _asInt(d['draw']);
      final a = _asInt(d['awayWin']);
      final stored = _asInt(d['total']);
      final summed = h + draw + a;
      // Compteurs 1-N-2 = source de vérité visuel ; `total` stocké en secours.
      final total = summed > 0 ? summed : (stored > 0 ? stored : 0);
      return {
        'homeWin': h,
        'draw': draw,
        'awayWin': a,
        'total': total,
      };
    });
  }

  static int _asInt(Object? v) {
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) {
      final n = v.toInt();
      return n < 0 ? 0 : n;
    }
    return 0;
  }
}
