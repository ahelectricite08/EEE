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
  }) async {
    // Ne pas modifier `matches/{matchId}` ici : stats / score / events restent jusqu’à
    // suppression explicite dans l’admin (onglet Stats) ou fin de live (`clearLive`).

    await _db.collection('live').doc('current').set({
      'url': url,
      'logo1': logo1 ?? '',
      'logo2': logo2 ?? '',
      'live_viewers': viewers,
      'team1': team1,
      'team2': team2,
      'matchId': matchId ?? '',
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

  /// Renvoie le matchId du live en cours ('' si absent)
  static Future<String> _liveMatchId() async {
    final snap = await _db.collection('live').doc('current').get();
    return ((snap.data() ?? {})['matchId'] as String? ?? '').trim();
  }

  /// Met à jour le score live + synchro match doc en temps réel
  static Future<void> updateLiveScore(int home, int away) async {
    final matchId = await _liveMatchId();
    final futures = <Future>[
      _db.collection('live').doc('current').update({'scoreHome': home, 'scoreAway': away}),
    ];
    if (matchId.isNotEmpty) {
      futures.add(_db.collection('matches').doc(matchId).set({
        'scoreHome': home,
        'scoreAway': away,
        'score1': home,
        'score2': away,
      }, SetOptions(merge: true)));
    }
    await Future.wait(futures);
  }

  /// Déclenche la notification mi-temps
  static Future<void> notifyHalftime() async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'halftime',
    });
  }

  /// Déclenche la fin de match
  static Future<void> notifyFulltime(int minute) async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'fulltime',
      'minute': minute,
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
        if (stats != null && stats.isNotEmpty) saveData['stats'] = stats;
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

  /// Met à jour les cartons + synchro match doc en temps réel
  static Future<void> updateCards({
    required int yellowHome,
    required int yellowAway,
    required int redHome,
    required int redAway,
  }) async {
    final matchId = await _liveMatchId();
    final payload = {
      'yellowHome': yellowHome,
      'yellowAway': yellowAway,
      'redHome': redHome,
      'redAway': redAway,
    };
    final futures = <Future>[
      _db.collection('live').doc('current').update(payload),
    ];
    if (matchId.isNotEmpty) {
      futures.add(_db.collection('matches').doc(matchId).set(payload, SetOptions(merge: true)));
    }
    await Future.wait(futures);
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

  static Future<void> addMatchEvent({
    required String type,
    required String team,
    required String player,
    required int minute,
  }) async {
    final docRef = _db.collection('live').doc('current');
    String matchId = '';
    final event = {
      'type': type,
      'team': team.trim(),
      'player': player,
      'minute': minute,
    };
    final Map<String, dynamic> matchExtra = {};

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      matchId = (data['matchId'] as String? ?? '').trim();
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final upperTeam = team.trim().toUpperCase();
      final isHome = team1.isNotEmpty ? upperTeam == team1 : upperTeam != team2;

      final updates = <String, dynamic>{
        'events': FieldValue.arrayUnion([event]),
      };
      if (type == 'yellow') {
        final field = isHome ? 'yellowHome' : 'yellowAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
        matchExtra[field] = updates[field];
      } else if (type == 'red') {
        final field = isHome ? 'redHome' : 'redAway';
        updates[field] = ((data[field] as int?) ?? 0) + 1;
        matchExtra[field] = updates[field];
      }
      tx.update(docRef, updates);
    });

    if (matchId.isNotEmpty) {
      await _db.collection('matches').doc(matchId).set({
        'events': FieldValue.arrayUnion([event]),
        ...matchExtra,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> removeMatchEvent(Map<String, dynamic> event) async {
    final docRef = _db.collection('live').doc('current');
    String matchId = '';
    final Map<String, dynamic> matchExtra = {};

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      matchId = (data['matchId'] as String? ?? '').trim();
      final team1 = (data['team1'] as String? ?? '').trim().toUpperCase();
      final team2 = (data['team2'] as String? ?? '').trim().toUpperCase();
      final type = (event['type'] as String? ?? '').trim();
      final team = (event['team'] as String? ?? '').trim().toUpperCase();
      final isHome = team1.isNotEmpty ? team == team1 : team != team2;

      final updates = <String, dynamic>{
        'events': FieldValue.arrayRemove([event]),
      };
      if (type == 'yellow') {
        final field = isHome ? 'yellowHome' : 'yellowAway';
        updates[field] = (((data[field] as int?) ?? 0) - 1).clamp(0, 999);
        matchExtra[field] = updates[field];
      } else if (type == 'red') {
        final field = isHome ? 'redHome' : 'redAway';
        updates[field] = (((data[field] as int?) ?? 0) - 1).clamp(0, 999);
        matchExtra[field] = updates[field];
      }
      tx.update(docRef, updates);
    });

    if (matchId.isNotEmpty) {
      await _db.collection('matches').doc(matchId).set({
        'events': FieldValue.arrayRemove([event]),
        ...matchExtra,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> setManOfTheMatch({
    required String player,
    String partnerName = '',
    String partnerLogo = '',
  }) async {
    final docRef = _db.collection('live').doc('current');
    String matchId = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      matchId = ((snap.data() ?? {})['matchId'] as String? ?? '').trim();
      tx.update(docRef, {
        'manOfTheMatchName': player,
        'manOfTheMatchPartnerName': partnerName,
        'manOfTheMatchPartnerLogo': partnerLogo,
      });
    });
    if (matchId.isNotEmpty) {
      await _db.collection('matches').doc(matchId).set({
        'manOfTheMatchName': player,
        'manOfTheMatchPartnerName': partnerName,
        'manOfTheMatchPartnerLogo': partnerLogo,
      }, SetOptions(merge: true));
    }
  }

  /// Met à jour les stats live + synchro match doc en temps réel
  static Future<void> setLiveStats(Map<String, dynamic> stats) async {
    final matchId = await _liveMatchId();
    final futures = <Future>[
      _db.collection('live').doc('current').update({'stats': stats}),
    ];
    if (matchId.isNotEmpty) {
      futures.add(_db.collection('matches').doc(matchId).set(
        {'stats': stats, 'showStats': true},
        SetOptions(merge: true),
      ));
    }
    await Future.wait(futures);
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
