import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'match_media_stats_service.dart';

/// Clip audio commentateur lié à un fait de jeu (`eventId`).
class MatchCommentaryClip {
  final String id;
  final String eventId;
  final String type;
  final int minute;
  final String player;
  final String team;
  final String audioUrl;
  final String storagePath;
  final int durationSec;
  final int playCount;
  final String status;

  const MatchCommentaryClip({
    required this.id,
    required this.eventId,
    required this.type,
    required this.minute,
    required this.player,
    required this.team,
    required this.audioUrl,
    required this.storagePath,
    required this.durationSec,
    this.playCount = 0,
    required this.status,
  });

  bool get isReady =>
      status == 'ready' && audioUrl.trim().isNotEmpty;

  factory MatchCommentaryClip.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return MatchCommentaryClip(
      id: doc.id,
      eventId: (d['eventId'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      minute: (d['minute'] as num?)?.toInt() ?? 0,
      player: (d['player'] ?? '').toString(),
      team: (d['team'] ?? '').toString(),
      audioUrl: (d['audioUrl'] ?? '').toString(),
      storagePath: (d['storagePath'] ?? '').toString(),
      durationSec: (d['durationSec'] as num?)?.toInt() ?? 0,
      playCount: (d['playCount'] as num?)?.toInt() ?? 0,
      status: (d['status'] ?? '').toString(),
    );
  }
}

/// Upload / lecture des commentaires audio match (MVP clips liés à l’event).
class MatchCommentaryService {
  MatchCommentaryService._();
  static final instance = MatchCommentaryService._();

  static const int maxDurationSec = 40;
  static const int minDurationSec = 2;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String matchId) =>
      _db.collection('matches').doc(matchId.trim()).collection('commentary');

  Stream<Map<String, MatchCommentaryClip>> watchByEventId(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) {
      return Stream.value(const {});
    }
    return _col(id).snapshots().map((snap) {
      final out = <String, MatchCommentaryClip>{};
      for (final doc in snap.docs) {
        final clip = MatchCommentaryClip.fromDoc(doc);
        if (clip.eventId.isEmpty || !clip.isReady) continue;
        out[clip.eventId] = clip;
      }
      return out;
    });
  }

  /// Enregistre un clip M4A pour [eventId]. Remplace l’éventuel clip existant.
  /// Utilise [bytes] + `putData` (web-safe, pas de `dart:io` File).
  Future<MatchCommentaryClip> uploadClip({
    required String matchId,
    required String eventId,
    required Uint8List bytes,
    required int durationSec,
    String type = '',
    int minute = 0,
    String player = '',
    String team = '',
  }) async {
    final mid = matchId.trim();
    final eid = eventId.trim();
    if (mid.isEmpty || eid.isEmpty) {
      throw StateError('match_or_event_missing');
    }
    if (bytes.isEmpty) {
      throw StateError('audio_file_missing');
    }
    final secs = durationSec.clamp(minDurationSec, maxDurationSec);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'match_commentary/$mid/${eid}_$ts.m4a';

    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {
          'matchId': mid,
          'eventId': eid,
          'createdBy': uid,
        },
      ),
    );
    final audioUrl = await ref.getDownloadURL();

    // Un clip par event : réutilise le doc id = eventId pour simplicité.
    final docRef = _col(mid).doc(eid);
    final payload = <String, dynamic>{
      'eventId': eid,
      'type': type,
      'minute': minute,
      'player': player,
      'team': team,
      'audioUrl': audioUrl,
      'storagePath': storagePath,
      'durationSec': secs,
      'playCount': 0,
      'status': 'ready',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(payload, SetOptions(merge: true));
    await MatchMediaStatsService.instance.recomputeCatalog(mid);

    return MatchCommentaryClip(
      id: eid,
      eventId: eid,
      type: type,
      minute: minute,
      player: player,
      team: team,
      audioUrl: audioUrl,
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
