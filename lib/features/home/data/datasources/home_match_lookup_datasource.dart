import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dvcr/models/match_model.dart';

class HomeMatchLookupDatasource {
  HomeMatchLookupDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<MatchModel?> fetchById(String matchId) async {
    final snap = await _db.collection('matches').doc(matchId).get();
    if (!snap.exists) return null;
    return MatchModel.fromFirestore(snap);
  }
}
