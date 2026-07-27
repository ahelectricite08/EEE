import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore `app_config/home_banner` + Storage `home_banner/banner.jpg`.
class HomeBannerDatasource {
  HomeBannerDatasource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('app_config').doc('home_banner');

  Stream<String?> watchPhotoUrl() {
    return _doc.snapshots().map((s) => s.data()?['photoUrl'] as String?);
  }

  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
    const storagePath = 'home_banner/banner.jpg';

    final ref = _storage.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _doc.set({
      'photoUrl': url,
      'storagePath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }

  Future<void> clearPhoto() {
    return _doc.set(
      {'photoUrl': null, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
