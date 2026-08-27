import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/match_partner_logos.dart';

/// Logos partenaires note du match / homme du match.
/// `app_config/match_partner_logos` + Storage `match_partner_logos/`.
class MatchPartnerLogosService {
  MatchPartnerLogosService._();
  static final instance = MatchPartnerLogosService._();

  static const int maxFileBytes = 2 * 1024 * 1024;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('app_config').doc(MatchPartnerLogos.firestoreDocId);

  Stream<MatchPartnerLogos> watch() {
    return _doc.snapshots().map((snap) => MatchPartnerLogos.fromMap(snap.data()));
  }

  Future<MatchPartnerLogos> getOnce() async {
    final snap = await _doc.get();
    return MatchPartnerLogos.fromMap(snap.data());
  }

  Future<void> setLogoUrl({
    required MatchPartnerLogoSlot slot,
    required String url,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final trimmed = url.trim();
    await _doc.set({
      ..._urlFields(slot, trimmed),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<MatchPartnerLogos> uploadLogo({
    required MatchPartnerLogoSlot slot,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (bytes.isEmpty) throw StateError('partner_logo_empty');
    if (bytes.length > maxFileBytes) throw StateError('partner_logo_too_large');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');

    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => throw StateError('partner_logo_format'),
    };
    final contentType = switch (safeExt) {
      'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final fileStem = switch (slot) {
      MatchPartnerLogoSlot.matchRating => 'match_rating_logo',
      MatchPartnerLogoSlot.motm => 'motm_logo',
    };
    final storagePath =
        '${MatchPartnerLogos.storageFolder}/$fileStem.$safeExt';

    final previous = await getOnce();
    final prevPath = switch (slot) {
      MatchPartnerLogoSlot.matchRating => previous.matchRatingLogoPath,
      MatchPartnerLogoSlot.motm => previous.motmLogoPath,
    }.trim();
    if (prevPath.isNotEmpty && prevPath != storagePath) {
      try {
        await _storage.ref(prevPath).delete();
      } catch (_) {}
    }

    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'role': fileStem,
          'updatedBy': uid,
        },
      ),
    );
    final url = await ref.getDownloadURL();
    await _doc.set({
      ..._urlFields(slot, url, path: storagePath),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
    return getOnce();
  }

  Future<void> clearLogo({
    required MatchPartnerLogoSlot slot,
    bool deleteStorageFile = false,
  }) async {
    final current = await getOnce();
    final path = switch (slot) {
      MatchPartnerLogoSlot.matchRating => current.matchRatingLogoPath,
      MatchPartnerLogoSlot.motm => current.motmLogoPath,
    }.trim();
    if (deleteStorageFile && path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
    await _doc.set({
      ..._urlFields(slot, '', path: ''),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  Map<String, String> _urlFields(
    MatchPartnerLogoSlot slot,
    String url, {
    String? path,
  }) {
    switch (slot) {
      case MatchPartnerLogoSlot.matchRating:
        return {
          'matchRatingLogoUrl': url,
          if (path != null) 'matchRatingLogoPath': path,
        };
      case MatchPartnerLogoSlot.motm:
        return {
          'motmLogoUrl': url,
          if (path != null) 'motmLogoPath': path,
        };
    }
  }
}
