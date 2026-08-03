import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Audio « Parole du coach » attaché au document match.
class MatchCoachAudio {
  final String audioUrl;
  final String storagePath;
  final int durationSec;
  final String title;
  final DateTime? updatedAt;

  const MatchCoachAudio({
    required this.audioUrl,
    required this.storagePath,
    this.durationSec = 0,
    this.title = '',
    this.updatedAt,
  });

  bool get isReady => audioUrl.trim().isNotEmpty;

  static MatchCoachAudio? fromMatchData(Map<String, dynamic>? d) {
    if (d == null) return null;
    final url = (d['coachAudioUrl'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final updated = d['coachAudioUpdatedAt'];
    return MatchCoachAudio(
      audioUrl: url,
      storagePath: (d['coachAudioPath'] ?? '').toString(),
      durationSec: (d['coachAudioDurationSec'] as num?)?.toInt() ?? 0,
      title: (d['coachAudioTitle'] ?? '').toString(),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}

/// Upload / suppression de la parole du coach (web-safe via `putData`).
class MatchCoachAudioService {
  MatchCoachAudioService._();
  static final instance = MatchCoachAudioService._();

  static const int maxDurationSec = 180;
  static const int minDurationSec = 2;
  static const int maxFileBytes = 15 * 1024 * 1024;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _matchRef(String matchId) =>
      _db.collection('matches').doc(matchId.trim());

  Stream<MatchCoachAudio?> watch(String matchId) {
    final id = matchId.trim();
    if (id.isEmpty) return Stream.value(null);
    return _matchRef(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return MatchCoachAudio.fromMatchData(snap.data());
    });
  }

  /// Enregistre un clip M4A / AAC / MP3 pour le match. Remplace l’existant.
  Future<MatchCoachAudio> upload({
    required String matchId,
    required Uint8List bytes,
    required int durationSec,
    String title = '',
    String contentType = 'audio/mp4',
    String extension = 'm4a',
  }) async {
    final mid = matchId.trim();
    if (mid.isEmpty) throw StateError('match_missing');
    if (bytes.isEmpty) throw StateError('audio_file_missing');
    if (bytes.length > maxFileBytes) throw StateError('audio_too_large');

    // 0 = durée inconnue (fichier importé sans analyse).
    final secs = durationSec <= 0
        ? 0
        : durationSec.clamp(minDurationSec, maxDurationSec);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final cleanedExt = extension.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final ext = cleanedExt.isEmpty ? 'm4a' : cleanedExt;
    final storagePath = 'match_coach_audio/$mid/coach_$ts.$ext';

    // Supprime l’ancien fichier Storage s’il existe.
    final prev = await _matchRef(mid).get();
    final prevPath = (prev.data()?['coachAudioPath'] ?? '').toString();
    if (prevPath.isNotEmpty) {
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
          'matchId': mid,
          'createdBy': uid,
          'kind': 'coach_audio',
        },
      ),
    );
    final audioUrl = await ref.getDownloadURL();
    final cleanTitle = title.trim();

    await _matchRef(mid).set({
      'coachAudioUrl': audioUrl,
      'coachAudioPath': storagePath,
      'coachAudioDurationSec': secs,
      'coachAudioTitle': cleanTitle,
      'coachAudioUpdatedAt': FieldValue.serverTimestamp(),
      'coachAudioCreatedBy': uid,
    }, SetOptions(merge: true));

    return MatchCoachAudio(
      audioUrl: audioUrl,
      storagePath: storagePath,
      durationSec: secs,
      title: cleanTitle,
    );
  }

  Future<void> delete(String matchId) async {
    final mid = matchId.trim();
    if (mid.isEmpty) return;
    final doc = await _matchRef(mid).get();
    if (!doc.exists) return;
    final path = (doc.data()?['coachAudioPath'] ?? '').toString();
    if (path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
    await _matchRef(mid).set({
      'coachAudioUrl': FieldValue.delete(),
      'coachAudioPath': FieldValue.delete(),
      'coachAudioDurationSec': FieldValue.delete(),
      'coachAudioTitle': FieldValue.delete(),
      'coachAudioUpdatedAt': FieldValue.delete(),
      'coachAudioCreatedBy': FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
