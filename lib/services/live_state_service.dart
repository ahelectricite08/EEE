import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_stats_schema.dart';

/// État agrégé des flux live DVCR (match + émission).
class LiveHubState {
  final bool isMatchLive;
  final bool isEmissionLive;
  final String? matchStreamUrl;
  /// `false` = match live sans flux YouTube (score / stats uniquement).
  final bool matchStreamBroadcast;
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
  /// Toggle admin « Stats en direct » uniquement (sans inférer depuis des stats déjà saisies).
  final bool liveStatsToggleOn;
  final int yellowHome;
  final int yellowAway;
  final int redHome;
  final int redAway;
  final int minute;
  final bool isHalftime;
  final bool isExtraHalftime;
  final bool isFulltime;
  final bool isExtraFulltime;
  final bool isExtraTimePlaying;
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
    this.matchStreamBroadcast = true,
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
    this.liveStatsToggleOn = false,
    this.yellowHome = 0,
    this.yellowAway = 0,
    this.redHome = 0,
    this.redAway = 0,
    this.minute = 0,
    this.isHalftime = false,
    this.isExtraHalftime = false,
    this.isFulltime = false,
    this.isExtraFulltime = false,
    this.isExtraTimePlaying = false,
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

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final t = v?.toString().trim().toLowerCase() ?? '';
    return t == 'true' || t == '1' || t == 'yes';
  }

  static bool _statsMapHasData(dynamic raw) {
    if (raw is! Map) return false;
    return !MatchStatsSchema.isEmpty(Map<String, dynamic>.from(raw));
  }

  static bool _liveDocHasStats(Map<String, dynamic>? cur, String matchId) {
    if (cur == null) return false;
    if (_statsMapHasData(cur['stats'])) return true;
    final previewId = (cur['statsPreviewMatchId'] ?? '').toString().trim();
    if (previewId.isNotEmpty &&
        matchId.isNotEmpty &&
        previewId != matchId) {
      return false;
    }
    return _statsMapHasData(cur['statsPreview']);
  }

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
      matchStreamBroadcast: cur?['streamBroadcast'] is bool
          ? cur!['streamBroadcast'] as bool
          : ((cur?['url'] as String?)?.trim().isNotEmpty ?? true),
      emissionStreamUrl: em?['url'] as String?,
      emissionTitle: (em?['title'] as String?) ?? 'ÉMISSION DVCR',
      emissionViewers: (em?['viewers'] as int?) ?? 0,
      scoreHome: (cur?['scoreHome'] as int?) ?? 0,
      scoreAway: (cur?['scoreAway'] as int?) ?? 0,
      matchTeam1: (cur?['team1'] as String?) ?? '',
      matchTeam2: (cur?['team2'] as String?) ?? '',
      matchLogo1: (cur?['logo1'] as String?) ?? '',
      matchLogo2: (cur?['logo2'] as String?) ?? '',
      statsEnabled:
          (cur?['statsEnabled'] as bool?) == true ||
          _liveDocHasStats(cur, matchIdStr),
      liveStatsToggleOn: (cur?['statsEnabled'] as bool?) == true,
      yellowHome: (cur?['yellowHome'] as int?) ?? 0,
      yellowAway: (cur?['yellowAway'] as int?) ?? 0,
      redHome: (cur?['redHome'] as int?) ?? 0,
      redAway: (cur?['redAway'] as int?) ?? 0,
      minute: _readInt(cur?['minute']),
      isHalftime: cur?['lastEvent'] == 'halftime',
      isExtraHalftime: cur?['lastEvent'] == 'extra_halftime',
      isFulltime: cur?['lastEvent'] == 'fulltime',
      isExtraFulltime: cur?['lastEvent'] == 'extra_fulltime',
      isExtraTimePlaying: cur?['lastEvent'] == 'extra_time',
      chronoBaseSeconds: _readInt(cur?['chronoBaseSeconds']),
      chronoStartedAtMs: _readInt(cur?['chronoStartedAtMs']),
      chronoRunning: _readBool(cur?['chronoRunning']),
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
