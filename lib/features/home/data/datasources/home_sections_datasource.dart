import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `config/home_sections` ACL for Home.
class HomeSectionsDatasource {
  HomeSectionsDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('config').doc('home_sections');

  Stream<Map<String, dynamic>> watchRaw() {
    return _ref.snapshots(includeMetadataChanges: true).map(
          (snap) => snap.data() ?? const <String, dynamic>{},
        );
  }

  Future<void> setPodcastNextEvent(DateTime dateTime) {
    return _ref.set({
      'podcastNextEventAt': Timestamp.fromDate(dateTime),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearPodcastNextEvent() {
    return _ref.set({
      'podcastNextEventAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
