import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:live_activities/models/alert_config.dart';
import 'package:live_activities/models/live_activity_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/club_branding.dart';
import 'live_banner_format.dart';
import 'live_score_sticky_service.dart';
import 'live_state_service.dart';
import 'live_event_sound_service.dart';
import 'live_team_logo_resolver.dart';
import 'live_activity_push_sync.dart';

/// Suivi score sur écran verrouillé : Live Activity (iOS) + RemoteViews (Android).
/// Repli : notification persistante [LiveScoreStickyService].
class LiveMatchActivityService {
  LiveMatchActivityService._();

  static const appGroupId = 'group.fr.dvcr.app.liveactivities';
  static const activityId = 'dvcr_live_match';
  static const _prefEnabled = 'notif_live_sticky_score';
  static const _prefForceStart = 'live_activity_force_start';

  static final LiveActivities _plugin = LiveActivities();
  static StreamSubscription<LiveHubState>? _hubSub;
  static bool _enabled = true;
  static bool _pluginReady = false;
  static bool _nativeActive = false;
  static bool _forceStartNext = false;
  static String? _runningActivityId;
  static LiveHubState? _lastHub;
  static LiveHubState? _lastApplied;
  static String _lastEffLogo1 = '';
  static String _lastEffLogo2 = '';
  static String _cachedIosLogo1Path = '';
  static String _cachedIosLogo2Path = '';
  static String? _lastPlayedSoundKey;
  static Timer? _chronoRefreshTimer;
  static int _contentTick = 0;
  static LiveHubState? _pendingHubApply;
  static bool _pendingForceChronoTick = false;
  static bool _hubApplyInFlight = false;
  static _LiveActivityLifecycleBridge? _lifecycleBridge;
  static StreamSubscription<ActivityUpdate>? _activityStatusSub;
  static bool _resumeSyncInFlight = false;
  static Timer? _foregroundWatchdog;
  static DateTime? _lastSuccessfulNativeAt;

