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
    try {
      await FirebaseFunctions.instance
          .httpsCallable('reopenMatchStats')
          .call({'matchId': matchId});
    } catch (_) {
      await setPublicationState(matchId, MatchStatsPublicationState.preview);
      return;
    }
    final sheet = await get(matchId);
    final stats = MatchStatsSchema.normalizeMap(
      sheet?['stats'] as Map<String, dynamic>?,
    );
    await _syncLiveHubPreview(matchId, stats);
  }

  /// Change l’état publication (client + CF pour « officiel »).
  Future<void> setPublicationState(
    String matchId,
    MatchStatsPublicationState state,
  ) async {
    if (state == MatchStatsPublicationState.published) {
      try {
        await finalize(matchId);
      } catch (_) {
        await _publishClient(matchId);
      }
      return;
    }

    await ensureFromMatch(matchId);
    final sheetSnap = await docRef(matchId).get();
    final matchSnap = await _matches.doc(matchId).get();
    final sheet = sheetSnap.data() ?? {};
    final match = matchSnap.data() ?? {};
    final stats = MatchStatsSchema.normalizeMap(
      (sheet['stats'] as Map<String, dynamic>?) ??
          (match['stats'] as Map<String, dynamic>?),
    );
    final eventsRaw = sheet['events'] ?? match['events'];
    final events = eventsRaw is List
        ? eventsRaw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final hasContent =
        !MatchStatsSchema.isEmpty(stats) || events.isNotEmpty;

    if (state == MatchStatsPublicationState.preview) {
      await _setPreviewClient(
        matchId: matchId,
        stats: stats,
        events: events,
        hasContent: hasContent,
      );
      await _syncLiveHubPreview(matchId, stats);
      return;
    }

    // draft / none → à saisir
    await _setDraftClient(
      matchId: matchId,
      stats: stats,
      events: events,
    );
    await _clearLiveHubPreview(matchId);
  }

  Future<void> _publishClient(String matchId) async {
    final sheetSnap = await docRef(matchId).get();
    if (!sheetSnap.exists) {
      await ensureFromMatch(matchId);
    }
    final sheet = (await docRef(matchId).get()).data() ?? {};
    final match = (await _matches.doc(matchId).get()).data() ?? {};
    final stats = MatchStatsSchema.normalizeMap(
      (sheet['stats'] as Map<String, dynamic>?) ??
          (match['stats'] as Map<String, dynamic>?),
    );
    final eventsRaw = sheet['events'] ?? match['events'];
    final events = eventsRaw is List
        ? eventsRaw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final hasContent =
        !MatchStatsSchema.isEmpty(stats) || events.isNotEmpty;

    await _matches.doc(matchId).set({
      'stats': stats,
      'events': events,
      'statsState': MatchStatsPublicationState.published.firestoreValue,
      'showStats': hasContent,
      'statsPublishedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await docRef(matchId).set({
      'state': MatchStatsPublicationState.published.firestoreValue,
      'previewEnabled': false,
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await _clearLiveHubPreview(matchId);
  }

  Future<void> _setPreviewClient({
    required String matchId,
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> events,
    required bool hasContent,
  }) async {
    final previewState = hasContent
        ? MatchStatsPublicationState.preview
        : MatchStatsPublicationState.draft;

    await docRef(matchId).set({
      'stats': stats,
      'events': events,
      'state': previewState.firestoreValue,
      'previewEnabled': hasContent,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await _matches.doc(matchId).set({
      'stats': stats,
      'events': events,
      'statsState': previewState.firestoreValue,
      'showStats': hasContent,
      'statsPreviewAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setDraftClient({
    required String matchId,
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> events,
  }) async {
    await docRef(matchId).set({
      'stats': stats,
      'events': events,
      'state': MatchStatsPublicationState.draft.firestoreValue,
      'previewEnabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await _matches.doc(matchId).set({
      'stats': stats,
      'events': events,
      'statsState': MatchStatsPublicationState.draft.firestoreValue,
      'showStats': false,
    }, SetOptions(merge: true));
  }

  Future<void> _syncLiveHubPreview(
    String matchId,
    Map<String, dynamic> stats,
  ) async {
    final liveRef = FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final liveMid = (live['matchId'] ?? '').toString().trim();
    final previewMid = (live['statsPreviewMatchId'] ?? '').toString().trim();
    if (liveMid != matchId && previewMid != matchId) return;

    final patch = <String, dynamic>{
      'statsEnabled': true,
      'statsPreviewMatchId': matchId,
      'statsPreviewUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (!MatchStatsSchema.isEmpty(stats)) {
      patch['statsPreview'] = stats;
      patch['stats'] = stats;
    }
    await liveRef.set(patch, SetOptions(merge: true));
  }

  Future<void> _clearLiveHubPreview(String matchId) async {
    final liveRef = FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final liveMid = (live['matchId'] ?? '').toString().trim();
    final previewMid = (live['statsPreviewMatchId'] ?? '').toString().trim();
    if (liveMid != matchId && previewMid != matchId) return;

    await liveRef.set({
      'statsPreview': FieldValue.delete(),
      'statsPreviewMatchId': FieldValue.delete(),
      'statsPreviewUpdatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
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
