import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match_stats_schema.dart';

/// Source admin : collection `match_stats/{matchId}`.
class MatchStatsSheetService {
  MatchStatsSheetService._();
  static final instance = MatchStatsSheetService._();

  static final _col = FirebaseFirestore.instance.collection('match_stats');
  static final _matches = FirebaseFirestore.instance.collection('matches');

  DocumentReference<Map<String, dynamic>> docRef(String matchId) =>
      _col.doc(matchId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String matchId) =>
      docRef(matchId).snapshots();

  Future<Map<String, dynamic>?> get(String matchId) async {
    final snap = await docRef(matchId).get();
    return snap.data();
  }

  Future<void> ensureFromMatch(String matchId) async {
    final ref = docRef(matchId);
    final existing = await ref.get();
    if (existing.exists) return;

    final matchSnap = await _matches.doc(matchId).get();
    if (!matchSnap.exists) return;
    final m = matchSnap.data()!;
    final stats = MatchStatsSchema.normalizeMap(m['stats'] as Map<String, dynamic>?);
    final events = m['events'] is List ? List.from(m['events'] as List) : <dynamic>[];

    var state = MatchStatsPublicationState.draft;
    final statsState = m['statsState']?.toString();
    if (statsState == 'published' || m['showStats'] == true) {
      state = MatchStatsPublicationState.published;
    } else if (statsState == 'preview') {
      state = MatchStatsPublicationState.preview;
    }

    await ref.set({
      'matchId': matchId,
      'team1': m['team1'] ?? '',
      'team2': m['team2'] ?? '',
      'date': m['date'],
      'competition': m['competition'] ?? '',
      'stats': stats,
      'events': events,
      'state': state.firestoreValue,
      'previewEnabled': state == MatchStatsPublicationState.preview,
      'statsVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  Future<void> saveDraft({
    required String matchId,
    required Map<String, dynamic> stats,
    List<Map<String, dynamic>>? events,
  }) async {
    await ensureFromMatch(matchId);
    final normalized = MatchStatsSchema.normalizeMap(stats);
    final hasContent = !MatchStatsSchema.isEmpty(normalized) ||
        (events != null && events.isNotEmpty);

    final patch = <String, dynamic>{
      'stats': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    };
    if (events != null) {
      patch['events'] = events;
    }

    // Dès qu’il y a du contenu : preview active jusqu’à clôture (cron 5 min).
    if (hasContent) {
      patch['state'] = MatchStatsPublicationState.preview.firestoreValue;
      patch['previewEnabled'] = true;
    } else {
      patch['state'] = MatchStatsPublicationState.draft.firestoreValue;
      patch['previewEnabled'] = false;
    }

    await docRef(matchId).set(patch, SetOptions(merge: true));
  }

  /// Pousse immédiatement sur `matches` (sans attendre le cron 5 min).
  Future<void> syncNow(String matchId) async {
    await FirebaseFunctions.instance
        .httpsCallable('syncMatchStatsPreviewManual')
        .call({'matchId': matchId});
  }

  /// @deprecated Preview s’active automatiquement à la saisie — utiliser [syncNow].
  Future<void> enablePreview(String matchId) async {
    await ensureFromMatch(matchId);
    await docRef(matchId).set({
      'state': MatchStatsPublicationState.preview.firestoreValue,
      'previewEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
    await syncNow(matchId);
  }

  Future<void> finalize(String matchId) async {
    await FirebaseFunctions.instance
        .httpsCallable('finalizeMatchStats')
        .call({'matchId': matchId});
  }

  /// Repasse un match clôturé en saisie modifiable (preview).
  Future<void> reopen(String matchId) async {
    await FirebaseFunctions.instance
        .httpsCallable('reopenMatchStats')
        .call({'matchId': matchId});
  }

  /// Prépare la fiche stats avant le match (brouillon vide prêt à saisir).
  Future<void> prepareSession(String matchId) async {
    await ensureFromMatch(matchId);
  }

  Future<int> migrateFromMatches() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('migrateMatchStatsFromMatches')
        .call();
    final data = result.data;
    if (data is Map && data['migrated'] is num) {
      return (data['migrated'] as num).toInt();
    }
    return 0;
  }
}
