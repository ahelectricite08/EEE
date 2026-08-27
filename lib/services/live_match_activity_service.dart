import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:live_activities/models/alert_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/club_branding.dart';
import 'live_banner_format.dart';
import 'live_score_sticky_service.dart';
import 'live_state_service.dart';
import 'live_event_sound_service.dart';
import 'live_team_logo_resolver.dart';
import 'live_activity_push_sync.dart';
import 'live_activity_token_service.dart';

/// Suivi score sur écran verrouillé : Live Activity (iOS) + RemoteViews (Android).
/// Repli : notification persistante [LiveScoreStickyService].
class LiveMatchActivityService {
  LiveMatchActivityService._();

  static const appGroupId = 'group.fr.dvcr.app.liveactivities';
  static const activityId = 'dvcr_live_match';
  static const _nativeChannel = MethodChannel('fr.dvcr.app/live_activity_native');
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
  static final Map<String, Uint8List> _logoByteCache = {};
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
  /// Empêche un apply / `ended` callback de recréer l’activité après Arrêter le live.
  static bool _dismissingLiveActivity = false;

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
    LiveActivityTokenService.ensureListeners();
    await _hubSub?.cancel();
    _hubSub = LiveStateService.watch().listen(_onHub);
    _ensureLifecycleHooks();
    unawaited(syncNow(hardRefresh: true));
  }

  /// Resync complète — au retour au 1er plan ou si l'affichage natif a décroché.
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

      var hub = await _fetchCurrentHub();
      if (hub != null && !hub.isMatchLive) {
        if (hub.liveMatchId.isNotEmpty &&
            _isSyntheticLiveId(hub.liveMatchId)) {
          return;
        }
        await dismissNow();
        return;
      }
      if (hub == null) {
        if (_dismissingLiveActivity) return;
        hub = _lastHub;
      }
      if (hub == null || !hub.isMatchLive) {
        if (hub != null &&
            hub.liveMatchId.isNotEmpty &&
            _isSyntheticLiveId(hub.liveMatchId)) {
          return;
        }
        await dismissNow();
        return;
      }

      await _reconcileRunningActivity();
      final runningId = _runningActivityId;
      if (runningId != null && runningId.isNotEmpty) {
        unawaited(_registerPushTokenIfAny(runningId));
      }
      unawaited(LiveActivityTokenService.flushPending());

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
      active: (active) {
        if (_dismissingLiveActivity) return;
        _runningActivityId = active.activityId;
        _nativeActive = true;
        unawaited(
          LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: true),
        );
        final token = active.activityToken.trim();
        if (token.isNotEmpty) {
          unawaited(
            LiveActivityTokenService.register(
              activityId: active.activityId,
              activityToken: token,
              matchId: _lastHub?.liveMatchId ?? '',
            ),
          );
        }
      },
      ended: (_) {
        _markNativeNeedsResync();
        unawaited(LiveActivityTokenService.clear());
        unawaited(
          LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: false),
        );
      },
      stale: (_) => _markNativeNeedsResync(),
    );
  }

  static void _markNativeNeedsResync() {
    _nativeActive = false;
    _runningActivityId = null;
    _lastSuccessfulNativeAt = null;
    if (_dismissingLiveActivity) return;
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

  /// Après notif « coup d'envoi » ou ouverture depuis le live.
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

    if (!_enabled) {
      await dismissNow();
      return;
    }
    if (!hub.isMatchLive) {
      final currentExists =
          LiveStateService.latestCurrent?.exists == true;
      if (!currentExists) {
        await dismissNow();
      } else {
        await _endNative();
        await LiveScoreStickyService.clearFallback();
        _syncChronoRefreshTimer(hub);
        _syncForegroundWatchdog(hub);
      }
      return;
    }

    _dismissingLiveActivity = false;

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
  /// sont fusionnés pour éviter qu'un vieux apply écrase un but/carton récent.
  static Future<void> _drainHubApplyQueue() async {
    _hubApplyInFlight = true;
    try {
      while (_pendingHubApply != null && !_dismissingLiveActivity) {
        final hub = _pendingHubApply!;
        final forceChronoTick = _pendingForceChronoTick;
        _pendingHubApply = null;
        _pendingForceChronoTick = false;
        await _applyHub(hub, forceChronoTick: forceChronoTick);
      }
    } finally {
      _hubApplyInFlight = false;
      if (_pendingHubApply != null && !_dismissingLiveActivity) {
        unawaited(_drainHubApplyQueue());
      }
    }
  }

  static Future<void> _applyHub(
    LiveHubState hub, {
    bool forceChronoTick = false,
  }) async {
    if (_dismissingLiveActivity || !hub.isMatchLive) return;
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
    // Sur iOS, on force un update supplémentaire tant que le chemin logo local
    // n'est pas encore confirmé (UserDefaults cross-process pas encore flushé
    // au premier render du widget).
    final logoNotConfirmed = Platform.isIOS &&
        (_cachedIosLogo1Path.isEmpty || _cachedIosLogo2Path.isEmpty) &&
        (quickLogo1.isNotEmpty || quickLogo2.isNotEmpty);
    final changed = forceChronoTick ||
        scoreChanged ||
        eventLineChanged ||
        logoNotConfirmed ||
        !_sameDisplay(_lastApplied, hub, quickLogo1, quickLogo2);
    if (!changed && !_forceStartNext && _nativeActive) {
      return;
    }

    // Reconcile seulement si on n'a pas encore d'activité confirmée
    if (!_nativeActive || _runningActivityId == null) {
      await _reconcileRunningActivity();
    }

    // Résolution logos : fast-path si déjà connus (évite Firestore à chaque update)
    final String effLogo1;
    final String effLogo2;
    if (quickLogo1.isNotEmpty && quickLogo2.isNotEmpty) {
      effLogo1 = quickLogo1;
      effLogo2 = quickLogo2;
    } else {
      final resolved = await LiveTeamLogoResolver.resolve(
        team1: hub.matchTeam1,
        team2: hub.matchTeam2,
        logo1: hub.matchLogo1,
        logo2: hub.matchLogo2,
        matchId: hub.liveMatchId,
      );
      effLogo1 = resolved.logo1;
      effLogo2 = resolved.logo2;
    }
    unawaited(_persistResolvedLogosIfNeeded(hub));

    final data = await _activityData(hub, effLogo1, effLogo2);

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
      // Les paths sont déjà mis en cache dans _activityData via _iosLogoPayload.
      unawaited(
        LiveActivityPushSync.persistNativeSnapshot(
          activityId: _runningActivityId,
          logo1Url: effLogo1,
          logo2Url: effLogo2,
          logo1Path: _cachedIosLogo1Path,
          logo2Path: _cachedIosLogo2Path,
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
      _lastEffLogo1 = effLogo1;
      _lastEffLogo2 = effLogo2;
      unawaited(_maybePlayEventSound(hub, isFirstBannerApply: firstApply));
      return;
    }

    if (changed || _forceStartNext) {
      final firstApply = _lastApplied == null;
      await LiveScoreStickyService.showFallback(hub);
      _lastApplied = hub;
      _lastEffLogo1 = effLogo1;
      _lastEffLogo2 = effLogo2;
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
    _logoByteCache.clear();
    _lastPlayedSoundKey = null;
    _lastSuccessfulNativeAt = null;
    _pendingHubApply = null;
    _pendingForceChronoTick = false;
    unawaited(LiveActivityPushSync.clearCachedActivity());
    unawaited(LiveActivityTokenService.clear());
    unawaited(
      LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: false),
    );
    if (_pluginReady) {
      try {
        await _plugin.endAllActivities();
      } catch (e) {
        debugPrint('DVCR LiveActivity end: $e');
      }
    }
    if (Platform.isIOS) {
      try {
        await _nativeChannel.invokeMethod<void>('endLiveActivity');
      } catch (_) {}
    }
  }

  /// Coupe immédiatement la Live Activity (fin de direct admin ou FCM live_end).
  static Future<void> dismissNow() async {
    _dismissingLiveActivity = true;
    _lastHub = null;
    _pendingHubApply = null;
    _pendingForceChronoTick = false;
    _forceStartNext = false;
    _chronoRefreshTimer?.cancel();
    _chronoRefreshTimer = null;
    _foregroundWatchdog?.cancel();
    _foregroundWatchdog = null;
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setBool(_prefForceStart, false)),
    );
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

  /// Push natif avec repli createOrUpdate si l'activité iOS/Android a décroché.
  static Future<bool> _pushNativeData(
    Map<String, dynamic> data, {
    LiveHubState? hub,
    LiveHubState? before,
    AlertConfig? alertConfig,
  }) async {
    if (_dismissingLiveActivity) return false;
    try {
      if (_runningActivityId == null || _forceStartNext) {
        if (_forceStartNext) {
          await _plugin.endAllActivities();
          _runningActivityId = null;
        }
        final id = await _plugin.createActivity(activityId, data);
        if (id == null || id.isEmpty) return false;
        _runningActivityId = id;
        unawaited(_registerPushTokenIfAny(id));
      } else if (Platform.isIOS) {
        // Le plugin updateActivity() pousse un ContentState CONSTANT (appGroupId
        // seul) → iOS dédoublonne et NE re-render PAS le widget. On passe par la
        // méthode native pushUpdate qui change le staleDate à chaque appel pour
        // forcer le re-render (sinon but/cartons/chrono ne se mettent jamais à jour).
        final pushed = await _nativeChannel.invokeMethod<bool>('pushUpdate', {
          'data': data,
          'alertTitle': alertConfig?.title ?? '',
          'alertBody': alertConfig?.body ?? '',
        });
        if (pushed != true) {
          // Repli : activité peut-être perdue côté natif → laisse le catch gérer.
          await _plugin.updateActivity(
            _runningActivityId!,
            data,
            alertConfig: alertConfig,
          );
        }
      } else {
        await _plugin.updateActivity(
          _runningActivityId!,
          data,
          alertConfig: alertConfig,
        );
      }
      _nativeActive = true;
      unawaited(
        LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: true),
      );
      return true;
    } catch (e) {
      debugPrint('DVCR LiveActivity update: $e');
      _nativeActive = false;
      try {
        await _plugin.createOrUpdateActivity(activityId, data);
        await _reconcileRunningActivity();
        if (_runningActivityId != null) {
          _nativeActive = true;
          unawaited(
            LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: true),
          );
          return true;
        }
      } catch (e2) {
        debugPrint('DVCR LiveActivity createOrUpdate: $e2');
      }
      return false;
    }
  }

  /// ActivityKit push token — retry : iOS le fournit souvent après createActivity.
  static Future<void> _registerPushTokenIfAny(String activityId) async {
    if (!Platform.isIOS) return;
    LiveActivityTokenService.ensureListeners();
    for (var i = 0; i < 8; i++) {
      try {
        final token = await _plugin.getPushToken(activityId);
        if (token != null && token.trim().isNotEmpty) {
          await LiveActivityTokenService.register(
            activityId: activityId,
            activityToken: token,
            matchId: _lastHub?.liveMatchId ?? '',
          );
          return;
        }
      } catch (e) {
        debugPrint('DVCR LiveActivity getPushToken: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: 350 + i * 250));
    }
    debugPrint('DVCR LiveActivity: push token unavailable after retries');
  }

  static Future<Map<String, dynamic>> _activityData(
    LiveHubState hub,
    String logo1,
    String logo2,
  ) async {
    final now = DateTime.now();
    final end = now.add(const Duration(hours: 3));
    final status = _statusLabel(hub);
    final lastGoal = LiveBannerFormat.lockScreenEventLine(hub);

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
      'lastEventIsHome': LiveBannerFormat.lastEventIsHome(hub),
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
      final p1 = await _iosLogoPayload(logo1,
          cachedUrl: _lastEffLogo1,
          cachedPath: _cachedIosLogo1Path,
          fixedFileName: 'teamA.png',
          logoKey: 'teamALogo');
      final p2 = await _iosLogoPayload(logo2,
          cachedUrl: _lastEffLogo2,
          cachedPath: _cachedIosLogo2Path,
          fixedFileName: 'teamB.png',
          logoKey: 'teamBLogo');
      // Mise en cache immédiate — le chemin est connu avant même l'appel plugin,
      // plus besoin d'attendre _fetchAndCacheLogoPaths après la mise à jour.
      if (p1.isNotEmpty) _cachedIosLogo1Path = p1;
      if (p2.isNotEmpty) _cachedIosLogo2Path = p2;
      data['teamALogo'] = p1;
      data['teamBLogo'] = p2;
    } else if (Platform.isAndroid) {
      data['teamAImageUrl'] = logo1;
      data['teamBImageUrl'] = logo2;
    }

    return data;
  }

  /// Télécharge le logo via http, le convertit en PNG, l'écrit dans le
  /// conteneur AppGroup via la méthode native [writeLogoFile] qui pré-synchronise
  /// UserDefaults avant que le plugin crée/mette à jour l'activité.
  /// Retourne le chemin absolu du fichier, ou '' en cas d'échec.
  static Future<String> _iosLogoPayload(
    String url, {
    String cachedUrl = '',
    String cachedPath = '',
    String fixedFileName = 'logo.png',
    String logoKey = 'teamALogo',
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    // Fast-path : même URL + chemin déjà connu → rien à réécrire
    if (trimmed == cachedUrl.trim() && cachedPath.isNotEmpty) {
      return cachedPath;
    }
    Uint8List? bytes = _logoByteCache[trimmed];
    if (bytes == null) {
      try {
        final response = await http
            .get(Uri.parse(trimmed))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          bytes = response.bodyBytes;
          _logoByteCache[trimmed] = bytes;
        }
      } catch (e) {
        debugPrint('LiveActivity logo download: $e');
      }
    }
    if (bytes == null || bytes.isEmpty) return '';

    // Conversion forcée en PNG + redimensionnement à 120 px.
    // Deux raisons critiques :
    //  1. Wix peut servir AVIF/WebP même avec extension .png — UIImage(contentsOfFile:)
    //     dans le widget extension ne supporte pas ces formats de façon fiable.
    //  2. L'extension Live Activity a un budget mémoire très strict (~30 Mo). Un logo
    //     pleine résolution (500×500+) fait échouer silencieusement le décodage UIImage
    //     → carré gris. On décode directement à une cible de 120 px (suffisant pour la
    //     Dynamic Island 18-52 px et le Lock Screen 36 px, même en @3x).
    Uint8List pngBytes = bytes;
    try {
      // Seul targetWidth est fixé → la hauteur est calculée pour préserver le
      // ratio (pas de déformation des logos non-carrés).
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 120,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (byteData != null && byteData.lengthInBytes > 0) {
        pngBytes = byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('LiveActivity logo PNG convert: $e');
    }

    // Écriture dans AppGroup + pré-sync UserDefaults via méthode native.
    // Cela garantit que le widget extension voit les données correctes dès
    // la première render, avant même que le plugin appelle synchronize().
    try {
      final path = await _nativeChannel.invokeMethod<String>('writeLogoFile', {
        'fileName': fixedFileName,
        'logoKey': logoKey,
        'bytes': pngBytes,
      });
      if (path != null && path.isNotEmpty) {
        _logoByteCache.remove(trimmed); // plus besoin des bytes en mémoire
        return path;
      }
    } catch (e) {
      debugPrint('LiveActivity writeLogoFile: $e');
    }

    // Repli : passe par LiveActivityFileFromMemory si la méthode native échoue
    _logoByteCache[trimmed] = pngBytes;
    return '';
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

  /// Toutes les 30 s au 1er plan : resync si le natif n'a pas répondu récemment.
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

  /// Rafraîchissement léger de la minute (sans logos / sans file d'attente lourde).
  static Future<void> _pushChronoRefresh(LiveHubState hub) async {
    if (_dismissingLiveActivity) return;
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
      // Inclure les logos dans chaque refresh — le plugin écrase toutes les clés
      // UserDefaults à chaque update et le widget perdrait les images sinon.
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

    final currentKey = _eventSoundKey(hub);
    // Déduplication principale : même événement que l'état précédent
    if (before != null && currentKey == _eventSoundKey(before)) return null;
    // Déduplication sur resync (hardRefresh remet before=null) :
    // on ne répète pas une alerte déjà envoyée pour cette clé d'événement
    if (currentKey.isNotEmpty && currentKey == _lastPlayedSoundKey) return null;

    final line = LiveBannerFormat.lockScreenEventLine(hub);
    if (line.isEmpty) return null;

    final type = _lastEventType(hub);
    final title = switch (type) {
      'goal' => '⚽ BUT !',
      'yellow' || 'yellow_card' => '🟨 Carton jaune',
      'red' || 'red_card' => '🟥 Carton rouge',
      'substitution' => '🔄 Remplacement',
      _ => null,
    };
    if (title == null) {
      if (hub.isHalftime) {
        return AlertConfig(title: '⏸ Mi-temps', body: LiveBannerFormat.minuteLabel(hub));
      }
      if (hub.isFulltime || hub.isExtraFulltime) {
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
    // Renfort haptique si l'app tourne encore (Alert Live Activity = son côté iOS).
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
