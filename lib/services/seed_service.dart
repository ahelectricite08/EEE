import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestion du document live/current dans Firestore
class SeedService {
  static final _db = FirebaseFirestore.instance;

  /// Démarre un live — crée live/current
  static Future<void> startLive({
    required String url,
    String team1 = '',
    String team2 = '',
    String? matchId,
    String? logo1,
    String? logo2,
    int viewers = 0,
    bool tvBroadcast = false,
  }) async {
    // Ne pas modifier `matches/{matchId}` ici : stats / score / events restent jusqu’à
    // suppression explicite dans l’admin (onglet Stats) ou fin de live (`clearLive`).

    var resolvedMatchId = (matchId ?? '').trim();
    if (resolvedMatchId.isEmpty) {
      resolvedMatchId = 'live_${DateTime.now().millisecondsSinceEpoch}';
    }

    await _db.collection('live').doc('current').set({
      'url': url,
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

  /// Fin de match : bloque le chrono + notif Cloud Function.
  static Future<void> notifyFulltime(int minute) async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'fulltime',
      ..._chronoPausedAtMinute(minute),
    });
  }

  /// Reprise 2e mi-temps après la pause (46′ par défaut).
  static Future<void> resumeSecondHalf({int startMinute = 46}) async {
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

  /// Fin des prolongations (+ notif).
  static Future<void> notifyExtraFulltime(int minute) async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'extra_fulltime',
      ..._chronoPausedAtMinute(minute),
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

  /// Termine le live — sauvegarde stats+events dans matches/{matchId} puis supprime live/current
  static Future<void> clearLive() async {
    final snap = await _db.collection('live').doc('current').get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final matchId = (data['matchId'] as String? ?? '').trim();
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

      if (matchId.isNotEmpty) {
        final saveData = <String, dynamic>{
          'scoreHome': scoreHome,
          'scoreAway': scoreAway,
          'score1': scoreHome,
          'score2': scoreAway,
          'yellowHome': yellowHome,
          'yellowAway': yellowAway,
          'redHome': redHome,
          'redAway': redAway,
          'showStats': true,
          'status': 'finished', // déclenche la Cloud Function de calcul des pronos
        };
        if (stats != null && stats.isNotEmpty) {
          saveData['stats'] = stats;
          saveData['showStats'] = true;
        }
        if (events is List && events.isNotEmpty) saveData['events'] = events;
        if (manOfTheMatch.toString().isNotEmpty) {
          saveData['manOfTheMatchName'] = manOfTheMatch;
          saveData['manOfTheMatchPartnerName'] = manPartnerName;
          saveData['manOfTheMatchPartnerLogo'] = manPartnerLogo;
        }
        await _db.collection('matches').doc(matchId).set(
          saveData,
          SetOptions(merge: true),
        );
      }
    }
    await _db.collection('live').doc('current').delete();
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
  }) async {
    final trimmedPlayer = player.trim();
    if (type == 'goal' && !isGoalScorerValid(trimmedPlayer)) {
      throw StateError('goal_scorer_required');
    }
    final resolvedPlayer = trimmedPlayer.isEmpty ? 'Inconnu' : trimmedPlayer;

    final docRef = _db.collection('live').doc('current');
    final event = _eventPayload(
      type: type,
      team: team,
      player: resolvedPlayer,
      minute: minute,
    );
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final upperTeam = team.trim().toUpperCase();
      final isHome = team1.isNotEmpty ? upperTeam == team1 : upperTeam != team2;

      final updates = <String, dynamic>{
        'events': FieldValue.arrayUnion([event]),
      };
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
      } else if (type == 'red') {
        final field = isHome ? 'redHome' : 'redAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
      }
      tx.update(docRef, updates);
    });
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
  }

  static Future<void> removeMatchEvent(Map<String, dynamic> event) async {
    final docRef = _db.collection('live').doc('current');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final type = (event['type'] as String? ?? '').trim();
      final team = (event['team'] as String? ?? '').trim().toUpperCase();
      final isHome = team1.isNotEmpty ? team == team1 : team != team2;

      final updates = <String, dynamic>{
        'events': FieldValue.arrayRemove([event]),
      };
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

  /// Stats live : uniquement [live/current] ; copie vers [matches] à [clearLive].
  static Future<void> setLiveStats(Map<String, dynamic> stats) async {
    await _db.collection('live').doc('current').update({
      'stats': stats,
      'statsEnabled': true,
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
    };
    if (clearStats) {
      updates['stats'] = <String, dynamic>{};
    }
    await _db.collection('live').doc('current').update(updates);
  }
}
