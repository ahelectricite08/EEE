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
      return {
        'homeWin': (d['homeWin'] as num?)?.toInt() ?? 0,
        'draw': (d['draw'] as num?)?.toInt() ?? 0,
        'awayWin': (d['awayWin'] as num?)?.toInt() ?? 0,
        'total': (d['total'] as num?)?.toInt() ?? 0,
      };
    });
  }
}
