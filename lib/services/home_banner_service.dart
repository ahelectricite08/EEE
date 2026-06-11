import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Gère la photo principale de la home (bannière hero).
/// Firestore : app_config/home_banner → { photoUrl, storagePath, updatedAt }
/// Storage   : home_banner/banner.jpg (écrasé à chaque mise à jour)
class HomeBannerService {
  HomeBannerService._();

  static final _doc = FirebaseFirestore.instance
      .collection('app_config')
      .doc('home_banner');

  /// Stream de l'URL courante (null = utiliser l'asset par défaut).
  static Stream<String?> photoUrlStream() =>
      _doc.snapshots().map((s) => s.data()?['photoUrl'] as String?);

  /// Télécharge une image et enregistre son URL dans Firestore.
  static Future<String> uploadPhoto(
    Uint8List bytes,
    String extension,
  ) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
    const storagePath = 'home_banner/banner.jpg';

    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _doc.set({
      'photoUrl': url,
      'storagePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }

  /// Remet la photo par défaut (asset local).
  static Future<void> clearPhoto() async {
    await _doc.set(
      {'photoUrl': null, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
