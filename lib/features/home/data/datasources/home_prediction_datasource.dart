import 'package:cloud_firestore/cloud_firestore.dart';

/// Home-owned read of a single prediction doc (Accueil featured match footer).
class HomePredictionDatasource {
  HomePredictionDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPrediction({
    required String matchId,
    required String uid,
  }) {
    return _db.collection('predictions').doc('${matchId}_$uid').snapshots();
  }
}