  static Future<void> start() async {
    if (kIsWeb) return;
    await _refreshEnabled();
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        await _plugin.init(
          appGroupId: appGroupId,
          urlScheme: 'dvcr',
        );
        _pluginReady = true;
      } catch (e) {
        debugPrint('DVCR LiveActivity init: $e');
        _pluginReady = false;
      }
    }
    _forceStartNext =
        (await SharedPreferences.getInstance()).getBool(_prefForceStart) ??
            false;
    await _hubSub?.cancel();
    _hubSub = LiveStateService.watch().listen(_onHub);
    _ensureLifecycleHooks();
    unawaited(syncNow(hardRefresh: true));
  }

  /// Resync complète — au retour au 1er plan ou si l’affichage natif a décroché.
  static Future<void> syncNow({bool hardRefresh = false}) async {
    if (kIsWeb || !_enabled || _resumeSyncInFlight) return;
    _resumeSyncInFlight = true;
    try {
      await _refreshEnabled();
      if (!_enabled) return;

      if (hardRefresh) {
        _chronoRefreshTimer?.cancel();
        _chronoRefreshTimer = null;
        _lastApplied = null;
      }

      await _reconcileRunningActivity();

      var hub = await _fetchCurrentHub();
      hub ??= _lastHub;
      if (hub == null || !hub.isMatchLive) return;

      _lastHub = hub;
      if (hardRefresh || !_nativeActive || _runningActivityId == null) {
        _lastApplied = null;
      }
      await _onHub(hub, forceChronoTick: true);
    } finally {
      _resumeSyncInFlight = false;
    }
  }

  /// Alias explicite pour le cycle de vie app.
  static Future<void> onAppResumed() => syncNow(hardRefresh: true);

  static void _ensureLifecycleHooks() {
    _lifecycleBridge ??= _LiveActivityLifecycleBridge();
    final binding = WidgetsBinding.instance;
    binding.removeObserver(_lifecycleBridge!);
    binding.addObserver(_lifecycleBridge!);

    _activityStatusSub ??= _plugin.activityUpdateStream.listen(
      _onNativeActivityStatus,
      onError: (Object e) => debugPrint('DVCR LiveActivity status: $e'),
    );
  }

  static void _onNativeActivityStatus(ActivityUpdate update) {
    update.mapOrNull(
      ended: (_) => _markNativeNeedsResync(),
      stale: (_) => _markNativeNeedsResync(),
    );
  }

  static void _markNativeNeedsResync() {
    _nativeActive = false;
    _runningActivityId = null;
    _lastSuccessfulNativeAt = null;
    final hub = _lastHub;
    if (hub != null && hub.isMatchLive && _enabled) {
      unawaited(syncNow(hardRefresh: true));
    }
  }

  static Future<void> _reconcileRunningActivity() async {
    if (!_pluginReady) return;
    try {
      final ids = await _plugin.getAllActivitiesIds();
      if (ids.isEmpty) {
        _runningActivityId = null;
        _nativeActive = false;
        return;
      }
      if (_runningActivityId == null || !ids.contains(_runningActivityId)) {
        _runningActivityId = ids.first;
        _nativeActive = true;
      }
    } catch (e) {
      debugPrint('DVCR LiveActivity reconcile: $e');
    }
  }

  static Future<LiveHubState?> _fetchCurrentHub() async {
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get(const GetOptions(source: Source.server));
    } catch (e) {
      debugPrint('DVCR LiveActivity fetch server: $e');
      try {
        snap = await FirebaseFirestore.instance
            .collection('live')
            .doc('current')
            .get(const GetOptions(source: Source.cache));
      } catch (e2) {
        debugPrint('DVCR LiveActivity fetch cache: $e2');
        return null;
      }
    }
    return LiveHubState.fromSnapshots(current: snap, emission: null);
  }

  static Future<void> stop() async {
    _chronoRefreshTimer?.cancel();
    _chronoRefreshTimer = null;
    _foregroundWatchdog?.cancel();
    _foregroundWatchdog = null;
    await _hubSub?.cancel();
    _hubSub = null;
    await _activityStatusSub?.cancel();
    _activityStatusSub = null;
    if (_lifecycleBridge != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleBridge!);
      _lifecycleBridge = null;
    }
    await _endNative();
    await LiveScoreStickyService.clearFallback();
    _lastHub = null;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    if (!value) {
      await _endNative();
      await LiveScoreStickyService.clearFallback();
      _lastHub = null;
    } else if (_lastHub != null && _lastHub!.isMatchLive) {
      await _onHub(_lastHub!);
    }
  }

  /// Après notif « coup d’envoi » ou ouverture depuis le live.
  static Future<void> markStartAfterUserOpenedApp() async {
    _forceStartNext = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefForceStart, true);
    if (_lastHub != null && _lastHub!.isMatchLive) {
      await _onHub(_lastHub!);
    }
  }

  static Future<void> _refreshEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefEnabled) ?? prefs.getBool('notif_live') ?? true;
  }

  static Future<void> _onHub(
    LiveHubState hub, {
    bool forceChronoTick = false,
  }) async {
    final prev = _lastHub;
    _lastHub = hub;

    if (!_enabled || !hub.isMatchLive) {
      _pendingHubApply = null;
      _pendingForceChronoTick = false;
      _forceStartNext = false;
      unawaited(
        SharedPreferences.getInstance()
            .then((p) => p.setBool(_prefForceStart, false)),
      );
      await _endNative();
      await LiveScoreStickyService.clearFallback();
      _syncChronoRefreshTimer(hub);
      _syncForegroundWatchdog(hub);
      return;
    }

    _syncChronoRefreshTimer(hub);
    _syncForegroundWatchdog(hub);
    final chronoChanged = prev != null &&
        (prev.chronoRunning != hub.chronoRunning ||
            prev.chronoStartedAtMs != hub.chronoStartedAtMs ||
            prev.chronoBaseSeconds != hub.chronoBaseSeconds);
    _pendingHubApply = hub;
    _pendingForceChronoTick =
        _pendingForceChronoTick || forceChronoTick || chronoChanged;
    if (_hubApplyInFlight) return;
    await _drainHubApplyQueue();
  }

  /// Une seule mise à jour native à la fois ; les snapshots Firestore rapprochés
  /// sont fusionnés pour éviter qu’un vieux apply écrase un but/carton récent.
  static Future<void> _drainHubApplyQueue() async {
    _hubApplyInFlight = true;
    try {
      while (_pendingHubApply != null) {
        final hub = _pendingHubApply!;
        final forceChronoTick = _pendingForceChronoTick;
        _pendingHubApply = null;
        _pendingForceChronoTick = false;
        await _applyHub(hub, forceChronoTick: forceChronoTick);
      }
    } finally {
      _hubApplyInFlight = false;
      if (_pendingHubApply != null) {
        unawaited(_drainHubApplyQueue());
      }
    }
  }

  static Future<void> _applyHub(
    LiveHubState hub, {
    bool forceChronoTick = false,
  }) async {
    final quickLogo1 = hub.matchLogo1.trim().isNotEmpty
        ? hub.matchLogo1.trim()
        : _lastEffLogo1;
    final quickLogo2 = hub.matchLogo2.trim().isNotEmpty
        ? hub.matchLogo2.trim()
        : _lastEffLogo2;
    final scoreChanged = _lastApplied != null &&
        (_lastApplied!.scoreHome != hub.scoreHome ||
            _lastApplied!.scoreAway != hub.scoreAway);
    final eventLineChanged = _lastApplied != null &&
        LiveBannerFormat.lockScreenEventLine(_lastApplied!) !=
            LiveBannerFormat.lockScreenEventLine(hub);
    final changed = forceChronoTick ||
        scoreChanged ||
        eventLineChanged ||
        !_sameDisplay(_lastApplied, hub, quickLogo1, quickLogo2);
    if (!changed && !_forceStartNext && _nativeActive) {
      return;
    }

    await _reconcileRunningActivity();

    final resolved = await LiveTeamLogoResolver.resolve(
      team1: hub.matchTeam1,
      team2: hub.matchTeam2,
      logo1: hub.matchLogo1,
      logo2: hub.matchLogo2,
      matchId: hub.liveMatchId,
    );
    unawaited(_persistResolvedLogosIfNeeded(hub));

    final data = _activityData(hub, resolved.logo1, resolved.logo2);

    var nativeOk = false;
    if (_pluginReady) {
      final alertConfig = _dynamicIslandAlert(hub, before: _lastApplied);
      nativeOk = await _pushNativeData(
        data,
        hub: hub,
        before: _lastApplied,
        alertConfig: alertConfig,
      );
    }

    if (nativeOk) {
      _lastSuccessfulNativeAt = DateTime.now();
      _captureIosLogoPaths(data, resolved.logo1, resolved.logo2);
      unawaited(
        LiveActivityPushSync.persistNativeSnapshot(
          activityId: _runningActivityId,
          logo1Url: resolved.logo1,
          logo2Url: resolved.logo2,
          logo1Path: data['teamALogo'] is String ? data['teamALogo'] as String : '',
          logo2Path: data['teamBLogo'] is String ? data['teamBLogo'] as String : '',
        ),
      );
      _forceStartNext = false;
      unawaited(
        SharedPreferences.getInstance()
            .then((p) => p.setBool(_prefForceStart, false)),
      );
      await LiveScoreStickyService.clearFallback();
      final firstApply = _lastApplied == null;
      _lastApplied = hub;
      _lastEffLogo1 = resolved.logo1;
      _lastEffLogo2 = resolved.logo2;
      unawaited(_maybePlayEventSound(hub, isFirstBannerApply: firstApply));
      return;
    }

    if (changed || _forceStartNext) {
      final firstApply = _lastApplied == null;
      await LiveScoreStickyService.showFallback(hub);
      _lastApplied = hub;
      _lastEffLogo1 = resolved.logo1;
      _lastEffLogo2 = resolved.logo2;
      unawaited(_maybePlayEventSound(hub, isFirstBannerApply: firstApply));
    }
    _forceStartNext = false;
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setBool(_prefForceStart, false)),
    );
  }

  static Future<void> _endNative() async {
    _nativeActive = false;
    _runningActivityId = null;
    _lastApplied = null;
    _lastEffLogo1 = '';
    _lastEffLogo2 = '';
    _cachedIosLogo1Path = '';
    _cachedIosLogo2Path = '';
    _lastPlayedSoundKey = null;
    _lastSuccessfulNativeAt = null;
    _pendingHubApply = null;
    _pendingForceChronoTick = false;
    unawaited(LiveActivityPushSync.clearCachedActivity());
    if (!_pluginReady) return;
    try {
      await _plugin.endAllActivities();
    } catch (e) {
      debugPrint('DVCR LiveActivity end: $e');
    }
    if (Platform.isIOS) {
      try {
        await const MethodChannel('fr.dvcr.app/live_activity_native')
            .invokeMethod<void>('endLiveActivity');
      } catch (_) {}
    }
  }

  /// Coupe immédiatement la Live Activity (fin de direct admin ou FCM live_end).
  static Future<void> dismissNow() async {
    _lastHub = null;
    _chronoRefreshTimer?.cancel();
    _chronoRefreshTimer = null;
    _foregroundWatchdog?.cancel();
    _foregroundWatchdog = null;
    await _endNative();
    await LiveScoreStickyService.clearFallback();
  }

  static Future<void> _persistResolvedLogosIfNeeded(LiveHubState hub) async {
    if (!hub.isMatchLive) return;
    final mid = hub.liveMatchId.trim();
    if (mid.isEmpty || _isSyntheticLiveId(mid)) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('matches').doc(mid).get();
      if (!snap.exists) return;
      final d = snap.data() ?? {};
      final patch = <String, dynamic>{};
      if (hub.matchLogo1.trim().isEmpty) {
        final l1 = (d['logo1'] as String? ?? '').trim();
        if (l1.isNotEmpty) patch['logo1'] = l1;
      }
      if (hub.matchLogo2.trim().isEmpty) {
        final l2 = (d['logo2'] as String? ?? '').trim();
        if (l2.isNotEmpty) patch['logo2'] = l2;
      }
      if (patch.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .set(patch, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DVCR LiveActivity logo persist: $e');
    }
  }

  static bool _isSyntheticLiveId(String id) =>
      id.startsWith('live_') && RegExp(r'^live_\d+$').hasMatch(id);

  /// Push natif avec repli createOrUpdate si l’activité iOS/Android a décroché.
  static Future<bool> _pushNativeData(
    Map<String, dynamic> data, {
    LiveHubState? hub,
    LiveHubState? before,
    AlertConfig? alertConfig,
  }) async {
    try {
      if (_runningActivityId == null || _forceStartNext) {
        if (_forceStartNext) {
          await _plugin.endAllActivities();
          _runningActivityId = null;
        }
        final id = await _plugin.createActivity(activityId, data);
        if (id == null || id.isEmpty) return false;
        _runningActivityId = id;
      } else {
        await _plugin.updateActivity(
          _runningActivityId!,
          data,
          alertConfig: alertConfig,
        );
      }
      _nativeActive = true;
      return true;
    } catch (e) {
      debugPrint('DVCR LiveActivity update: $e');
      _nativeActive = false;
      try {
        await _plugin.createOrUpdateActivity(activityId, data);
        await _reconcileRunningActivity();
        if (_runningActivityId != null) {
          _nativeActive = true;
          return true;
        }
      } catch (e2) {
        debugPrint('DVCR LiveActivity createOrUpdate: $e2');
      }
      return false;
    }
  }

  static Map<String, dynamic> _activityData(
    LiveHubState hub,
    String logo1,
    String logo2,
  ) {
    final now = DateTime.now();
    final end = now.add(const Duration(hours: 3));
    final status = _statusLabel(hub);
    final lastGoal = LiveBannerFormat.lockScreenEventLine(hub);
    final imageOpts = LiveActivityImageFileOptions(resizeFactor: 0.55);

    final data = <String, dynamic>{
      'matchName': ClubBranding.liveActivityBrand,
      'teamAName': _shortTeam(hub.matchTeam1),
      'teamAState': status,
      'teamAScore': hub.scoreHome,
      'teamBName': _shortTeam(hub.matchTeam2),
      'teamBState': 'LIVE',
      'teamBScore': hub.scoreAway,
      'lastGoalLine': lastGoal,
      'lastEventLine': lastGoal,
      'matchMinute': status,
      'matchStartDate': now.millisecondsSinceEpoch,
      'matchEndDate': end.millisecondsSinceEpoch,
      'chronoRunning': hub.chronoRunning,
      'chronoBaseSeconds': hub.chronoBaseSeconds,
      'chronoStartedAtMs': hub.chronoStartedAtMs,
      'liveMinute': hub.minute,
      'isHalftime': hub.isHalftime,
      'isExtraHalftime': hub.isExtraHalftime,
      'isFulltime': hub.isFulltime,
      'isExtraFulltime': hub.isExtraFulltime,
      'isExtraTimePlaying': hub.isExtraTimePlaying,
      'lastEvent': _lastEventPhase(hub),
      'contentTick': ++_contentTick,
      'lastEventType': _lastEventType(hub),
      'liveEventSoundKey': _eventSoundKey(hub),
    };

    if (Platform.isIOS) {
      data['teamALogo'] = _iosLogoPayload(
        logo1,
        cachedUrl: _lastEffLogo1,
        cachedPath: _cachedIosLogo1Path,
        imageOpts: imageOpts,
      );
      data['teamBLogo'] = _iosLogoPayload(
        logo2,
        cachedUrl: _lastEffLogo2,
        cachedPath: _cachedIosLogo2Path,
        imageOpts: imageOpts,
      );
    } else if (Platform.isAndroid) {
      data['teamAImageUrl'] = logo1;
      data['teamBImageUrl'] = logo2;
    }

    return data;
  }

  /// Réutilise le fichier déjà copié dans l’App Group — évite de re-télécharger
  /// les logos à chaque but/carton (gros gain de latence perçue).
  static dynamic _iosLogoPayload(
    String url, {
    required String cachedUrl,
    required String cachedPath,
    required LiveActivityImageFileOptions imageOpts,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed == cachedUrl.trim() && cachedPath.isNotEmpty) {
      return cachedPath;
    }
    return LiveActivityFileFromUrl.image(trimmed, imageOptions: imageOpts);
  }

  static void _captureIosLogoPaths(
    Map<String, dynamic> data,
    String logo1,
    String logo2,
  ) {
    if (!Platform.isIOS) return;
    final p1 = data['teamALogo'];
    if (p1 is String && p1.isNotEmpty && logo1.trim().isNotEmpty) {
      _cachedIosLogo1Path = p1;
    }
    final p2 = data['teamBLogo'];
    if (p2 is String && p2.isNotEmpty && logo2.trim().isNotEmpty) {
      _cachedIosLogo2Path = p2;
    }
  }

  static void _syncChronoRefreshTimer(LiveHubState hub) {
    final needsTick = hub.isMatchLive &&
        hub.chronoRunning &&
        !hub.isHalftime &&
        !hub.isFulltime &&
        !hub.isExtraHalftime &&
        !hub.isExtraFulltime &&
        !hub.isExtraTimePlaying;
    if (!_enabled || !needsTick) {
      _chronoRefreshTimer?.cancel();
      _chronoRefreshTimer = null;
      return;
    }
    if (_chronoRefreshTimer != null) return;
    _chronoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final last = _lastHub;
      if (last != null && last.isMatchLive) {
        unawaited(_pushChronoRefresh(last));
      }
    });
  }

  /// Toutes les 30 s au 1er plan : resync si le natif n’a pas répondu récemment.
  static void _syncForegroundWatchdog(LiveHubState hub) {
    if (!_enabled || !hub.isMatchLive) {
      _foregroundWatchdog?.cancel();
      _foregroundWatchdog = null;
      return;
    }
    if (_foregroundWatchdog != null) return;
    _foregroundWatchdog = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_enabled) return;
      final last = _lastHub;
      if (last == null || !last.isMatchLive) return;

      final lastOk = _lastSuccessfulNativeAt;
      final stale = lastOk == null ||
          DateTime.now().difference(lastOk) > const Duration(seconds: 50);
      if (!_nativeActive || _runningActivityId == null || stale) {
        unawaited(syncNow(hardRefresh: true));
        return;
      }
      unawaited(_pushChronoRefresh(last));
    });
  }

  /// Rafraîchissement léger de la minute (sans logos / sans file d’attente lourde).
  static Future<void> _pushChronoRefresh(LiveHubState hub) async {
    if (!_enabled || !_nativeActive || _runningActivityId == null || !_pluginReady) {
      return;
    }
    if (!hub.isMatchLive) return;

    final minute = LiveBannerFormat.minuteLabel(hub);
    final prev = _lastApplied;
    if (prev != null &&
        LiveBannerFormat.minuteLabel(prev) == minute &&
        prev.chronoRunning == hub.chronoRunning &&
        prev.chronoBaseSeconds == hub.chronoBaseSeconds &&
        prev.chronoStartedAtMs == hub.chronoStartedAtMs &&
        prev.isHalftime == hub.isHalftime &&
        prev.isFulltime == hub.isFulltime &&
        prev.isExtraHalftime == hub.isExtraHalftime &&
        prev.isExtraFulltime == hub.isExtraFulltime &&
        prev.isExtraTimePlaying == hub.isExtraTimePlaying) {
      return;
    }

    final data = <String, dynamic>{
      'matchMinute': minute,
      'teamAState': minute,
      'contentTick': ++_contentTick,
      'chronoRunning': hub.chronoRunning,
      'chronoBaseSeconds': hub.chronoBaseSeconds,
      'chronoStartedAtMs': hub.chronoStartedAtMs,
      'liveMinute': hub.minute,
      'lastEvent': _lastEventPhase(hub),
      'isHalftime': hub.isHalftime,
      'isExtraHalftime': hub.isExtraHalftime,
      'isFulltime': hub.isFulltime,
      'isExtraFulltime': hub.isExtraFulltime,
      'isExtraTimePlaying': hub.isExtraTimePlaying,
    };

    if (Platform.isIOS) {
      if (_cachedIosLogo1Path.isNotEmpty) {
        data['teamALogo'] = _cachedIosLogo1Path;
      }
      if (_cachedIosLogo2Path.isNotEmpty) {
        data['teamBLogo'] = _cachedIosLogo2Path;
      }
    }

    try {
      final ok = await _pushNativeData(data);
      if (ok) {
        _lastSuccessfulNativeAt = DateTime.now();
        _lastApplied = hub;
      } else {
        unawaited(syncNow(hardRefresh: true));
      }
    } catch (e) {
      debugPrint('DVCR LiveActivity chrono refresh: $e');
      unawaited(syncNow(hardRefresh: true));
    }
  }

  static bool _sameDisplay(
    LiveHubState? a,
    LiveHubState b,
    String effLogo1,
    String effLogo2,
  ) {
    if (a == null) return false;
    return a.scoreHome == b.scoreHome &&
        a.scoreAway == b.scoreAway &&
        a.matchTeam1 == b.matchTeam1 &&
        a.matchTeam2 == b.matchTeam2 &&
        a.matchLogo1 == b.matchLogo1 &&
        a.matchLogo2 == b.matchLogo2 &&
        _lastEffLogo1 == effLogo1 &&
        _lastEffLogo2 == effLogo2 &&
        LiveBannerFormat.minuteLabel(a) == LiveBannerFormat.minuteLabel(b) &&
        a.isHalftime == b.isHalftime &&
        a.isFulltime == b.isFulltime &&
        a.isExtraHalftime == b.isExtraHalftime &&
        a.isExtraFulltime == b.isExtraFulltime &&
        a.isExtraTimePlaying == b.isExtraTimePlaying &&
        a.chronoRunning == b.chronoRunning &&
        a.chronoBaseSeconds == b.chronoBaseSeconds &&
        a.chronoStartedAtMs == b.chronoStartedAtMs &&
        a.timelineEvents.length == b.timelineEvents.length &&
        _eventSoundKey(a) == _eventSoundKey(b) &&
        LiveBannerFormat.lockScreenEventLine(a) ==
            LiveBannerFormat.lockScreenEventLine(b);
  }

  static String _shortTeam(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 16) return t;
    return '${t.substring(0, 14)}…';
  }

  static String _statusLabel(LiveHubState hub) =>
      LiveBannerFormat.minuteLabel(hub);

  static String _lastEventPhase(LiveHubState hub) {
    if (hub.isFulltime) return 'fulltime';
    if (hub.isExtraFulltime) return 'extra_fulltime';
    if (hub.isHalftime) return 'halftime';
    if (hub.isExtraHalftime) return 'extra_halftime';
    if (hub.isExtraTimePlaying) return 'extra_time';
    return '';
  }

  static String _lastEventType(LiveHubState hub) {
    if (hub.timelineEvents.isEmpty) return '';
    return (hub.timelineEvents.last['type'] ?? '').toString();
  }

  static String _eventSoundKey(LiveHubState hub) {
    if (hub.timelineEvents.isEmpty) return '';
    final e = hub.timelineEvents.last;
    final type = (e['type'] ?? '').toString();
    final player = (e['player'] ?? '').toString();
    final minute = (e['minute'] ?? hub.minute).toString();
    return '$type|${hub.timelineEvents.length}|$minute|$player';
  }

  static AlertConfig? _dynamicIslandAlert(
    LiveHubState hub, {
    LiveHubState? before,
  }) {
    if (!Platform.isIOS) return null;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.resumed) return null;

    if (before != null && _eventSoundKey(hub) == _eventSoundKey(before)) {
      return null;
    }

    final line = LiveBannerFormat.lockScreenEventLine(hub);
    if (line.isEmpty) return null;

    final type = _lastEventType(hub);
    final title = switch (type) {
      'goal' => '⚽ BUT !',
      'yellow' => '🟨 Carton jaune',
      'red' => '🟥 Carton rouge',
      'substitution' => '🔄 Changement',
      _ => null,
    };
    if (title == null) {
      if (hub.isHalftime) {
        return AlertConfig(title: '⏸ Mi-temps', body: LiveBannerFormat.minuteLabel(hub));
      }
      if (hub.isFulltime) {
        return AlertConfig(title: '🏁 Fin du match', body: LiveBannerFormat.minuteLabel(hub));
      }
      return null;
    }
    final score = '${hub.scoreHome} : ${hub.scoreAway}';
    return AlertConfig(title: '$title · $score', body: line);
  }

  static Future<void> _maybePlayEventSound(
    LiveHubState hub, {
    required bool isFirstBannerApply,
  }) async {
    final key = _eventSoundKey(hub);
    if (key.isEmpty) return;
    if (_lastPlayedSoundKey == key) return;
    _lastPlayedSoundKey = key;
    if (isFirstBannerApply) return;
    if (Platform.isAndroid) return;
    await LiveEventSoundService.maybePlayForEvent(_lastEventType(hub));
    // Renfort haptique si l’app tourne encore (Alert Live Activity = son côté iOS).
    if (Platform.isIOS) {
      await LiveEventSoundService.maybeHapticForEvent(_lastEventType(hub));
    }
  }
}

class _LiveActivityLifecycleBridge extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(LiveMatchActivityService.syncNow(hardRefresh: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      LiveMatchActivityService._foregroundWatchdog?.cancel();
      LiveMatchActivityService._foregroundWatchdog = null;
    }
  }
}
