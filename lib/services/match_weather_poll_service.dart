import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match_weather_poll.dart';
import 'match_weather_service.dart';

/// Votes météo — `match_weather_votes/{matchId}/votes/{uid}`.
class MatchWeatherPollService {
  MatchWeatherPollService._();
  static final instance = MatchWeatherPollService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _votes(String matchId) =>
      _db
          .collection(MatchWeatherPoll.collection)
          .doc(matchId)
          .collection(MatchWeatherPoll.votesSub);

  Stream<MatchWeatherPollSnapshot> watch(String matchId) {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      return _votes(matchId).snapshots().map((qs) {
        final counts = <String, int>{};
        String? mine;
        for (final d in qs.docs) {
          final id = (d.data()['optionId'] ?? '').toString();
          if (!MatchWeatherPoll.isValidOptionId(id)) continue;
          counts[id] = (counts[id] ?? 0) + 1;
          if (user != null && d.id == user.uid) mine = id;
        }
        return MatchWeatherPollSnapshot(counts: counts, myOptionId: mine);
      });
    });
  }

  static String userFacingWriteError(Object error) {
    if (error is StateError) return error.message;
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'unauthenticated') {
        return 'Connecte-toi pour voter.';
      }
      if (code == 'permission-denied') {
        return 'Fermé — 20 min après le coup d’envoi.';
      }
    }
    return 'Impossible d’enregistrer. Réessaie dans un instant.';
  }

  Future<void> vote({
    required String matchId,
    required String optionId,
    required DateTime kickoff,
    DateTime? now,
    MatchWeatherMode? mode,
    int? tempC,
  }) async {
    final mid = matchId.trim();
    if (mid.isEmpty || mid.length > 80) {
      throw StateError('Match inconnu.');
    }
    final allowedToday = mode == null
        ? MatchWeatherPoll.optionIds
        : MatchWeatherPoll.optionIdsFor(mode, tempC);
    if (!allowedToday.contains(optionId)) {
      throw StateError('Choix inconnu.');
    }
    if (!MatchWeatherPoll.isOpen(kickoff, now: now)) {
      throw StateError('Fermé — 20 min après le coup d’envoi.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Connecte-toi pour voter.');
    }
    final ref = _votes(mid).doc(user.uid);
    final snap = await ref.get();
    final payload = <String, dynamic>{
      'uid': user.uid,
      'matchId': mid,
      'optionId': optionId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }
}
