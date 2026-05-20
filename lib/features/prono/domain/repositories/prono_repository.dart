import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prono_match_list_item.dart';

/// Contrat données Prono « league » (Firestore existant — compatible CF).
abstract class PronoRepository {
  /// Matchs à venir (fenêtre standard app).
  Stream<List<PronoMatchListItem>> watchUpcomingMatches({int limit = 80});

  /// Document prono utilisateur pour un match (`predictions/{matchId_uid}`).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPredictionDoc(
    String matchId,
    String uid,
  );

  /// Entrée classement saison (`prono_leaderboard/{uid}`).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLeaderboardEntry(
    String uid,
  );

  /// Stats agrégées 1-X-2 pour barres tendance (`match_prono_stats/{matchId}`).
  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchMatchPronoStats(
    String matchId,
  );
}
