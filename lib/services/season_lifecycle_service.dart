import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/season_lifecycle_config.dart';

/// Lecture de [app_config/season_lifecycle] (fin de saison / messages d’attente).
class SeasonLifecycleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get ref =>
      _db.collection('app_config').doc(SeasonLifecycleConfig.firestoreDocId);

  static Stream<SeasonLifecycleConfig> stream() =>
      ref.snapshots().map(SeasonLifecycleConfig.fromSnapshot);

  static Future<SeasonLifecycleConfig> getCurrent() async {
    final snap = await ref.get();
    return SeasonLifecycleConfig.fromSnapshot(snap);
  }

  static Future<void> save(SeasonLifecycleConfig config) async {
    await ref.set(config.toFirestoreMap(), SetOptions(merge: true));
  }
}
