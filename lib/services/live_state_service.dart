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
  /// `live/current.showLineupOnCard` — toggle admin « Afficher compo sur la carte ».
  final bool liveLineupOnCard;
  /// Radio commentaire MediaMTX / HLS active (`live/current.radioLive`).
  final bool radioLive;
  final String radioRoomName;
  /// URL publique d’écoute (HLS ou Icecast).
  final String radioHlsUrl;
  /// URL WHIP publish (vide en mode URL externe).
  final String radioWhipUrl;

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
    this.liveLineupOnCard = false,
    this.radioLive = false,
    this.radioRoomName = '',
    this.radioHlsUrl = '',
    this.radioWhipUrl = '',
  });

  static const LiveHubState empty = LiveHubState(
    isMatchLive: false,
    isEmissionLive: false,
    liveMatchId: '',
  );

  bool get anyLive => isMatchLive || isEmissionLive;

  String get _sig => [
        isMatchLive,
        isEmissionLive,
        matchStreamUrl,
        matchStreamBroadcast,
        emissionStreamUrl,
        emissionTitle,
        emissionViewers,
        scoreHome,
        scoreAway,
        matchTeam1,
        matchTeam2,
        matchLogo1,
        matchLogo2,
        statsEnabled,
        liveStatsToggleOn,
        yellowHome,
        yellowAway,
        redHome,
        redAway,
        minute,
        isHalftime,
        isExtraHalftime,
        isFulltime,
        isExtraFulltime,
        isExtraTimePlaying,
        chronoBaseSeconds,
        chronoStartedAtMs,
        chronoRunning,
        liveMatchId,
        liveLineupOnCard,
        radioLive,
        radioRoomName,
        radioHlsUrl,
        radioWhipUrl,
        timelineEvents.length,
        timelineEvents
            .map((e) => '${e['type']}|${e['player']}|${e['minute']}|${e['team']}')
            .join(';'),
      ].join('\u0001');

  @override
  bool operator ==(Object other) =>
      other is LiveHubState && other._sig == _sig;

  @override
  int get hashCode => _sig.hashCode;

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
      liveLineupOnCard: cur?['showLineupOnCard'] == true,
      radioLive: cur?['radioLive'] == true,
      radioRoomName: (cur?['radioRoomName']?.toString() ?? '').trim(),
      radioHlsUrl: (cur?['radioHlsUrl']?.toString() ?? '').trim(),
      radioWhipUrl: (cur?['radioWhipUrl']?.toString() ?? '').trim(),
    );
  }
}

/// Hub live unique : **une** paire de lecteurs Firestore (`live/current` +
/// `live/emission`), N listeners Dart (accueil, TV, overlay score, SFX…).
///
/// Les onglets [IndexedStack] restent montés : on ne coupe **pas** Firestore
/// au changement d’onglet (P1 = lazy tabs). Démarré au premier [watch],
/// conservé pour la durée du process.
class LiveStateService {
  LiveStateService._();
  static final LiveStateService instance = LiveStateService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  final StreamController<LiveHubState> _hubCtrl =
      StreamController<LiveHubState>.broadcast();
  final StreamController<DocumentSnapshot<Map<String, dynamic>>> _currentCtrl =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  final StreamController<DocumentSnapshot<Map<String, dynamic>>> _emissionCtrl =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();

  /// Conservé pour la durée du process (IndexedStack / SFX).
  static final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _firestoreRetain = [];

  LiveHubState _latest = LiveHubState.empty;
  DocumentSnapshot<Map<String, dynamic>>? _currentSnap;
  DocumentSnapshot<Map<String, dynamic>>? _emissionSnap;
  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _emissionData;
  bool _started = false;
  bool _currentReady = false;
  bool _emissionReady = false;

  static LiveHubState get latest => instance._latest;
  static DocumentSnapshot<Map<String, dynamic>>? get latestCurrent =>
      instance._currentSnap;
  static DocumentSnapshot<Map<String, dynamic>>? get latestEmission =>
      instance._emissionSnap;

  static Stream<LiveHubState> watch() {
    instance._ensureStarted();
    return Stream<LiveHubState>.multi((listener) {
      if (instance._currentSnap != null || instance._emissionSnap != null) {
        listener.add(instance._latest);
      }
      final sub = instance._hubCtrl.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () => sub.cancel();
    });
  }

  /// Même doc `live/current` que [watch] — pas de lecteur Firestore en plus.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentSnapshots() {
    instance._ensureStarted();
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.multi((listener) {
      final snap = instance._currentSnap;
      if (snap != null) listener.add(snap);
      final sub = instance._currentCtrl.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () => sub.cancel();
    });
  }

  /// Même doc `live/emission` que [watch] — pas de lecteur Firestore en plus.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchEmissionSnapshots() {
    instance._ensureStarted();
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.multi((listener) {
      final snap = instance._emissionSnap;
      if (snap != null) listener.add(snap);
      final sub = instance._emissionCtrl.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () => sub.cancel();
    });
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;

    void pushHub() {
      final next = LiveHubState.fromSnapshots(
        current: _currentSnap,
        emission: _emissionSnap,
      );
      if (next == _latest) return;
      _latest = next;
      if (!_hubCtrl.isClosed) _hubCtrl.add(next);
    }

    _firestoreRetain.add(
      _db.collection('live').doc('current').snapshots().listen(
        (snap) {
          _currentSnap = snap;
          final data = snap.data();
          final changed = !_currentReady || !_mapEq(_currentData, data);
          _currentReady = true;
          _currentData = data;
          if (changed && !_currentCtrl.isClosed) _currentCtrl.add(snap);
          pushHub();
        },
        onError: (Object e, StackTrace st) {
          if (!_hubCtrl.isClosed) _hubCtrl.addError(e, st);
        },
      ),
    );

    _firestoreRetain.add(
      _db.collection('live').doc('emission').snapshots().listen(
        (snap) {
          _emissionSnap = snap;
          final data = snap.data();
          final changed = !_emissionReady || !_mapEq(_emissionData, data);
          _emissionReady = true;
          _emissionData = data;
          if (changed && !_emissionCtrl.isClosed) _emissionCtrl.add(snap);
          pushHub();
        },
        onError: (Object e, StackTrace st) {
          if (!_hubCtrl.isClosed) _hubCtrl.addError(e, st);
        },
      ),
    );
    assert(_firestoreRetain.length == 2, 'LiveHub: 2 lecteurs Firestore');
  }

  static bool _mapEq(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_valueEq(a[key], b[key])) return false;
    }
    return true;
  }

  static bool _valueEq(Object? a, Object? b) {
    if (identical(a, b) || a == b) return true;
    if (a is Map && b is Map) {
      return _mapEq(
        Map<String, dynamic>.from(a),
        Map<String, dynamic>.from(b),
      );
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valueEq(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }
}
