import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match_lineup.dart';
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
    final events = MatchStatsSchema.eventsFromMatchDoc(m);

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

  /// Archive compositions live → fiche stats (résumés match, workbench).
  Future<void> syncLineups({
    required String matchId,
    required MatchLineupSide home,
    required MatchLineupSide away,
  }) async {
    final id = matchId.trim();
    if (id.isEmpty) return;
    if (!home.hasContent && !away.hasContent) return;

    await ensureFromMatch(id);
    await docRef(id).set({
      'lineupHome': home.toMap(),
      'lineupAway': away.toMap(),
      'lineupsSyncedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await _matches.doc(id).set({
      'lineupHome': home.toMap(),
      'lineupAway': away.toMap(),
      'lineupsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDraft({
    required String matchId,
    required Map<String, dynamic> stats,
    List<Map<String, dynamic>>? events,
    bool preservePublication = true,
  }) async {
    await ensureFromMatch(matchId);
    final normalized = MatchStatsSchema.normalizeMap(stats);

    final patch = <String, dynamic>{
      'stats': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    };
    if (events != null) {
      patch['events'] = events;
    }

    if (!preservePublication) {
      final hasContent = !MatchStatsSchema.isEmpty(normalized) ||
          (events != null && events.isNotEmpty);
      if (hasContent) {
        patch['state'] = MatchStatsPublicationState.draft.firestoreValue;
        patch['workbenchOpen'] = true;
      }
    }

    await docRef(matchId).set(patch, SetOptions(merge: true));
    await pushStatsToLiveHubIfEnabled(matchId);
  }

  /// Met à jour les interrupteurs publication (onglet Statistiques match).
  Future<void> updatePublicationSettings(
    String matchId,
    MatchStatsPublicationSettings settings,
  ) async {
    await ensureFromMatch(matchId);
    await docRef(matchId).set({
      ...settings.toSheetPatch(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
    await applyPublicationSettings(matchId);
  }

  /// Applique flags → `matches` (+ live si match en cours).
  Future<void> applyPublicationSettings(String matchId) async {
    final id = matchId.trim();
    if (id.isEmpty) return;

    final sheetSnap = await docRef(id).get();
    final matchSnap = await _matches.doc(id).get();
    if (!matchSnap.exists) return;

    final sheet = sheetSnap.data() ?? {};
    final m = matchSnap.data() ?? {};
    final pub = MatchStatsPublicationSettings.fromSheet(sheet);
    final stats = MatchStatsSchema.normalizeMap(
      sheet['stats'] as Map<String, dynamic>? ??
          m['stats'] as Map<String, dynamic>?,
    );
    final hasNumericStats = !MatchStatsSchema.isEmpty(stats);

    final matchPatch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (pub.cardDisplay && (hasNumericStats || pub.official)) {
      matchPatch['showStats'] = true;
      matchPatch['stats'] = stats;
      matchPatch['statsState'] = pub.official
          ? MatchStatsPublicationState.published.firestoreValue
          : MatchStatsPublicationState.preview.firestoreValue;
      if (!pub.official) {
        matchPatch['statsPreviewAt'] = FieldValue.serverTimestamp();
      }
    } else if (!pub.official) {
      matchPatch['showStats'] = false;
      matchPatch['statsState'] = MatchStatsPublicationState.draft.firestoreValue;
    }

    if (pub.official && hasNumericStats) {
      matchPatch['showStats'] = true;
      matchPatch['stats'] = stats;
      matchPatch['statsState'] =
          MatchStatsPublicationState.published.firestoreValue;
    }

    await _matches.doc(id).set(matchPatch, SetOptions(merge: true));

    if (pub.cardDisplay && hasNumericStats) {
      try {
        await syncNow(id);
      } catch (_) {}
    }
    await pushStatsToLiveHubIfEnabled(id);
  }

  /// Bandeau stats live — réservé à l’onglet Direct (`live/current.statsEnabled`).
  Future<void> setLiveStatsDisplay(
    String matchId, {
    required bool enabled,
  }) async {
    final id = matchId.trim();
    if (id.isEmpty) return;

    final liveRef =
        FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    if ((live['matchId'] ?? '').toString().trim() != id) return;

    final patch = <String, dynamic>{'statsEnabled': enabled};
    if (!enabled) {
      patch['stats'] = <String, dynamic>{};
      patch['statsPreview'] = <String, dynamic>{};
    }
    await liveRef.set(patch, SetOptions(merge: true));

    if (enabled) {
      await pushStatsToLiveHubIfEnabled(id);
    }
  }

  /// Copie les chiffres saisis vers le hub live si le direct les a activés.
  Future<void> pushStatsToLiveHubIfEnabled(String matchId) async {
    final id = matchId.trim();
    if (id.isEmpty) return;

    final liveRef =
        FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final liveMid = (live['matchId'] ?? '').toString().trim();
    if (liveMid != id || live['statsEnabled'] != true) return;

    final sheet = await get(id);
    final stats = MatchStatsSchema.normalizeMap(
      sheet?['stats'] as Map<String, dynamic>?,
    );
    if (MatchStatsSchema.isEmpty(stats)) return;

    await liveRef.set({
      'statsPreview': stats,
      'stats': stats,
      'statsPreviewMatchId': id,
      'statsPreviewUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Possession / chrono live → `live/current` seulement (pas `match_stats`, pas d’onWrite).
  Future<void> pushLiveCountersToHub(
    String matchId,
    Map<String, dynamic> stats,
  ) async {
    final id = matchId.trim();
    if (id.isEmpty) return;
    final liveRef =
        FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final liveMid = (live['matchId'] ?? '').toString().trim();
    if (liveMid != id || live['statsEnabled'] != true) return;

    final normalized = MatchStatsSchema.normalizeMap(stats);
    if (MatchStatsSchema.isEmpty(normalized)) return;
    await liveRef.set({
      'stats': normalized,
      'statsPreview': normalized,
      'statsPreviewMatchId': id,
      'statsPreviewUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Pousse immédiatement sur `matches` (onWrite + filet nuit, plus de cron 5 min).
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
    await pushStatsToLiveHubIfEnabled(matchId);
  }

  /// Change l’état publication (Cloud Function — évite permission-denied client).
  Future<void> setPublicationState(
    String matchId,
    MatchStatsPublicationState state,
  ) async {
    await ensureFromMatch(matchId);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setMatchStatsPublicationState')
          .call({
        'matchId': matchId,
        'state': state.firestoreValue,
      });
      return;
    } catch (_) {
      // Fallback si la CF n’est pas encore déployée.
    }

    if (state == MatchStatsPublicationState.published) {
      try {
        await finalize(matchId);
      } catch (_) {
        await _publishClient(matchId);
      }
      await updatePublicationSettings(
        matchId,
        const MatchStatsPublicationSettings(
          workbenchOpen: true,
          cardDisplay: true,
          official: true,
        ),
      );
      return;
    }

    if (state == MatchStatsPublicationState.preview) {
      await updatePublicationSettings(
        matchId,
        const MatchStatsPublicationSettings(
          workbenchOpen: true,
          liveDisplay: true,
          cardDisplay: true,
          official: false,
        ),
      );
      return;
    }

    await updatePublicationSettings(
      matchId,
      const MatchStatsPublicationSettings(
        workbenchOpen: true,
        cardDisplay: false,
        official: false,
      ),
    );
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
    final events = MatchStatsSchema.parseGameEvents(eventsRaw);
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

  /// Score / cartons sur le hub live — ne modifie jamais `statsEnabled` ni les stats chiffrées.
  Future<void> _syncLiveHubScores(
    String matchId, {
    int? scoreHome,
    int? scoreAway,
    int? yellowHome,
    int? yellowAway,
    int? redHome,
    int? redAway,
  }) async {
    final liveRef = FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final liveMid = (live['matchId'] ?? '').toString().trim();
    if (liveMid != matchId.trim()) return;

    final patch = <String, dynamic>{};
    if (scoreHome != null) patch['scoreHome'] = scoreHome;
    if (scoreAway != null) patch['scoreAway'] = scoreAway;
    if (yellowHome != null) patch['yellowHome'] = yellowHome;
    if (yellowAway != null) patch['yellowAway'] = yellowAway;
    if (redHome != null) patch['redHome'] = redHome;
    if (redAway != null) patch['redAway'] = redAway;
    if (patch.isEmpty) return;
    await liveRef.set(patch, SetOptions(merge: true));
  }

  /// Éditeur match : recopie la liste d’événements sur le hub live (évite que le live réécrase les suppressions).
  Future<void> _pushFactsToLiveHub({
    required String matchId,
    required List<Map<String, dynamic>> events,
    required int scoreHome,
    required int scoreAway,
    required int yellowHome,
    required int yellowAway,
    required int redHome,
    required int redAway,
  }) async {
    final liveRef = FirebaseFirestore.instance.collection('live').doc('current');
    final liveSnap = await liveRef.get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    if ((live['matchId'] ?? '').toString().trim() != matchId.trim()) return;

    await liveRef.set({
      'events': events,
      'scoreHome': scoreHome,
      'scoreAway': scoreAway,
      'yellowHome': yellowHome,
      'yellowAway': yellowAway,
      'redHome': redHome,
      'redAway': redAway,
    }, SetOptions(merge: true));
  }

  static List<Map<String, dynamic>> _eventsListFrom(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Pendant un live, les faits de jeu sur `live/current` priment sur la fiche.
  Future<List<Map<String, dynamic>>> _eventsForPublication(
    String matchId,
    Map<String, dynamic> sheet,
    Map<String, dynamic> match,
  ) async {
    final liveSnap =
        await FirebaseFirestore.instance.collection('live').doc('current').get();
    if (liveSnap.exists) {
      final live = liveSnap.data() ?? {};
      final liveMid = (live['matchId'] ?? '').toString().trim();
      if (liveMid == matchId.trim()) {
        final liveEvents = _eventsListFrom(live['events']);
        if (liveEvents.isNotEmpty) return liveEvents;
      }
    }
    final eventsRaw = sheet['events'] ?? match['events'];
    return MatchStatsSchema.parseGameEvents(eventsRaw);
  }

  /// Copie `live/current` → `matches/{id}` + `match_stats/{id}` (carte app + admin stats).
  Future<void> syncFromLiveCurrent({bool tryCloudSync = true}) async {
    final liveSnap =
        await FirebaseFirestore.instance.collection('live').doc('current').get();
    if (!liveSnap.exists) return;
    final live = liveSnap.data() ?? {};
    final matchId = (live['matchId'] as String? ?? '').trim();
    if (matchId.isEmpty) return;

    final events = _eventsListFrom(live['events']);
    final stats = MatchStatsSchema.normalizeMap(
      live['stats'] as Map<String, dynamic>? ??
          live['statsPreview'] as Map<String, dynamic>?,
    );

    await syncMatchFacts(
      matchId: matchId,
      events: events,
      yellowHome: (live['yellowHome'] as num?)?.toInt() ?? 0,
      yellowAway: (live['yellowAway'] as num?)?.toInt() ?? 0,
      redHome: (live['redHome'] as num?)?.toInt() ?? 0,
      redAway: (live['redAway'] as num?)?.toInt() ?? 0,
      scoreHome: (live['scoreHome'] as num?)?.toInt(),
      scoreAway: (live['scoreAway'] as num?)?.toInt(),
      tryCloudSync: tryCloudSync,
    );
  }

  /// Live / éditeur match : score, buteurs, cartons — sans publier les stats chiffrées.
  Future<void> syncMatchFacts({
    required String matchId,
    required List<Map<String, dynamic>> events,
    int yellowHome = 0,
    int yellowAway = 0,
    int redHome = 0,
    int redAway = 0,
    int? scoreHome,
    int? scoreAway,
    bool tryCloudSync = false,
    /// true quand la fiche match est la source (suppressions / corrections manuelles).
    bool pushEventsToLiveHub = false,
  }) async {
    await ensureFromMatch(matchId);
    final matchSnap = await _matches.doc(matchId).get();
    final m = matchSnap.data() ?? {};
    final t1 = (m['team1'] as String? ?? '').trim();
    final t2 = (m['team2'] as String? ?? '').trim();
    final eventCounts = MatchStatsSchema.countFromEvents(events, t1, t2);
    final resolved = MatchStatsSchema.resolveMatchScores(m, events: events);

    var finalHome = scoreHome ?? resolved.home;
    var finalAway = scoreAway ?? resolved.away;
    if (eventCounts.totalGoals > 0) {
      finalHome = eventCounts.goalsHome;
      finalAway = eventCounts.goalsAway;
      if (scoreHome != null && scoreAway != null) {
        finalHome = scoreHome > eventCounts.goalsHome
            ? scoreHome
            : eventCounts.goalsHome;
        finalAway = scoreAway > eventCounts.goalsAway
            ? scoreAway
            : eventCounts.goalsAway;
      }
    }

    int finalYH;
    int finalYA;
    int finalRH;
    int finalRA;
    if (pushEventsToLiveHub) {
      finalYH = eventCounts.yellowHome;
      finalYA = eventCounts.yellowAway;
      finalRH = eventCounts.redHome;
      finalRA = eventCounts.redAway;
    } else {
      finalYH = yellowHome;
      finalYA = yellowAway;
      finalRH = redHome;
      finalRA = redAway;
      if (eventCounts.totalCards > 0) {
        finalYH = eventCounts.yellowHome > finalYH
            ? eventCounts.yellowHome
            : finalYH;
        finalYA = eventCounts.yellowAway > finalYA
            ? eventCounts.yellowAway
            : finalYA;
        finalRH = eventCounts.redHome > finalRH ? eventCounts.redHome : finalRH;
        finalRA = eventCounts.redAway > finalRA ? eventCounts.redAway : finalRA;
      }
    }

    await docRef(matchId).set({
      'events': events,
      'factsSyncedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await _matches.doc(matchId).set({
      'events': events,
      'yellowHome': finalYH,
      'yellowAway': finalYA,
      'redHome': finalRH,
      'redAway': finalRA,
      'score1': finalHome,
      'score2': finalAway,
      'scoreHome': finalHome,
      'scoreAway': finalAway,
    }, SetOptions(merge: true));

    if (pushEventsToLiveHub) {
      await _pushFactsToLiveHub(
        matchId: matchId,
        events: events,
        scoreHome: finalHome,
        scoreAway: finalAway,
        yellowHome: finalYH,
        yellowAway: finalYA,
        redHome: finalRH,
        redAway: finalRA,
      );
    } else {
      await _syncLiveHubScores(
        matchId,
        scoreHome: finalHome,
        scoreAway: finalAway,
        yellowHome: finalYH,
        yellowAway: finalYA,
        redHome: finalRH,
        redAway: finalRA,
      );
    }
    await pushStatsToLiveHubIfEnabled(matchId);
  }

  /// Pousse la fiche `match_stats` vers la carte match (après saisie workbench).
  Future<void> publishSheetToMatch(String matchId, {bool tryCloudSync = true}) async {
    final id = matchId.trim();
    if (id.isEmpty) return;

    final sheetSnap = await docRef(id).get();
    final matchSnap = await _matches.doc(id).get();
    if (!matchSnap.exists) return;

    final sheet = sheetSnap.data() ?? {};
    final m = matchSnap.data() ?? {};
    var events = _eventsListFrom(sheet['events']);
    if (events.isEmpty) {
      events = MatchStatsSchema.eventsFromMatchDoc(m);
    }

    final stats = MatchStatsSchema.normalizeMap(
      sheet['stats'] as Map<String, dynamic>? ??
          m['stats'] as Map<String, dynamic>?,
    );

    await saveDraft(matchId: id, stats: stats, events: events);
    await applyPublicationSettings(id);
    if (tryCloudSync) {
      try {
        await syncNow(id);
      } catch (_) {}
    }
  }

  /// Après édition admin (buteurs, cartons) : fiche `match_stats`, `matches` et live.
  Future<void> syncFromMatchEditor({
    required String matchId,
    required List<Map<String, dynamic>> events,
    int yellowHome = 0,
    int yellowAway = 0,
    int redHome = 0,
    int redAway = 0,
    int? scoreHome,
    int? scoreAway,
    Map<String, dynamic>? stats,
    bool tryCloudSync = false,
    bool factsOnly = false,
  }) async {
    final sheetStats = stats != null
        ? MatchStatsSchema.normalizeMap(stats)
        : null;

    if (factsOnly || sheetStats == null || MatchStatsSchema.isEmpty(sheetStats)) {
      final pushLive = await _isThisMatchLiveOnHub(matchId);
      await syncMatchFacts(
        matchId: matchId,
        events: events,
        yellowHome: yellowHome,
        yellowAway: yellowAway,
        redHome: redHome,
        redAway: redAway,
        scoreHome: scoreHome,
        scoreAway: scoreAway,
        tryCloudSync: tryCloudSync,
        pushEventsToLiveHub: pushLive,
      );
      return;
    }

    await saveDraft(
      matchId: matchId,
      stats: sheetStats,
      events: events,
    );
    await syncMatchFacts(
      matchId: matchId,
      events: events,
      yellowHome: yellowHome,
      yellowAway: yellowAway,
      redHome: redHome,
      redAway: redAway,
      scoreHome: scoreHome,
      scoreAway: scoreAway,
      tryCloudSync: false,
      pushEventsToLiveHub: true,
    );
    if (tryCloudSync) {
      await applyPublicationSettings(matchId);
    }
  }

  /// `live/current` pointe sur ce match calendrier (pas un id `live_*` fantôme).
  Future<bool> _isThisMatchLiveOnHub(String matchId) async {
    final id = matchId.trim();
    if (id.isEmpty || id.startsWith('live_')) return false;
    final snap = await FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .get();
    if (!snap.exists) return false;
    return (snap.data()?['matchId'] as String? ?? '').trim() == id;
  }

  Future<bool> isMatchLiveOnHub(String matchId) =>
      _isThisMatchLiveOnHub(matchId);

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

  /// Fin de direct : archive stats et faits live dans `match_stats/{matchId}`.
  Future<void> archiveFromLiveEnd({
    required String matchId,
    Map<String, dynamic>? stats,
    dynamic events,
    required int scoreHome,
    required int scoreAway,
    int yellowHome = 0,
    int yellowAway = 0,
    int redHome = 0,
    int redAway = 0,
  }) async {
    final id = matchId.trim();
    if (id.isEmpty) return;
    await ensureFromMatch(id);

    final normalized =
        stats != null ? MatchStatsSchema.normalizeMap(stats) : null;
    final parsedEvents = events is List
        ? events
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : null;

    final patch = <String, dynamic>{
      'matchId': id,
      'archivedFromLiveAt': FieldValue.serverTimestamp(),
      'workbenchOpen': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    };
    if (normalized != null && !MatchStatsSchema.isEmpty(normalized)) {
      patch['stats'] = normalized;
      patch['state'] = MatchStatsPublicationState.preview.firestoreValue;
      patch['previewEnabled'] = true;
    }
    if (parsedEvents != null && parsedEvents.isNotEmpty) {
      patch['events'] = parsedEvents;
      patch['state'] = MatchStatsPublicationState.preview.firestoreValue;
      patch['previewEnabled'] = true;
    }
    if (patch.length > 4) {
      await docRef(id).set(patch, SetOptions(merge: true));
    }

    if (parsedEvents != null && parsedEvents.isNotEmpty) {
      await syncMatchFacts(
        matchId: id,
        events: parsedEvents,
        yellowHome: yellowHome,
        yellowAway: yellowAway,
        redHome: redHome,
        redAway: redAway,
        scoreHome: scoreHome,
        scoreAway: scoreAway,
        pushEventsToLiveHub: false,
      );
    }
  }

  /// Prépare la fiche stats avant le match (brouillon vide prêt à saisir).
  Future<void> prepareSession(String matchId) async {
    await ensureFromMatch(matchId);
    final sheet = await get(matchId);
    await docRef(matchId).set({
      'workbenchOpen': true,
      'cardDisplay': sheet?['cardDisplay'] == true,
      'state': sheet?['state'] ??
          MatchStatsPublicationState.draft.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  /// Admin : efface stats chiffrées + buteurs/cartons pour tous les matchs Sedan d'une saison.
  Future<Map<String, dynamic>> resetSedanSeasonStats({
    required String seasonLabel,
    required String activeSeasonLabel,
    String? implicitLegacySeasonLabel,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('resetSedanSeasonStats')
        .call({
          'season': seasonLabel.trim(),
          'activeSeasonLabel': activeSeasonLabel.trim(),
          'implicitLegacySeasonLabel':
              (implicitLegacySeasonLabel ?? activeSeasonLabel).trim(),
        });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const {};
  }
}
