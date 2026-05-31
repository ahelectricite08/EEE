import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/club_branding.dart';
import 'live_banner_format.dart';
import 'live_score_sticky_service.dart';
import 'live_state_service.dart';
import 'live_event_sound_service.dart';
import 'live_team_logo_resolver.dart';

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
  static String? _lastPlayedSoundKey;
  static Timer? _chronoRefreshTimer;

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
  }

  static Future<void> stop() async {
    _chronoRefreshTimer?.cancel();
    _chronoRefreshTimer = null;
    await _hubSub?.cancel();
    _hubSub = null;
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

  static Future<void> _onHub(LiveHubState hub) async {
    await _refreshEnabled();
    _lastHub = hub;

    if (!_enabled || !hub.isMatchLive) {
      _forceStartNext = false;
      await SharedPreferences.getInstance()
          .then((p) => p.setBool(_prefForceStart, false));
      await _endNative();
      await LiveScoreStickyService.clearFallback();
      _syncChronoRefreshTimer(hub);
      return;
    }

    _syncChronoRefreshTimer(hub);

    final resolved = await LiveTeamLogoResolver.resolve(
      team1: hub.matchTeam1,
      team2: hub.matchTeam2,
      logo1: hub.matchLogo1,
      logo2: hub.matchLogo2,
      matchId: hub.liveMatchId,
    );
    await _persistResolvedLogosIfNeeded(hub, resolved.logo1, resolved.logo2);

    final data = _activityData(hub, resolved.logo1, resolved.logo2);
    final changed = !_sameDisplay(_lastApplied, hub, resolved.logo1, resolved.logo2);
    if (!changed && !_forceStartNext && _nativeActive) {
      return;
    }

    var nativeOk = false;
    if (_pluginReady) {
      try {
        if (_runningActivityId == null || _forceStartNext) {
          if (_forceStartNext) {
            await _plugin.endAllActivities();
            _runningActivityId = null;
          }
          final id = await _plugin.createActivity(activityId, data);
          if (id != null && id.isNotEmpty) {
            _runningActivityId = id;
            _nativeActive = true;
            nativeOk = true;
          }
        } else {
          await _plugin.updateActivity(_runningActivityId!, data);
          _nativeActive = true;
          nativeOk = true;
        }
      } catch (e) {
        debugPrint('DVCR LiveActivity update: $e');
        _nativeActive = false;
      }
    }

    if (nativeOk) {
      _forceStartNext = false;
      await SharedPreferences.getInstance()
          .then((p) => p.setBool(_prefForceStart, false));
      await LiveScoreStickyService.clearFallback();
      final firstApply = _lastApplied == null;
      _lastApplied = hub;
      _lastEffLogo1 = resolved.logo1;
      _lastEffLogo2 = resolved.logo2;
      await _maybePlayEventSound(hub, isFirstBannerApply: firstApply);
      return;
    }

    if (changed || _forceStartNext) {
      final firstApply = _lastApplied == null;
      await LiveScoreStickyService.showFallback(hub);
      _lastApplied = hub;
      _lastEffLogo1 = resolved.logo1;
      _lastEffLogo2 = resolved.logo2;
      await _maybePlayEventSound(hub, isFirstBannerApply: firstApply);
    }
    _forceStartNext = false;
    await SharedPreferences.getInstance()
        .then((p) => p.setBool(_prefForceStart, false));
  }

  static Future<void> _endNative() async {
    _nativeActive = false;
    _runningActivityId = null;
    _lastApplied = null;
    _lastEffLogo1 = '';
    _lastEffLogo2 = '';
    _lastPlayedSoundKey = null;
    if (!_pluginReady) return;
    try {
      await _plugin.endAllActivities();
    } catch (e) {
      debugPrint('DVCR LiveActivity end: $e');
    }
  }

  static Future<void> _persistResolvedLogosIfNeeded(
    LiveHubState hub,
    String logo1,
    String logo2,
  ) async {
    if (!hub.isMatchLive) return;
    final patch = <String, dynamic>{};
    if (hub.matchLogo1.trim().isEmpty && logo1.isNotEmpty) {
      patch['logo1'] = logo1;
    }
    if (hub.matchLogo2.trim().isEmpty && logo2.isNotEmpty) {
      patch['logo2'] = logo2;
    }
    if (patch.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .set(patch, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DVCR LiveActivity logo persist: $e');
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
      'lastEventType': _lastEventType(hub),
      'liveEventSoundKey': _eventSoundKey(hub),
    };

    if (Platform.isIOS) {
      if (logo1.isNotEmpty) {
        data['teamALogo'] = LiveActivityFileFromUrl.image(logo1, imageOptions: imageOpts);
      }
      if (logo2.isNotEmpty) {
        data['teamBLogo'] = LiveActivityFileFromUrl.image(logo2, imageOptions: imageOpts);
      }
    } else if (Platform.isAndroid) {
      data['teamAImageUrl'] = logo1;
      data['teamBImageUrl'] = logo2;
    }

    return data;
  }

  static void _syncChronoRefreshTimer(LiveHubState hub) {
    if (!_enabled || !hub.isMatchLive || !hub.chronoRunning) {
      _chronoRefreshTimer?.cancel();
      _chronoRefreshTimer = null;
      return;
    }
    if (_chronoRefreshTimer != null) return;
    _chronoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final last = _lastHub;
      if (last != null && last.isMatchLive) {
        unawaited(_onHub(last));
      }
    });
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
        a.minute == b.minute &&
        a.isHalftime == b.isHalftime &&
        a.isFulltime == b.isFulltime &&
        a.isExtraHalftime == b.isExtraHalftime &&
        a.isExtraFulltime == b.isExtraFulltime &&
        a.chronoRunning == b.chronoRunning &&
        a.chronoBaseSeconds == b.chronoBaseSeconds &&
        a.chronoStartedAtMs == b.chronoStartedAtMs &&
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

  static Future<void> _maybePlayEventSound(
    LiveHubState hub, {
    required bool isFirstBannerApply,
  }) async {
    final key = _eventSoundKey(hub);
    if (key.isEmpty) return;
    if (_lastPlayedSoundKey == key) return;
    _lastPlayedSoundKey = key;
    if (isFirstBannerApply) return;
    // Android : sons gérés dans [DvcrLiveActivityManager] à chaque mise à jour notif.
    if (Platform.isAndroid) return;
    await LiveEventSoundService.maybePlayForEvent(_lastEventType(hub));
  }

}
