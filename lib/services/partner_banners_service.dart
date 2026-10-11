import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/partner_banners.dart';

export '../models/partner_banners.dart';

/// Catalogue admin d’encarts partenaires (`app_config/partner_banners`).
class PartnerBannersService {
  PartnerBannersService._();
  static final instance = PartnerBannersService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _catalogDoc =>
      _db.collection('app_config').doc(PartnerBanner.firestoreDocId);

  static PartnerBannerCatalog _lastKnown = PartnerBannerCatalog.empty;

  static PartnerBannerCatalog get lastKnown => _lastKnown;

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } on Object {
      return false;
    }
  }

  Stream<PartnerBannerCatalog> watchCatalog() {
    if (!_firebaseReady) {
      return Stream<PartnerBannerCatalog>.value(_lastKnown);
    }
    return _catalogDoc.snapshots().map((snap) {
      final c = PartnerBannerCatalog.fromMap(snap.data());
      _lastKnown = c;
      return c;
    }).handleError((_, __) {});
  }

  Future<PartnerBannerCatalog> getCatalog() async {
    if (!_firebaseReady) return _lastKnown;
    final snap = await _catalogDoc.get();
    final c = PartnerBannerCatalog.fromMap(snap.data());
    _lastKnown = c;
    return c;
  }

  /// PNG / JPG / WebP, 800 Ko max.
  Future<PartnerBanner> uploadBanner({
    required Uint8List bytes,
    required String extension,
    required String slot,
    String? originalName,
    String linkUrl = '',
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    if (bytes.isEmpty) throw StateError('banner_empty');
    if (bytes.length > PartnerBanner.maxFileBytes) {
      throw StateError('banner_too_large');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');

    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => throw StateError('banner_format'),
    };
    final contentType = switch (safeExt) {
      'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final id = _newId();
    final storagePath = '${PartnerBanner.storageFolder}/$id.$safeExt';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'role': 'partner_banner',
          'slot': PartnerBanner.normalizeSlot(slot),
          'updatedBy': uid,
          if (originalName != null && originalName.trim().isNotEmpty)
            'originalName': originalName.trim().length <= 80
                ? originalName.trim()
                : originalName.trim().substring(0, 80),
        },
      ),
    );
    final url = await ref.getDownloadURL();
    final now = DateTime.now().millisecondsSinceEpoch;
    late final PartnerBanner banner;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = PartnerBannerCatalog.fromMap(snap.data());
      final slotNorm = PartnerBanner.normalizeSlot(slot);
      var maxSort = -1;
      for (final b in current.forSlot(slotNorm)) {
        if (b.sort > maxSort) maxSort = b.sort;
      }
      banner = PartnerBanner(
        id: id,
        imageUrl: url,
        storagePath: storagePath,
        linkUrl: linkUrl.trim(),
        slot: slotNorm,
        sort: maxSort + 10,
        active: true,
        createdAtMillis: now,
        pixelWidthStored: pixelWidth ?? 0,
        pixelHeightStored: pixelHeight ?? 0,
      );
      tx.set(
        _catalogDoc,
        {
          'banners': [banner, ...current.items].map((b) => b.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMillis': now,
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
    return banner;
  }

  Future<void> updateBanner(PartnerBanner banner) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final id = banner.id.trim();
    if (id.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = PartnerBannerCatalog.fromMap(snap.data());
      final next = current.items.map((b) {
        if (b.id != id) return b;
        return b.copyWith(
          linkUrl: banner.linkUrl,
          slot: PartnerBanner.normalizeSlot(banner.slot),
          sort: banner.sort,
          active: banner.active,
        );
      }).toList();
      tx.set(
        _catalogDoc,
        {
          'banners': next.map((b) => b.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMillis': now,
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> deleteBanner(PartnerBanner banner) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final id = banner.id.trim();
    if (id.isEmpty) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_catalogDoc);
      final current = PartnerBannerCatalog.fromMap(snap.data());
      final next = current.items.where((b) => b.id != id).toList();
      tx.set(
        _catalogDoc,
        {
          'banners': next.map((b) => b.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );
    });

    final path = banner.storagePath.trim();
    if (path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
  }

  /// Taille naturelle du fichier (pour l’avertissement de ratio).
  static Future<({int width, int height})?> probeImageSize(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = (width: frame.image.width, height: frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  static String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = Random().nextInt(1 << 20).toRadixString(36);
    return 'pb_${t}_$r';
  }
}
