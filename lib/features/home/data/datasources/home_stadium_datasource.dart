import 'package:cloud_firestore/cloud_firestore.dart';

class HomeStadiumDatasource {
  HomeStadiumDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<String?> watchStadiumImageUrl(String teamName) {
    return _db
        .collection('teams')
        .where('name', isEqualTo: teamName)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final url =
          (snap.docs.first.data()['stadiumImageUrl'] as String?)?.trim();
      return (url == null || url.isEmpty) ? null : url;
    });
  }
}
