import 'package:cloud_firestore/cloud_firestore.dart';

/// Agrégats audio + MP4 sur la fiche match (`matches/{id}.mediaStats`).
class MatchMediaStats {
  final int audioClips;
  final int audioDurationSec;
  final int audioPlays;
  final int videoClips;
  final int videoDurationSec;
  final int videoPlays;

  const MatchMediaStats({
    this.audioClips = 0,
    this.audioDurationSec = 0,
    this.audioPlays = 0,
    this.videoClips = 0,
    this.videoDurationSec = 0,
    this.videoPlays = 0,
  });

  bool get hasAny =>
      audioClips > 0 || videoClips > 0 || audioPlays > 0 || videoPlays > 0;

  factory MatchMediaStats.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const MatchMediaStats();
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return MatchMediaStats(
      audioClips: i('audioClips'),
      audioDurationSec: i('audioDurationSec'),
      audioPlays: i('audioPlays'),
      videoClips: i('videoClips'),
      videoDurationSec: i('videoDurationSec'),
      videoPlays: i('videoPlays'),
    );
  }

  Map<String, dynamic> toMap() => {
        'audioClips': audioClips,
        'audioDurationSec': audioDurationSec,
        'audioPlays': audioPlays,
        'videoClips': videoClips,
        'videoDurationSec': videoDurationSec,
        'videoPlays': videoPlays,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class MatchMediaStatsService {
  MatchMediaStatsService._();
  static final instance = MatchMediaStatsService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _match(String matchId) =>
      _db.collection('matches').doc(matchId.trim());

  Stream<MatchMediaStats> watch(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) {
      return Stream.value(const MatchMediaStats());
    }
    return _match(id).snapshots().map(
          (s) => MatchMediaStats.fromMap(
            s.data()?['mediaStats'] as Map<String, dynamic>?,
          ),
        );
  }

  /// Recalcule clips + durées depuis les sous-collections ; conserve les plays.
  Future<void> recomputeCatalog(String matchId) async {
    final mid = matchId.trim();
    if (mid.isEmpty) return;
    final matchRef = _match(mid);
    final audioSnap = await matchRef.collection('commentary').get();
    final videoSnap = await matchRef.collection('highlights').get();

    var audioClips = 0;
    var audioDur = 0;
    var audioPlays = 0;
    for (final d in audioSnap.docs) {
      final m = d.data();
      if ((m['status'] ?? '') != 'ready') continue;
      if ((m['audioUrl'] ?? '').toString().isEmpty) continue;
      audioClips++;
      audioDur += (m['durationSec'] as num?)?.toInt() ?? 0;
      audioPlays += (m['playCount'] as num?)?.toInt() ?? 0;
    }

    var videoClips = 0;
    var videoDur = 0;
    var videoPlays = 0;
    for (final d in videoSnap.docs) {
      final m = d.data();
      if ((m['status'] ?? '') != 'ready') continue;
      if ((m['videoUrl'] ?? '').toString().isEmpty) continue;
      videoClips++;
      videoDur += (m['durationSec'] as num?)?.toInt() ?? 0;
      videoPlays += (m['playCount'] as num?)?.toInt() ?? 0;
    }

    await matchRef.set({
      'mediaStats': MatchMediaStats(
        audioClips: audioClips,
        audioDurationSec: audioDur,
        audioPlays: audioPlays,
        videoClips: videoClips,
        videoDurationSec: videoDur,
        videoPlays: videoPlays,
      ).toMap(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementAudioPlay({
    required String matchId,
    required String eventId,
  }) async {
    await _incrementPlay(
      matchId: matchId,
      eventId: eventId,
      collection: 'commentary',
      aggregateKey: 'audioPlays',
    );
  }

  Future<void> incrementVideoPlay({
    required String matchId,
    required String eventId,
  }) async {
    await _incrementPlay(
      matchId: matchId,
      eventId: eventId,
      collection: 'highlights',
      aggregateKey: 'videoPlays',
    );
  }

  Future<void> _incrementPlay({
    required String matchId,
    required String eventId,
    required String collection,
    required String aggregateKey,
  }) async {
    final mid = matchId.trim();
    final eid = eventId.trim();
    if (mid.isEmpty || eid.isEmpty) return;
    final clipRef = _match(mid).collection(collection).doc(eid);
    // Play count sur le clip (fans autorisés). Agrégat match recalculé côté staff.
    try {
      await clipRef.set({
        'playCount': FieldValue.increment(1),
        'lastPlayedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    try {
      await _match(mid).set({
        'mediaStats': {
          aggregateKey: FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore si rules match bloquent — le playCount clip suffit.
    }
  }
}
