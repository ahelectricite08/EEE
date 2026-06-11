import 'package:cloud_firestore/cloud_firestore.dart';

/// Saison prono DVCR (`prono_seasons/current`) et stats saisonnières optionnelles.
class PronoSeasonService {
  PronoSeasonService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<DocumentSnapshot<Map<String, dynamic>>> currentSeasonStream() {
    return _db.collection('prono_seasons').doc('current').snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userSeasonStatsStream({
    required String uid,
    String seasonDocId = 'current',
  }) {
    final docId = '${uid}_$seasonDocId';
    return _db.collection('user_season_stats').doc(docId).snapshots();
  }
}
