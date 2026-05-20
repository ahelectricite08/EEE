import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fff_season_config.dart';

/// Lecture / écriture de [app_config/fff_season] (synchro FFF Cloud Functions).
class SeasonConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('fff_season');

  static Stream<FffSeasonConfig> stream() {
    return _ref.snapshots().map(FffSeasonConfig.fromSnapshot);
  }

  static Future<FffSeasonConfig> getCurrent() async {
    final snap = await _ref.get();
    return FffSeasonConfig.fromSnapshot(snap);
  }

  static Future<void> save(FffSeasonConfig config) async {
    await _ref.set(config.toFirestoreMap(), SetOptions(merge: true));
  }
}
