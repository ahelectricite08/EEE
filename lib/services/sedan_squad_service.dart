import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sedan_squad.dart';

/// Effectif Sedan — lecture publique, écriture admin (`app_config/sedan_squad`).
class SedanSquadService {
  SedanSquadService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get configRef =>
      _db.collection('app_config').doc(SedanSquad.firestoreDocId);

  static Stream<SedanSquad> watch() {
    return configRef.snapshots().map((snap) => SedanSquad.fromMap(snap.data()));
  }

  static Future<SedanSquad> get() async {
    final snap = await configRef.get();
    return SedanSquad.fromMap(snap.data());
  }

  static Future<void> save(SedanSquad squad) async {
    await configRef.set(squad.toFirestoreMap(), SetOptions(merge: true));
  }

  static String newPlayerId(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9àâäéèêëïîôùûüç]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = slug.isEmpty ? 'player' : slug;
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${base}_$suffix';
  }
}
