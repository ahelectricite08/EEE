import 'package:cloud_firestore/cloud_firestore.dart';

/// Home-owned prono leaderboard strip (Accueil mini-card only — not Prono module).
class HomePronoLeaderboardDatasource {
  HomePronoLeaderboardDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTop({int limit = 5}) {
    return _db
        .collection('prono_leaderboard')
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots();
  }
}
