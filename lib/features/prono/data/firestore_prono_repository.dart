import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/match_competition.dart';
import '../domain/models/prono_match_list_item.dart';
import '../domain/prono_lock.dart';
import '../domain/repositories/prono_repository.dart';

class FirestorePronoRepository implements PronoRepository {
  final FirebaseFirestore _db;

  FirestorePronoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<PronoMatchListItem>> watchUpcomingMatches({int limit = 80}) {
    final from = Timestamp.fromDate(
      DateTime.now().subtract(pronoBoardLookback),
    );
    return _db
        .collection('matches')
        .where('date', isGreaterThan: from)
        .orderBy('date')
        .limit(limit)
        .snapshots()
        .map((snap) {
      final winners = <String, PronoMatchListItem>{};
      for (final doc in snap.docs) {
        final item = PronoMatchListItem.fromDoc(doc);
        if (!MatchCompetition.isPronoEligible(
          item.competition,
          matchId: item.id,
        )) {
          continue;
        }
        final key = pronoFixtureDedupeKey(item);
        final existing = winners[key];
        if (existing == null || preferFffPronoMatch(item, existing)) {
          winners[key] = item;
        }
      }
      final out = winners.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
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
