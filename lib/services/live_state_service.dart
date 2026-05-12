import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// État agrégé des flux live DVCR (match + émission).
class LiveHubState {
  final bool isMatchLive;
  final bool isEmissionLive;
  final String? matchStreamUrl;
  final String? emissionStreamUrl;
  final String emissionTitle;
  final int emissionViewers;
  final int scoreHome;
  final int scoreAway;
  final String matchTeam1;
  final String matchTeam2;
  final String matchLogo1;
  final String matchLogo2;
  final bool statsEnabled;
  final int yellowHome;
  final int yellowAway;
  final int redHome;
  final int redAway;
  final int minute;
  final bool isHalftime;
  final bool isFulltime;
  final int chronoBaseSeconds;
  final int chronoStartedAtMs;
  final bool chronoRunning;
  final List<Map<String, dynamic>> timelineEvents;
  /// `live/current.matchId` (chaîne vide si absent).
  final String liveMatchId;

  const LiveHubState({
    required this.isMatchLive,
    required this.isEmissionLive,
    this.matchStreamUrl,
    this.emissionStreamUrl,
    this.emissionTitle = 'ÉMISSION DVCR',
    this.emissionViewers = 0,
    this.scoreHome = 0,
    this.scoreAway = 0,
    this.matchTeam1 = '',
    this.matchTeam2 = '',
    this.matchLogo1 = '',
    this.matchLogo2 = '',
    this.statsEnabled = false,
    this.yellowHome = 0,
    this.yellowAway = 0,
    this.redHome = 0,
    this.redAway = 0,
    this.minute = 0,
    this.isHalftime = false,
    this.isFulltime = false,
    this.chronoBaseSeconds = 0,
    this.chronoStartedAtMs = 0,
    this.chronoRunning = false,
    this.timelineEvents = const [],
    this.liveMatchId = '',
  });

  static const LiveHubState empty = LiveHubState(
    isMatchLive: false,
    isEmissionLive: false,
    liveMatchId: '',
  );

  bool get anyLive => isMatchLive || isEmissionLive;

  static LiveHubState fromSnapshots({
    required DocumentSnapshot<Map<String, dynamic>>? current,
    required DocumentSnapshot<Map<String, dynamic>>? emission,
  }) {
    final cur = current?.data();
    final em = emission?.data();

    final matchIdStr = (cur?['matchId']?.toString() ?? '').trim();
    final isSyntheticLiveSession =
        matchIdStr.startsWith('live_') && RegExp(r'^live_\d+$').hasMatch(matchIdStr);
    // Doc `live/current` sans matchId = ancien bug ; id `live_…` = session sans fiche calendrier.
    final matchLive = current?.exists == true &&
        matchIdStr.isNotEmpty &&
        !isSyntheticLiveSession;
    final emLive = emission?.exists == true;

    final rawEvents = cur?['events'];
    final events = rawEvents is List
        ? rawEvents
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];

    return LiveHubState(
      isMatchLive: matchLive,
      isEmissionLive: emLive,
      matchStreamUrl: cur?['url'] as String?,
      emissionStreamUrl: em?['url'] as String?,
      emissionTitle: (em?['title'] as String?) ?? 'ÉMISSION DVCR',
      emissionViewers: (em?['viewers'] as int?) ?? 0,
      scoreHome: (cur?['scoreHome'] as int?) ?? 0,
      scoreAway: (cur?['scoreAway'] as int?) ?? 0,
      matchTeam1: (cur?['team1'] as String?) ?? '',
      matchTeam2: (cur?['team2'] as String?) ?? '',
      matchLogo1: (cur?['logo1'] as String?) ?? '',
      matchLogo2: (cur?['logo2'] as String?) ?? '',
      statsEnabled: (cur?['statsEnabled'] as bool?) ?? false,
      yellowHome: (cur?['yellowHome'] as int?) ?? 0,
      yellowAway: (cur?['yellowAway'] as int?) ?? 0,
      redHome: (cur?['redHome'] as int?) ?? 0,
      redAway: (cur?['redAway'] as int?) ?? 0,
      minute: (cur?['minute'] as int?) ?? 0,
      isHalftime: cur?['lastEvent'] == 'halftime',
      isFulltime: cur?['lastEvent'] == 'fulltime',
      chronoBaseSeconds: (cur?['chronoBaseSeconds'] as int?) ?? 0,
      chronoStartedAtMs: (cur?['chronoStartedAtMs'] as int?) ?? 0,
      chronoRunning: (cur?['chronoRunning'] as bool?) ?? false,
      timelineEvents: events,
      liveMatchId: (cur?['matchId']?.toString() ?? '').trim(),
    );
  }
}

/// Un seul flux Firestore combiné pour la home, le hero, etc.
class LiveStateService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<LiveHubState> watch() {
    DocumentSnapshot<Map<String, dynamic>>? lastMatch;
    DocumentSnapshot<Map<String, dynamic>>? lastEmission;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subMatch;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subEmission;

    late final StreamController<LiveHubState> hubCtl;
    hubCtl = StreamController<LiveHubState>(
      onListen: () {
        void push() {
          if (hubCtl.isClosed) return;
          hubCtl.add(
            LiveHubState.fromSnapshots(
              current: lastMatch,
              emission: lastEmission,
            ),
          );
        }

        subMatch = _db
            .collection('live')
            .doc('current')
            .snapshots()
            .listen((snap) {
              lastMatch = snap;
              push();
            });
        subEmission = _db
            .collection('live')
            .doc('emission')
            .snapshots()
            .listen((snap) {
              lastEmission = snap;
              push();
            });
      },
      onCancel: () async {
        await subMatch?.cancel();
        await subEmission?.cancel();
        subMatch = null;
        subEmission = null;
      },
    );

    return hubCtl.stream;
  }
}
