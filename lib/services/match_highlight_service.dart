import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'match_media_stats_service.dart';

/// Clip vidéo (export vMix) lié à un fait de jeu.
class MatchHighlightClip {
  final String id;
  final String eventId;
  final String type;
  final int minute;
  final String player;
  final String team;
  final String videoUrl;
  final String storagePath;
  final int durationSec;
  final int playCount;
  final String status;

  const MatchHighlightClip({
    required this.id,
    required this.eventId,
    required this.type,
    required this.minute,
    required this.player,
    required this.team,
    required this.videoUrl,
    required this.storagePath,
    required this.durationSec,
    this.playCount = 0,
    required this.status,
  });

  bool get isReady => status == 'ready' && videoUrl.trim().isNotEmpty;

  factory MatchHighlightClip.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return MatchHighlightClip(
      id: doc.id,
      eventId: (d['eventId'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      minute: (d['minute'] as num?)?.toInt() ?? 0,
      player: (d['player'] ?? '').toString(),
      team: (d['team'] ?? '').toString(),
      videoUrl: (d['videoUrl'] ?? '').toString(),
      storagePath: (d['storagePath'] ?? '').toString(),
      durationSec: (d['durationSec'] as num?)?.toInt() ?? 0,
      playCount: (d['playCount'] as num?)?.toInt() ?? 0,
      status: (d['status'] ?? '').toString(),
    );
  }
}

class MatchHighlightService {
  MatchHighlightService._();
  static final instance = MatchHighlightService._();

  /// Limite souple côté produit (export vMix 10–20 s typique).
  static const int maxDurationSec = 45;
  static const int maxFileBytes = 40 * 1024 * 1024;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String matchId) =>
      _db.collection('matches').doc(matchId.trim()).collection('highlights');

  Stream<Map<String, MatchHighlightClip>> watchByEventId(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) return Stream.value(const {});
    return _col(id).snapshots().map((snap) {
      final out = <String, MatchHighlightClip>{};
      for (final doc in snap.docs) {
        final clip = MatchHighlightClip.fromDoc(doc);
        if (clip.eventId.isEmpty || !clip.isReady) continue;
        out[clip.eventId] = clip;
      }
      return out;
    });
  }

  Stream<List<MatchHighlightClip>> watchPlaylist(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) return Stream.value(const []);
    return _col(id).snapshots().map((snap) {
      final list = snap.docs
          .map(MatchHighlightClip.fromDoc)
          .where((c) => c.isReady)
          .toList()
        ..sort((a, b) {
          final m = a.minute.compareTo(b.minute);
          if (m != 0) return m;
          return a.eventId.compareTo(b.eventId);
        });
      return list;
    });
  }

  Future<MatchHighlightClip> uploadClip({
    required String matchId,
    required String eventId,
    required File file,
    int durationSec = 0,
    String type = '',
    int minute = 0,
    String player = '',
    String team = '',
  }) async {
    final mid = matchId.trim();
    final eid = eventId.trim();
    if (mid.isEmpty || eid.isEmpty) throw StateError('match_or_event_missing');
    if (!await file.exists()) throw StateError('video_file_missing');
    final size = await file.length();
    if (size > maxFileBytes) throw StateError('video_too_large');

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'match_highlights/$mid/${eid}_$ts.mp4';
    final ref = _storage.ref(storagePath);
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'matchId': mid,
          'eventId': eid,
          'createdBy': uid,
          'source': 'vmix_export',
        },
      ),
    );
    final videoUrl = await ref.getDownloadURL();
    final secs = durationSec.clamp(0, maxDurationSec);

    await _col(mid).doc(eid).set({
      'eventId': eid,
      'type': type,
      'minute': minute,
      'player': player,
      'team': team,
      'videoUrl': videoUrl,
      'storagePath': storagePath,
      'durationSec': secs,
      'playCount': 0,
      'status': 'ready',
      'source': 'vmix_export',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await MatchMediaStatsService.instance.recomputeCatalog(mid);

    return MatchHighlightClip(
      id: eid,
      eventId: eid,
      type: type,
      minute: minute,
      player: player,
      team: team,
      videoUrl: videoUrl,
      storagePath: storagePath,
      durationSec: secs,
      status: 'ready',
    );
  }

  Future<void> deleteClip({
    required String matchId,
    required String eventId,
  }) async {
    final mid = matchId.trim();
    final eid = eventId.trim();
    if (mid.isEmpty || eid.isEmpty) return;
    final doc = await _col(mid).doc(eid).get();
    if (!doc.exists) return;
    final path = (doc.data()?['storagePath'] ?? '').toString();
    if (path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
    await doc.reference.delete();
    await MatchMediaStatsService.instance.recomputeCatalog(mid);
  }
}
