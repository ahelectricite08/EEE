import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/prono_match_list_item.dart';
import '../domain/repositories/prono_repository.dart';

class FirestorePronoRepository implements PronoRepository {
  final FirebaseFirestore _db;

  FirestorePronoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<PronoMatchListItem>> watchUpcomingMatches({int limit = 80}) {
    return _db
        .collection('matches')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .limit(limit)
        .snapshots()
        .map((snap) {
      final seen = <String>{};
      final out = <PronoMatchListItem>[];
      for (final doc in snap.docs) {
        final item = PronoMatchListItem.fromDoc(doc);
        final key = '${item.team1}|${item.team2}|${item.date.millisecondsSinceEpoch}';
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(item);
      }
      return out;
    });
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPredictionDoc(
    String matchId,
    String uid,
  ) {
    return _db
        .collection('predictions')
        .doc('${matchId}_$uid')
        .snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLeaderboardEntry(
    String uid,
  ) {
    return _db.collection('prono_leaderboard').doc(uid).snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchMatchPronoStats(
    String matchId,
  ) {
    return _db.collection('match_prono_stats').doc(matchId).snapshots();
  }
}
