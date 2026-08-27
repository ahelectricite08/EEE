import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/souvenir_branding.dart';

/// Config souvenir — `app_config/souvenir_branding`
/// (feature fan + logo partenaire Storage `match_souvenir/partner_logo.*`).
class MatchSouvenirBrandingService {
  MatchSouvenirBrandingService._();
  static final instance = MatchSouvenirBrandingService._();

  /// Aligné UI admin (~2 Mo) — rules Storage autorisent jusqu’à 5 Mo.
  static const int maxFileBytes = 2 * 1024 * 1024;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('app_config').doc(SouvenirBranding.firestoreDocId);

  Stream<SouvenirBranding> watch() {
    return _doc.snapshots().map(
          (snap) => SouvenirBranding.fromMap(snap.data()),
        );
  }

  Future<SouvenirBranding> getOnce() async {
    final snap = await _doc.get();
    return SouvenirBranding.fromMap(snap.data());
  }

  /// Active / désactive toute la feature souvenir fan (CTA + partage).
  Future<void> setFeatureEnabled(bool featureEnabled) async {
    await _doc.set({
      'featureEnabled': featureEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  Future<void> setEnabled(bool enabled) async {
    await _doc.set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  /// Colle une URL (Storage / CDN) sans nouvel upload.
  Future<void> setLogoUrl(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final trimmed = url.trim();
    await _doc.set({
      'enabled': trimmed.isNotEmpty ? true : false,
      'logoUrl': trimmed,
      if (trimmed.isEmpty) 'logoPath': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  /// Upload web-safe (`putData`) — remplace le fichier logo partenaire.
  Future<SouvenirBranding> uploadPartnerLogo({
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
    final storagePath =
        '${SouvenirBranding.storageFolder}/partner_logo.$safeExt';

    // Supprime l’ancien fichier si extension différente.
    final previous = await getOnce();
    final prevPath = previous.logoPath.trim();
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
          'role': 'souvenir_partner_logo',
          'updatedBy': uid,
        },
      ),
    );
    final url = await ref.getDownloadURL();
    await _doc.set({
      'enabled': true,
      'logoUrl': url,
      'logoPath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
    return SouvenirBranding(
      featureEnabled: previous.featureEnabled,
      enabled: true,
      logoUrl: url,
      logoPath: storagePath,
      revisionMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Masque le logo (toggle off) sans forcément supprimer le fichier.
  Future<void> clearPartnerLogo({bool deleteStorageFile = false}) async {
    final current = await getOnce();
    if (deleteStorageFile && current.logoPath.isNotEmpty) {
      try {
        await _storage.ref(current.logoPath).delete();
      } catch (_) {}
    }
    await _doc.set({
      'enabled': false,
      'logoUrl': '',
      'logoPath': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }
}
