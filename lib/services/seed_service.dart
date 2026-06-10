import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/match_lineup.dart';
import '../utils/youtube_parser.dart';
import 'match_rating_service.dart';
import 'match_stats_sheet_service.dart';
import 'live_match_activity_service.dart';

/// Gestion du document live/current dans Firestore
class SeedService {
  static final _db = FirebaseFirestore.instance;
  static Timer? _mirrorStatsDebounce;
  static Timer? _mirrorFactsDebounce;

  static List<Map<String, dynamic>> _eventsFromLiveData(
    Map<String, dynamic> data,
  ) {
    final raw = data['events'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static bool _sameEventIdentity(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final idA = (a['id'] ?? '').toString();
    final idB = (b['id'] ?? '').toString();
    if (idA.isNotEmpty && idB.isNotEmpty) return idA == idB;
    return (a['type'] ?? '').toString() == (b['type'] ?? '').toString() &&
        (a['minute'] ?? 0) == (b['minute'] ?? 0) &&
        (a['player'] ?? '').toString() == (b['player'] ?? '').toString() &&
        (a['team'] ?? '').toString() == (b['team'] ?? '').toString();
  }

  static Future<void> _mirrorLiveFactsToMatch({bool tryCloudSync = false}) async {
    try {
      await MatchStatsSheetService.instance.syncFromLiveCurrent(
        tryCloudSync: tryCloudSync,
      );
    } catch (e, st) {
      debugPrint('DVCR mirror live→match: $e\n$st');
    }
  }

  /// Copie live → fiche match sans réécrire les faits de jeu sur `live/current`.
  static void _mirrorLiveFactsDebounced() {
    _mirrorFactsDebounce?.cancel();
    _mirrorFactsDebounce = Timer(const Duration(milliseconds: 450), () {
      _mirrorFactsDebounce = null;
      unawaited(_mirrorLiveFactsToMatch(tryCloudSync: false));
    });
  }

  /// Stats chiffrées (possession, tirs…) : debounce pour ne pas spammer Firestore.
  static void _mirrorLiveStatsDebounced() {
    _mirrorStatsDebounce?.cancel();
    _mirrorStatsDebounce = Timer(const Duration(seconds: 2), () {
      _mirrorStatsDebounce = null;
      unawaited(_mirrorLiveFactsToMatch(tryCloudSync: false));
    });
  }

  /// Met à jour l’URL YouTube du direct (sans traçage `si=` / attribution).
  static Future<void> updateLiveStreamUrl(String url) async {
    final clean = YoutubeParser.sanitizeShareUrl(url);
    await _db.collection('live').doc('current').set({
      'url': clean,
      'streamBroadcast': clean.isNotEmpty,
      'urlSharedByUid': FieldValue.delete(),
      'urlSharedByName': FieldValue.delete(),
      'urlSharedByFirstName': FieldValue.delete(),
      'showUrlSharedBy': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Démarre un live — crée live/current
  static Future<void> startLive({
    required String url,
    String team1 = '',
    String team2 = '',
    String? matchId,
    String? logo1,
    String? logo2,
    int viewers = 0,
    bool streamBroadcast = true,
    bool tvBroadcast = false,
  }) async {
    // Ne pas modifier `matches/{matchId}` ici : stats / score / events restent jusqu’à
    // suppression explicite dans l’admin (onglet Stats) ou fin de live (`clearLive`).

    var resolvedMatchId = (matchId ?? '').trim();
    if (resolvedMatchId.isEmpty) {
      resolvedMatchId = 'live_${DateTime.now().millisecondsSinceEpoch}';
    }

    final streamUrl = streamBroadcast
        ? YoutubeParser.sanitizeShareUrl(url)
        : '';

    await _db.collection('live').doc('current').set({
      'url': streamUrl,
      'streamBroadcast': streamBroadcast,
      'logo1': logo1 ?? '',
      'logo2': logo2 ?? '',
      'live_viewers': viewers,
      'viewers': viewers,
      'tvBroadcast': tvBroadcast,
      'team1': team1,
      'team2': team2,
      'matchId': resolvedMatchId,
      'scoreHome': 0,
      'scoreAway': 0,
      'yellowHome': 0,
      'yellowAway': 0,
      'redHome': 0,
      'redAway': 0,
      'minute': 0,
      'events': [],
      'statsEnabled': false,
      'stats': {},
      'manOfTheMatchName': '',
      'manOfTheMatchPartnerName': '',
      'manOfTheMatchPartnerLogo': '',
      'motmVoteEnabled': false,
      'motmVoteStatus': '',
      'motmVoteMode': '',
      'motmVoteSessionId': '',
      'motmVoteTitle': '',
      'motmVoteTeamName': '',
      'motmVoteTeams': [],
      'motmVoteSponsorName': '',
      'motmVoteSponsorLogo': '',
      'motmVoteBackgroundImage': '',
      'motmVoteRevealWinner': true,
      'motmVoteCandidates': [],
      'motmVoteCounts': {},
      'motmVoteTotal': 0,
      'motmVoteWinnerId': '',
      'motmVoteWinnerName': '',
      'motmVoteWinnerVotes': 0,
      'motmVoteWinnerTeamId': '',
      'motmVoteWinnerTeamName': '',
      'motmVoteEndedReason': '',
      'matchRatingPending': false,
      'matchRatingStatus': '',
      'matchRatingSessionId': '',
      'matchRatingTitle': '',
      'matchRatingBackgroundImage': '',
      'matchRatingCounts': <String, int>{},
      'matchRatingTotal': 0,
      'matchRatingSum': 0,
      'matchRatingAverage': 0.0,
      'lineupHome': <String, dynamic>{
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
      'lineupAway': <String, dynamic>{
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
      'showLineupOnCard': false,
      'chronoRunning': false,
      'chronoBaseSeconds': 0,
      'chronoStartedAtMs': 0,
      'lastEvent': '',
    });
  }

  /// Score brut (éviter en admin : préférer [addMatchEvent] / [revokeRegisteredGoal]).
  static Future<void> updateLiveScore(int home, int away) async {
    await _db.collection('live').doc('current').update({
      'scoreHome': home,
      'scoreAway': away,
    });
  }

  static bool isGoalScorerValid(String player) {
    final p = player.trim();
    return p.isNotEmpty && p.toLowerCase() != 'inconnu';
  }

  static Map<String, dynamic> _chronoPausedAtMinute(int minute) {
    final seconds = minute * 60;
    return {
      'chronoBaseSeconds': seconds,
      'chronoStartedAtMs': 0,
      'chronoRunning': false,
      'minute': minute,
    };
  }

  /// Mi-temps : bloque le chrono à 45′ + notif Cloud Function.
  static Future<void> notifyHalftime() async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'halftime',
      ..._chronoPausedAtMinute(45),
    });
  }

  /// Fin de match : bloque le chrono + ouvre la note du match + notif Cloud Function.
  static Future<void> notifyFulltime(int minute) async {
    final snap = await _db.collection('live').doc('current').get();
    final data = snap.data() ?? <String, dynamic>{};
    await _db.collection('live').doc('current').update({
      'lastEvent': 'fulltime',
      ..._chronoPausedAtMinute(minute),
      ...MatchRatingService.newSessionFields(data),
    });
  }

  /// Reprise 2e mi-temps après la pause (45′ par défaut).
  static Future<void> resumeSecondHalf({int startMinute = 45}) async {
    await _db.collection('live').doc('current').update({
      'lastEvent': '',
      ..._chronoPausedAtMinute(startMinute),
    });
  }

  /// Prolongations : 90′ et chrono repart (uniquement au clic admin PROLONG.).
  static Future<void> startExtraTime({int startMinute = 90}) async {
    final seconds = startMinute * 60;
    await _db.collection('live').doc('current').update({
      'lastEvent': 'extra_time',
      'chronoBaseSeconds': seconds,
      'chronoStartedAtMs': DateTime.now().millisecondsSinceEpoch,
      'chronoRunning': true,
      'minute': startMinute,
    });
  }

  /// Mi-temps des prolongations (105′).
  static Future<void> notifyExtraHalftime() async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'extra_halftime',
      ..._chronoPausedAtMinute(105),
    });
  }

  /// Fin des prolongations (+ notif + note du match).
  static Future<void> notifyExtraFulltime(int minute) async {
    final snap = await _db.collection('live').doc('current').get();
    final data = snap.data() ?? <String, dynamic>{};
    await _db.collection('live').doc('current').update({
      'lastEvent': 'extra_fulltime',
      ..._chronoPausedAtMinute(minute),
      ...MatchRatingService.newSessionFields(data),
    });
  }

  /// Reprise 2e période de prolongation (106′).
  static Future<void> resumeExtraSecondHalf({int startMinute = 106}) async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'extra_time',
      ..._chronoPausedAtMinute(startMinute),
    });
  }

  /// Annule l’affichage mi-temps (sans changer la minute).
  static Future<void> clearMatchPhase() async {
    await _db.collection('live').doc('current').update({
      'lastEvent': '',
    });
  }

  /// Termine le live — coupe `live/current` tout de suite, archive le match en arrière-plan.
  static Future<void> clearLive() async {
    final liveRef = _db.collection('live').doc('current');
    final snap = await liveRef.get();
    if (!snap.exists) return;

    final data = Map<String, dynamic>.from(snap.data() as Map<String, dynamic>);
    await liveRef.delete();
    unawaited(LiveMatchActivityService.dismissNow());
    unawaited(_persistLiveEndSnapshot(data));
  }

  static Future<void> _persistLiveEndSnapshot(Map<String, dynamic> data) async {
    final matchId = (data['matchId'] as String? ?? '').trim();
    if (matchId.isEmpty || matchId.startsWith('live_')) return;

    final stats = data['stats'] as Map<String, dynamic>?;
    final events = data['events'];
    final scoreHome = data['scoreHome'] ?? 0;
    final scoreAway = data['scoreAway'] ?? 0;
    final yellowHome = data['yellowHome'] ?? 0;
    final yellowAway = data['yellowAway'] ?? 0;
    final redHome = data['redHome'] ?? 0;
    final redAway = data['redAway'] ?? 0;
    final manOfTheMatch = data['manOfTheMatchName'] ?? '';
    final manPartnerName = data['manOfTheMatchPartnerName'] ?? '';
    final manPartnerLogo = data['manOfTheMatchPartnerLogo'] ?? '';

    final saveData = <String, dynamic>{
      'scoreHome': scoreHome,
      'scoreAway': scoreAway,
      'score1': scoreHome,
      'score2': scoreAway,
      'yellowHome': yellowHome,
      'yellowAway': yellowAway,
      'redHome': redHome,
      'redAway': redAway,
      'status': 'finished',
    };
    if (events is List && events.isNotEmpty) {
      saveData['events'] = events;
    }
    if (manOfTheMatch.toString().isNotEmpty) {
      saveData['manOfTheMatchName'] = manOfTheMatch;
      saveData['manOfTheMatchPartnerName'] = manPartnerName;
      saveData['manOfTheMatchPartnerLogo'] = manPartnerLogo;
    }

    final ratingTotal = data['matchRatingTotal'];
    if (ratingTotal is num && ratingTotal.toInt() > 0) {
      final avg = data['matchRatingAverage'];
      final sum = data['matchRatingSum'];
      if (avg is num) {
        saveData['matchRatingAverage'] = avg.toDouble();
      }
      saveData['matchRatingTotal'] = ratingTotal.toInt();
      if (sum is num) saveData['matchRatingSum'] = sum.toInt();
    }

    final lineupHome = data['lineupHome'];
    final lineupAway = data['lineupAway'];
    if (lineupHome is Map) saveData['lineupHome'] = lineupHome;
    if (lineupAway is Map) saveData['lineupAway'] = lineupAway;
    if (data['showLineupOnCard'] == true) {
      saveData['showLineupOnCard'] = true;
    }

    try {
      await _db.collection('matches').doc(matchId).set(
        saveData,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('DVCR clearLive matches write: $e');
      final fallback = Map<String, dynamic>.from(saveData)
        ..remove('stats')
        ..remove('events');
      try {
        await _db.collection('matches').doc(matchId).set(
          fallback,
          SetOptions(merge: true),
        );
      } catch (e2) {
        debugPrint('DVCR clearLive matches fallback: $e2');
      }
    }

    try {
      await MatchStatsSheetService.instance.archiveFromLiveEnd(
        matchId: matchId,
        stats: stats,
        events: events,
        scoreHome: scoreHome is int ? scoreHome : (scoreHome as num).toInt(),
        scoreAway: scoreAway is int ? scoreAway : (scoreAway as num).toInt(),
        yellowHome: yellowHome is int ? yellowHome : (yellowHome as num).toInt(),
        yellowAway: yellowAway is int ? yellowAway : (yellowAway as num).toInt(),
        redHome: redHome is int ? redHome : (redHome as num).toInt(),
        redAway: redAway is int ? redAway : (redAway as num).toInt(),
      );
      final homeSide = MatchLineupSide.fromMap(
        data['lineupHome'] as Map<String, dynamic>?,
      );
      final awaySide = MatchLineupSide.fromMap(
        data['lineupAway'] as Map<String, dynamic>?,
      );
      if (homeSide.hasContent || awaySide.hasContent) {
        await MatchStatsSheetService.instance.syncLineups(
          matchId: matchId,
          home: homeSide,
          away: awaySide,
        );
      }
    } catch (e) {
      debugPrint('DVCR archiveFromLiveEnd: $e');
    }
  }

  /// Archive les salons chat marqués live (fin de direct).
  static Future<void> archiveLiveChatSalons() async {
    final existing = await _db
        .collection('chat_salons')
        .where('isLive', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .get();
    if (existing.docs.isEmpty) return;

    var batch = _db.batch();
    var ops = 0;
    for (final doc in existing.docs) {
      // Ne pas archiver tout de suite : le salon reste visible 2h côté client.
      batch.update(doc.reference, {
        'isLive': false,
        'liveEndedAt': FieldValue.serverTimestamp(),
      });
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  /// Termine le direct : coupe le hub live immédiatement, persiste en arrière-plan.
  static Future<void> endLiveSession() async {
    await clearLive();
    unawaited(
      archiveLiveChatSalons().catchError((Object e) {
        debugPrint('DVCR archiveLiveChatSalons: $e');
      }),
    );
  }

  /// Crée le salon chat live (archive les anciens salons actifs).
  static Future<void> createLiveChatSalon({
    required String matchId,
    required String name,
  }) async {
    final existing = await _db
        .collection('chat_salons')
        .where('isLive', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.update({
        'archived': true,
        'isLive': false,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
    await _db.collection('chat_salons').doc('live_$matchId').set({
      'name': name,
      'isLive': true,
      'archived': false,
      'matchId': matchId,
      'order': -1,
      'createdAt': FieldValue.serverTimestamp(),
      'archivedAt': null,
    });
  }

  /// Démarre le direct + salon chat associé.
  static Future<void> beginLiveSession({
    required String url,
    required String team1,
    required String team2,
    required String matchId,
    String? logo1,
    String? logo2,
    bool streamBroadcast = true,
    bool tvBroadcast = false,
  }) async {
    await startLive(
      url: url,
      team1: team1,
      team2: team2,
      matchId: matchId,
      logo1: logo1,
      logo2: logo2,
      streamBroadcast: streamBroadcast,
      tvBroadcast: tvBroadcast,
    );
    try {
      await createLiveChatSalon(
        matchId: matchId,
        name: '🔴 Live — $team1 vs $team2',
      );
    } catch (_) {
      // Live lancé même si le salon chat ne peut pas être créé (droits Firestore).
    }
  }

  /// Cartons : uniquement [live/current] pendant le direct.
  static Future<void> updateCards({
    required int yellowHome,
    required int yellowAway,
    required int redHome,
    required int redAway,
  }) async {
    await _db.collection('live').doc('current').update({
      'yellowHome': yellowHome,
      'yellowAway': yellowAway,
      'redHome': redHome,
      'redAway': redAway,
    });
  }

  /// Met à jour minute + base chrono (admin édition manuelle).
  static Future<void> setMinuteWithChrono(int minute) async {
    final seconds = minute * 60;
    await _db.collection('live').doc('current').update({
      'minute': minute,
      'chronoBaseSeconds': seconds,
    });
  }

  /// Met à jour la minute du match
  static Future<void> updateMinute(int minute) async {
    await _db.collection('live').doc('current').update({'minute': minute});
  }

  /// Démarre/met à jour le chrono (pour affichage temps réel côté app)
  static Future<void> startChrono(int baseSeconds) async {
    await _db.collection('live').doc('current').update({
      'chronoBaseSeconds': baseSeconds,
      'chronoStartedAtMs': DateTime.now().millisecondsSinceEpoch,
      'chronoRunning': true,
      'minute': baseSeconds ~/ 60,
    });
  }

  /// Pause le chrono
  static Future<void> pauseChrono(int baseSeconds) async {
    await _db.collection('live').doc('current').update({
      'chronoBaseSeconds': baseSeconds,
      'chronoStartedAtMs': 0,
      'chronoRunning': false,
    });
  }

  /// Ajoute un événement but
  static Future<void> addGoalEvent({
    required String team,
    required String player,
    required int minute,
  }) async {
    await addMatchEvent(
      type: 'goal',
      team: team,
      player: player,
      minute: minute,
    );
  }

  static Map<String, dynamic> _eventPayload({
    required String type,
    required String team,
    required String player,
    required int minute,
  }) {
    return {
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'team': team.trim(),
      'player': player,
      'minute': minute,
    };
  }

  static bool _sameGoalEvent(Map<String, dynamic> a, Map<String, dynamic> b) {
    final idA = (a['id'] ?? '').toString();
    final idB = (b['id'] ?? '').toString();
    if (idA.isNotEmpty && idB.isNotEmpty && idA == idB) return true;
    return (a['type'] ?? '').toString() == 'goal' &&
        (b['type'] ?? '').toString() == 'goal' &&
        (a['team'] ?? '').toString() == (b['team'] ?? '').toString() &&
        (a['player'] ?? '').toString() == (b['player'] ?? '').toString() &&
        (a['minute'] ?? 0) == (b['minute'] ?? 0);
  }

  static Map<String, dynamic> _lastAlertPayload({
    required String type,
    required Map<String, dynamic> data,
    required String team,
    required String player,
    required int minute,
    int? scoreHome,
    int? scoreAway,
  }) {
    return {
      'type': type,
      'team': team.trim(),
      'player': player,
      'minute': minute,
      'team1': data['team1'] ?? '',
      'team2': data['team2'] ?? '',
      'scoreHome': scoreHome ?? (data['scoreHome'] as int?) ?? 0,
      'scoreAway': scoreAway ?? (data['scoreAway'] as int?) ?? 0,
      'matchId': data['matchId'] ?? '',
    };
  }

  static Future<void> addMatchEvent({
    required String type,
    required String team,
    required String player,
    required int minute,
    String? playerIn,
  }) async {
    final trimmedPlayer = player.trim();
    if (type == 'goal' && !isGoalScorerValid(trimmedPlayer)) {
      throw StateError('goal_scorer_required');
    }
    if (type == 'substitution') {
      final out = trimmedPlayer;
      final inn = (playerIn ?? '').trim();
      if (out.isEmpty && inn.isEmpty) {
        throw StateError('substitution_players_required');
      }
    }
    final resolvedPlayer = trimmedPlayer.isEmpty ? 'Inconnu' : trimmedPlayer;

    final docRef = _db.collection('live').doc('current');
    final preSnap = await docRef.get();
    final preData = preSnap.data() ?? <String, dynamic>{};
    final team1Pre = (preData['team1'] as String? ?? '').trim().toUpperCase();
    final team2Pre = (preData['team2'] as String? ?? '').trim().toUpperCase();
    final upperTeam = team.trim().toUpperCase();
    final isHomePre =
        team1Pre.isNotEmpty ? upperTeam == team1Pre : upperTeam != team2Pre;

    final event = _eventPayload(
      type: type,
      team: team,
      player: resolvedPlayer,
      minute: minute,
    );
    event['isHome'] = isHomePre;
    if (type == 'substitution') {
      final inn = (playerIn ?? '').trim();
      event['playerOut'] = resolvedPlayer == 'Inconnu' && trimmedPlayer.isEmpty
          ? '?'
          : resolvedPlayer;
      event['playerIn'] = inn.isEmpty ? '?' : inn;
      event['player'] = event['playerOut'];
    }
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final upperTeam = team.trim().toUpperCase();
      final isHome = team1.isNotEmpty ? upperTeam == team1 : upperTeam != team2;

      final events = _eventsFromLiveData(data)..add(event);
      final updates = <String, dynamic>{'events': events};
      if (type == 'substitution') {
        updates['lastEventAlert'] = _lastAlertPayload(
          type: 'substitution',
          data: data,
          team: team,
          player: resolvedPlayer,
          minute: minute,
        );
        tx.update(docRef, updates);
        return;
      }
      if (type == 'goal') {
        final field = isHome ? 'scoreHome' : 'scoreAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
        updates['lastEventAlert'] = _lastAlertPayload(
          type: 'goal',
          data: data,
          team: team,
          player: resolvedPlayer,
          minute: minute,
          scoreHome: isHome
              ? ((data['scoreHome'] as int?) ?? 0) + 1
              : (data['scoreHome'] as int?) ?? 0,
          scoreAway: !isHome
              ? ((data['scoreAway'] as int?) ?? 0) + 1
              : (data['scoreAway'] as int?) ?? 0,
        );
      } else if (type == 'yellow') {
        final field = isHome ? 'yellowHome' : 'yellowAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
        updates['lastEventAlert'] = _lastAlertPayload(
          type: 'yellow',
          data: data,
          team: team,
          player: resolvedPlayer,
          minute: minute,
        );
      } else if (type == 'red') {
        final field = isHome ? 'redHome' : 'redAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
        updates['lastEventAlert'] = _lastAlertPayload(
          type: 'red',
          data: data,
          team: team,
          player: resolvedPlayer,
          minute: minute,
        );
      }
      tx.update(docRef, updates);
    });
    _mirrorLiveFactsDebounced();
  }

  /// Retire un but enregistré : annulé, refusé ou hors-jeu (+ notif live).
  static Future<void> revokeRegisteredGoal({
    required Map<String, dynamic> goalEvent,
    required String revokeType,
  }) async {
    assert(
      revokeType == 'goal_cancelled' ||
          revokeType == 'goal_disallowed' ||
          revokeType == 'offside',
    );
    final docRef = _db.collection('live').doc('current');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final raw = data['events'];
      final events = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final idx = events.indexWhere((e) => _sameGoalEvent(e, goalEvent));
      if (idx < 0) return;

      final goal = Map<String, dynamic>.from(events[idx]);
      events.removeAt(idx);

      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final goalTeam = (goal['team'] as String? ?? '').trim().toUpperCase();
      final isHome =
          team1.isNotEmpty ? goalTeam == team1 : goalTeam != team2;
      final newHome = isHome
          ? (((data['scoreHome'] as int?) ?? 0) - 1).clamp(0, 999)
          : ((data['scoreHome'] as int?) ?? 0);
      final newAway = !isHome
          ? (((data['scoreAway'] as int?) ?? 0) - 1).clamp(0, 999)
          : ((data['scoreAway'] as int?) ?? 0);

      events.add(
        _eventPayload(
          type: revokeType,
          team: (goal['team'] as String? ?? '').toString(),
          player: (goal['player'] as String? ?? 'Inconnu').toString(),
          minute: (goal['minute'] as num?)?.toInt() ?? 0,
        ),
      );

      tx.update(docRef, {
        'events': events,
        'scoreHome': newHome,
        'scoreAway': newAway,
        'lastEventAlert': _lastAlertPayload(
          type: revokeType,
          data: data,
          team: (goal['team'] as String? ?? '').toString(),
          player: (goal['player'] as String? ?? '').toString(),
          minute: (goal['minute'] as num?)?.toInt() ?? 0,
          scoreHome: newHome,
          scoreAway: newAway,
        ),
      });
    });
    _mirrorLiveFactsDebounced();
  }

  static Future<void> removeMatchEvent(Map<String, dynamic> event) async {
    final docRef = _db.collection('live').doc('current');
    final target = Map<String, dynamic>.from(event);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final type = (target['type'] as String? ?? '').trim();
      final team = (target['team'] as String? ?? '').trim().toUpperCase();
      final isHome = team1.isNotEmpty ? team == team1 : team != team2;

      final events = _eventsFromLiveData(data)
        ..removeWhere((e) => _sameEventIdentity(e, target));

      final updates = <String, dynamic>{'events': events};
      if (type == 'goal') {
        final field = isHome ? 'scoreHome' : 'scoreAway';
        updates[field] = (((data[field] as int?) ?? 0) - 1).clamp(0, 999);
      } else if (type == 'yellow') {
        final field = isHome ? 'yellowHome' : 'yellowAway';
        updates[field] = (((data[field] as int?) ?? 0) - 1).clamp(0, 999);
      } else if (type == 'red') {
        final field = isHome ? 'redHome' : 'redAway';
        updates[field] = (((data[field] as int?) ?? 0) - 1).clamp(0, 999);
      }
      tx.update(docRef, updates);
    });
    _mirrorLiveFactsDebounced();
  }

  static Future<void> setManOfTheMatch({
    required String player,
    String partnerName = '',
    String partnerLogo = '',
  }) async {
    await _db.collection('live').doc('current').update({
      'manOfTheMatchName': player,
      'manOfTheMatchPartnerName': partnerName,
      'manOfTheMatchPartnerLogo': partnerLogo,
    });
  }

  /// Stats live : écrit [live/current] puis copie vers carte + `match_stats` (debounce 2 s).
  static Future<void> setLiveStats(Map<String, dynamic> stats) async {
    await _db.collection('live').doc('current').update({
      'stats': stats,
      'statsEnabled': true,
    });
    _mirrorLiveStatsDebounced();
  }

  /// Repasse en « attente » : stats OFF + chiffres vidés (tests / reset staff).
  static Future<void> resetLiveStatsToWaiting() async {
    await _db.collection('live').doc('current').update({
      'statsEnabled': false,
      'stats': <String, dynamic>{},
      'statsPreview': FieldValue.delete(),
      'statsPreviewMatchId': FieldValue.delete(),
      'statsPreviewAt': FieldValue.delete(),
    });
  }

  /// Vide les chiffres mais laisse le mode stats activé (nouvelle saisie).
  static Future<void> clearLiveStatsOnly() async {
    await _db.collection('live').doc('current').update({
      'stats': <String, dynamic>{},
      'statsPreview': FieldValue.delete(),
      'statsPreviewMatchId': FieldValue.delete(),
      'statsPreviewAt': FieldValue.delete(),
    });
  }

  static Future<void> clearLiveFacts({bool clearStats = false}) async {
    final updates = <String, dynamic>{
      'events': <Map<String, dynamic>>[],
      'yellowHome': 0,
      'yellowAway': 0,
      'redHome': 0,
      'redAway': 0,
      'manOfTheMatchName': '',
      'manOfTheMatchPartnerName': '',
      'manOfTheMatchPartnerLogo': '',
      'motmVoteEnabled': false,
      'motmVoteStatus': '',
      'motmVoteMode': '',
      'motmVoteSessionId': '',
      'motmVoteTitle': '',
      'motmVoteTeamName': '',
      'motmVoteTeams': <Map<String, dynamic>>[],
      'motmVoteSponsorName': '',
      'motmVoteSponsorLogo': '',
      'motmVoteBackgroundImage': '',
      'motmVoteRevealWinner': true,
      'motmVoteCandidates': <Map<String, dynamic>>[],
      'motmVoteCounts': <String, int>{},
      'motmVoteTotal': 0,
      'motmVoteWinnerId': '',
      'motmVoteWinnerName': '',
      'motmVoteWinnerVotes': 0,
      'motmVoteWinnerTeamId': '',
      'motmVoteWinnerTeamName': '',
      'motmVoteEndedReason': '',
      'matchRatingPending': false,
      'matchRatingStatus': '',
      'matchRatingSessionId': '',
      'matchRatingTitle': '',
      'matchRatingBackgroundImage': '',
      'matchRatingCounts': <String, int>{},
      'matchRatingTotal': 0,
      'matchRatingSum': 0,
      'matchRatingAverage': 0.0,
      'lineupHome': <String, dynamic>{
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
      'lineupAway': <String, dynamic>{
        'coach': '',
        'starters': <String>[],
        'substitutes': <String>[],
      },
      'showLineupOnCard': false,
      'showMotm': false,
    };
    if (clearStats) {
      updates['stats'] = <String, dynamic>{};
    }
    await _db.collection('live').doc('current').update(updates);
    _mirrorLiveFactsDebounced();
  }
}
