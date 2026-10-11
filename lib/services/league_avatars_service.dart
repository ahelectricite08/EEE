import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/league_avatars.dart';

export '../models/league_avatars.dart';

/// Catalogue admin d’emblèmes de ligue (`app_config/league_avatars`).
class LeagueAvatarsService {
  LeagueAvatarsService._();
  static final instance = LeagueAvatarsService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _catalogDoc =>
      _db.collection('app_config').doc(LeagueCatalogAvatar.firestoreDocId);

  Stream<LeagueAvatarCatalog> watchCatalog() {
    return _catalogDoc
        .snapshots()
        .map(
          (snap) => LeagueAvatarCatalog.fromMap(snap.data()),
        )
        .handleError((Object _, StackTrace __) {});
  }

  Future<LeagueAvatarCatalog> getCatalog() async {
    final snap = await _catalogDoc.get();
    return LeagueAvatarCatalog.fromMap(snap.data());
  }

  /// Admin — PNG / WebP uniquement, 500 Ko max.
  Future<LeagueCatalogAvatar> uploadCatalogAvatar({
    required Uint8List bytes,
    required String extension,
    String? originalName,
  }) async {
    if (bytes.isEmpty) throw StateError('avatar_empty');
    if (bytes.length > LeagueCatalogAvatar.maxFileBytes) {
      throw StateError('avatar_too_large');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');

    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      _ => throw StateError('avatar_format'),
    };
    final contentType = safeExt == 'webp' ? 'image/webp' : 'image/png';
    final id = _newId();
    final storagePath = '${LeagueCatalogAvatar.storageFolder}/$id.$safeExt';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'role': 'league_avatar',
          'updatedBy': uid,
          if (originalName != null && originalName.trim().isNotEmpty)
            'originalName': originalName.trim().length <= 80
                ? originalName.trim()
                : originalName.trim().substring(0, 80),
        },
      ),
    );
    final url = await ref.getDownloadURL();
    final avatar = LeagueCatalogAvatar(
      id: id,
      url: url,
      storagePath: storagePath,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = LeagueAvatarCatalog.fromMap(snap.data());
      final next = [avatar, ...current.avatars];
      tx.set(
        _catalogDoc,
        {
          'avatars': next.map((a) => a.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
    return avatar;
  }

  Future<void> deleteCatalogAvatar(LeagueCatalogAvatar avatar) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final id = avatar.id.trim();
    if (id.isEmpty) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = LeagueAvatarCatalog.fromMap(snap.data());
      final next = current.avatars.where((a) => a.id != id).toList();
      tx.set(
        _catalogDoc,
        {
          'avatars': next.map((a) => a.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });

    final path = avatar.storagePath.trim();
    if (path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
  }

  Future<Map<String, String>> resolveCreateFields(String? avatarId) async {
    final catalog = await getCatalog();
    return resolveLeagueEmblemFields(avatarId: avatarId, catalog: catalog);
  }

  Future<Map<String, String>?> resolveUpdateFields(String avatarId) async {
    final catalog = await getCatalog();
    return resolveLeagueEmblemUpdateFields(
      avatarId: avatarId,
      catalog: catalog,
    );
  }

  static String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = Random().nextInt(1 << 20).toRadixString(36);
    return 'lg_${t}_$r';
  }
}
