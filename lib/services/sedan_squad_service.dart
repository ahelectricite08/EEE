import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  static const int maxPhotoBytes = 2 * 1024 * 1024;

  /// Portrait joueur → Storage `sedan_squad/{id}.jpg` — URL publique.
  static Future<String> uploadPlayerPhoto({
    required String playerId,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (bytes.isEmpty) throw StateError('photo_empty');
    if (bytes.length > maxPhotoBytes) throw StateError('photo_too_large');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');

    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => throw StateError('photo_format'),
    };
    final contentType = switch (safeExt) {
      'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final safeId = playerId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (safeId.isEmpty) throw StateError('photo_player');

    final ref = FirebaseStorage.instance
        .ref('${SedanSquad.storageFolder}/$safeId.$safeExt');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'playerId': playerId,
          'updatedBy': uid,
        },
      ),
    );
    return ref.getDownloadURL();
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
