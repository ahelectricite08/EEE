import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/radio_config.dart';

/// Lecture / écriture `app_config/radio` (URLs MediaMTX par défaut).
class RadioConfigService {
  RadioConfigService._();

  static final _ref = FirebaseFirestore.instance
      .collection('app_config')
      .doc(RadioConfig.firestoreDocId);

  static Future<RadioConfig> fetch() async {
    final snap = await _ref.get();
    return RadioConfig.fromMap(snap.data());
  }

  static Stream<RadioConfig> watch() => _ref.snapshots().map(
        (s) => RadioConfig.fromMap(s.data()),
      );

  static Future<void> save(RadioConfig config) async {
    await _ref.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
