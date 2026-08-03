import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HighlightStinger {
  final String id;
  final String name;
  final String url;
  final String storagePath;

  const HighlightStinger({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
  });

  factory HighlightStinger.fromMap(Map<String, dynamic> m) {
    return HighlightStinger(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
      storagePath: (m['storagePath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'storagePath': storagePath,
      };
}

class HighlightStingerLibrary {
  final List<HighlightStinger> items;
  final String selectedId;

  const HighlightStingerLibrary({
    this.items = const [],
    this.selectedId = '',
  });

  HighlightStinger? get selected {
    if (items.isEmpty) return null;
    for (final s in items) {
      if (s.id == selectedId) return s;
    }
    return items.first;
  }
}

/// Bibliothèque de stingers + export résumé match (callable FFmpeg).
class HighlightStingerService {
  HighlightStingerService._();
  static final instance = HighlightStingerService._();

  static const docPath = 'app_config/highlight_stingers';

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _db.doc(docPath);

  Stream<HighlightStingerLibrary> watchLibrary() {
    return _doc.snapshots().map((snap) {
      final d = snap.data() ?? {};
      final raw = d['items'];
      final items = <HighlightStinger>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final s = HighlightStinger.fromMap(Map<String, dynamic>.from(e));
            if (s.id.isNotEmpty) items.add(s);
          }
        }
      }
      return HighlightStingerLibrary(
        items: items,
        selectedId: (d['selectedId'] ?? '').toString(),
      );
    });
  }

  Future<void> selectStinger(String id) async {
    await _doc.set({
      'selectedId': id.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  Future<HighlightStinger> uploadStinger({
    required Uint8List bytes,
    required String name,
  }) async {
    if (bytes.isEmpty) throw StateError('stinger_file_missing');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final safeName = name.trim().isEmpty ? 'Stinger' : name.trim();
    final storagePath = 'match_stingers/${id}.mp4';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {'name': safeName},
      ),
    );
    final url = await ref.getDownloadURL();
    final stinger = HighlightStinger(
      id: id,
      name: safeName,
      url: url,
      storagePath: storagePath,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final d = snap.data() ?? {};
      final items = <Map<String, dynamic>>[];
      final raw = d['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      items.add(stinger.toMap());
      tx.set(_doc, {
        'items': items,
        'selectedId': (d['selectedId'] ?? '').toString().isEmpty
            ? id
            : d['selectedId'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
    });

    return stinger;
  }

  Future<void> deleteStinger(String id) async {
    final sid = id.trim();
    if (sid.isEmpty) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final d = snap.data() ?? {};
      final items = <Map<String, dynamic>>[];
      String? pathToDelete;
      final raw = d['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          if ((m['id'] ?? '').toString() == sid) {
            pathToDelete = (m['storagePath'] ?? '').toString();
            continue;
          }
          items.add(m);
        }
      }
      var selected = (d['selectedId'] ?? '').toString();
      if (selected == sid) {
        selected = items.isEmpty ? '' : (items.first['id'] ?? '').toString();
      }
      tx.set(_doc, {
        'items': items,
        'selectedId': selected,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (pathToDelete != null && pathToDelete.isNotEmpty) {
        // delete after txn
      }
    });
    // Best-effort storage cleanup
    try {
      final snap = await _doc.get();
      // path already removed from doc — try known pattern
      await _storage.ref('match_stingers/$sid.mp4').delete();
    } catch (_) {}
  }

  /// Lance l’export Cloud Function (FFmpeg).
  Future<Map<String, dynamic>> exportResume({
    required String matchId,
    String? stingerId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable(
      'exportMatchHighlightResume',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
    );
    final res = await callable.call({
      'matchId': matchId.trim(),
      if (stingerId != null && stingerId.trim().isNotEmpty)
        'stingerId': stingerId.trim(),
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Stream<Map<String, dynamic>?> watchExport(String matchId) {
    return _db.collection('matches').doc(matchId.trim()).snapshots().map((s) {
      final raw = s.data()?['highlightExport'];
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    });
  }
}
