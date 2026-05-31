import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/benevole_document.dart';
import '../models/benevole_space_config.dart';
import 'app_settings_service.dart';

/// Espace bénévoles : config, PDF (Storage + Firestore).
class BenevoleSpaceService {
  BenevoleSpaceService._();
  static final instance = BenevoleSpaceService._();

  static const _configId = 'benevole_space';

  static final _configRef = AppSettingsService.configDoc(_configId);
  static final _docsCol =
      FirebaseFirestore.instance.collection('benevole_documents');
  static final _storage = FirebaseStorage.instance;

  Stream<BenevoleSpaceConfig> watchConfig() {
    return _configRef.snapshots().map((snap) {
      return BenevoleSpaceConfig.fromMap(snap.data());
    });
  }

  Future<BenevoleSpaceConfig> getConfig() async {
    final snap = await _configRef.get();
    return BenevoleSpaceConfig.fromMap(snap.data());
  }

  Future<void> saveConfig(BenevoleSpaceConfig config) async {
    await _configRef.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  /// PDF publiés, triés pour l'app (Team DVCR).
  Stream<List<BenevoleDocument>> watchPublishedDocuments() {
    return _docsCol
        .where('published', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BenevoleDocument.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Tous les documents (admin).
  Stream<List<BenevoleDocument>> watchAllDocuments() {
    return _docsCol.orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((d) => BenevoleDocument.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> uploadPdf({
    required String title,
    required String category,
    required Uint8List bytes,
    required String fileName,
    bool published = true,
    int? order,
  }) async {
    final docRef = _docsCol.doc();
    final storagePath = 'benevole_docs/${docRef.id}.pdf';
    final ref = _storage.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final fileUrl = await ref.getDownloadURL();

    await docRef.set({
      'title': title.trim(),
      'category': category.trim().isEmpty ? 'Général' : category.trim(),
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'published': published,
      'order': order ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uploadedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static String normalizeDrivePdfPreviewUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return input;
    final uri = Uri.tryParse(input);
    if (uri == null) return input;

    // Formats supportes:
    // - https://drive.google.com/file/d/<id>/view
    // - https://drive.google.com/open?id=<id>
    // - https://drive.google.com/uc?id=<id>&export=download
    String? fileId;
    final seg = uri.pathSegments;
    final dIdx = seg.indexOf('d');
    if (dIdx >= 0 && dIdx + 1 < seg.length) {
      fileId = seg[dIdx + 1];
    }
    fileId ??= uri.queryParameters['id'];

    if (fileId == null || fileId.isEmpty) return input;
    return 'https://drive.google.com/file/d/$fileId/preview';
  }

  Future<void> addDriveDocument({
    required String title,
    required String category,
    required String driveUrl,
    bool published = true,
    int? order,
  }) async {
    final docRef = _docsCol.doc();
    final normalizedUrl = normalizeDrivePdfPreviewUrl(driveUrl);

    await docRef.set({
      'title': title.trim(),
      'category': category.trim().isEmpty ? 'Général' : category.trim(),
      'fileUrl': normalizedUrl,
      'originalUrl': driveUrl.trim(),
      'storagePath': '',
      'fileName': 'Google Drive',
      'source': 'drive',
      'published': published,
      'order': order ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uploadedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Future<void> setDocumentPublished(String docId, bool published) async {
    await _docsCol.doc(docId).update({
      'published': published,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDocument(BenevoleDocument doc) async {
    if (doc.storagePath.isNotEmpty) {
      try {
        await _storage.ref(doc.storagePath).delete();
      } catch (_) {}
    }
    await _docsCol.doc(doc.id).delete();
  }
}
