import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/profile_avatars.dart';

export '../models/profile_avatars.dart';

/// Catalogue admin + choix utilisateur (`avatarId` / `avatarUrl` sur `users/{uid}`).
class ProfileAvatarsService {
  ProfileAvatarsService._();
  static final instance = ProfileAvatarsService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _catalogDoc =>
      _db.collection('app_config').doc(ProfileAvatar.firestoreDocId);

  CollectionReference<Map<String, dynamic>> get _publicCol =>
      _db.collection(ProfileAvatar.publicCollection);

  Stream<ProfileAvatarCatalog> watchCatalog() {
    return _catalogDoc.snapshots().map(
          (snap) => ProfileAvatarCatalog.fromMap(snap.data()),
        );
  }

  Future<ProfileAvatarCatalog> getCatalog() async {
    final snap = await _catalogDoc.get();
    return ProfileAvatarCatalog.fromMap(snap.data());
  }

  final _publicUrlStreams = <String, Stream<String?>>{};

  Stream<String?> watchPublicAvatarUrl(String uid) {
    final id = uid.trim();
    if (id.isEmpty) return Stream<String?>.value(null);
    return _publicUrlStreams.putIfAbsent(
      id,
      () => _publicCol
          .doc(id)
          .snapshots()
          .map((snap) => profileAvatarUrlFromData(snap.data()))
          .distinct()
          .asBroadcastStream(),
    );
  }

  Stream<String?> watchMyAvatarUrl() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return Stream<String?>.value(null);
    return _db.collection('users').doc(uid).snapshots().map(
          (snap) => profileAvatarUrlFromData(snap.data()),
        );
  }

  /// Admin — PNG / WebP uniquement, 500 Ko max.
  Future<ProfileAvatar> uploadCatalogAvatar({
    required Uint8List bytes,
    required String extension,
    String? originalName,
  }) async {
    if (bytes.isEmpty) throw StateError('avatar_empty');
    if (bytes.length > ProfileAvatar.maxFileBytes) {
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
    final storagePath = '${ProfileAvatar.storageFolder}/$id.$safeExt';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'role': 'profile_avatar',
          'updatedBy': uid,
          if (originalName != null && originalName.trim().isNotEmpty)
            'originalName': originalName.trim().length <= 80
                ? originalName.trim()
                : originalName.trim().substring(0, 80),
        },
      ),
    );
    final url = await ref.getDownloadURL();
    final avatar = ProfileAvatar(
      id: id,
      url: url,
      storagePath: storagePath,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = ProfileAvatarCatalog.fromMap(snap.data());
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

  Future<void> deleteCatalogAvatar(ProfileAvatar avatar) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final id = avatar.id.trim();
    if (id.isEmpty) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = ProfileAvatarCatalog.fromMap(snap.data());
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

  Future<void> selectForCurrentUser(ProfileAvatar avatar) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final catalog = await getCatalog();
    final found = catalog.byId(avatar.id);
    if (found == null || !found.hasUrl) throw StateError('avatar_unknown');

    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(uid),
      {
        'avatarId': found.id,
        'avatarUrl': found.url,
      },
      SetOptions(merge: true),
    );
    batch.set(_publicCol.doc(uid), {
      'avatarId': found.id,
      'avatarUrl': found.url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    try {
      final lb = _db.batch();
      await _mergeLeaderboardAvatar(
        batch: lb,
        uid: uid,
        avatarId: found.id,
        avatarUrl: found.url,
      );
      await lb.commit();
    } catch (_) {}
  }

  Future<void> clearForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(uid),
      {
        'avatarId': FieldValue.delete(),
        'avatarUrl': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
    batch.delete(_publicCol.doc(uid));
    await batch.commit();
    try {
      final lb = _db.batch();
      await _mergeLeaderboardAvatar(batch: lb, uid: uid, clear: true);
      await lb.commit();
    } catch (_) {}
  }

  /// Dénormalise sur `prono_leaderboard/{uid}` s’il existe déjà (pas de create).
  Future<void> _mergeLeaderboardAvatar({
    required WriteBatch batch,
    required String uid,
    String? avatarId,
    String? avatarUrl,
    bool clear = false,
  }) async {
    final ref = _db.collection('prono_leaderboard').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;
    if (clear) {
      batch.set(
        ref,
        {
          'avatarId': FieldValue.delete(),
          'avatarUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }
    final id = (avatarId ?? '').trim();
    final url = (avatarUrl ?? '').trim();
    if (id.isEmpty || url.isEmpty) return;
    batch.set(
      ref,
      {
        'avatarId': id,
        'avatarUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = Random().nextInt(1 << 20).toRadixString(36);
    return 'av_${t}_$r';
  }
}
