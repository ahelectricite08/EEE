import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/club_branding.dart';
import '../firebase_options.dart';
import 'live_banner_format.dart';
import 'live_state_service.dart';
import 'notification_service.dart';

/// Met à jour la Live Activity quand une push FCM live arrive (app en arrière-plan).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundLiveSync(RemoteMessage message) async {
  // Obligatoire avant tout appel plugin (MethodChannel) dans un isolate background.
  WidgetsFlutterBinding.ensureInitialized();
  await LiveActivityPushSync.handleRemoteMessage(message, background: true);
}

class LiveActivityPushSync {
  LiveActivityPushSync._();

  static const _nativeChannel =
      MethodChannel('fr.dvcr.app/live_activity_native');

  static const activityId = 'dvcr_live_match';
  static const appGroupId = 'group.fr.dvcr.app.liveactivities';
  static const _prefEnabled = 'notif_live_sticky_score';
  static const _prefActivityId = 'live_la_running_id';
  static const _prefLogo1Path = 'live_la_logo1_path';
  static const _prefLogo2Path = 'live_la_logo2_path';
  static const _prefLogo1Url = 'live_la_logo1_url';
  static const _prefLogo2Url = 'live_la_logo2_url';

  /// Bannières visibles même quand une Live Activity est déjà affichée.
  static const alwaysVisibleBannerTypes = {
    'live_start',
    'kickoff',
    'live_end',
  };

  static bool allowsVisibleBannerWithLiveActivity(Map<String, dynamic> data) {
    if (data['endLive'] == '1' || data['type'] == 'live_end') return true;
    final type = (data['type'] ?? '').toString();
    return alwaysVisibleBannerTypes.contains(type);
  }

  static const _syncTypes = {
    'live_sync',
    'live_end',
    'goal',
    'yellow',
    'red',
    'substitution',
    'kickoff',
    'live_start',
    'halftime',
    'fulltime',
    'extra_time',
    'extra_halftime',
    'extra_fulltime',
    'goal_cancelled',
    'goal_disallowed',
    'offside',
    'yellow_card',
    'red_card',
  };

  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool background = false,
  }) async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
    final data = Map<String, dynamic>.from(message.data);
    if (data['endLive'] == '1' || data['type'] == 'live_end') {
      await dismissLiveActivity();
      return;
    }
    if (!_shouldSync(data)) return;

    if (background) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(_prefEnabled) ?? prefs.getBool('notif_live') ?? true;
    final laActive = await hasActiveLiveActivity();
    if (!enabled && !laActive) return;

    try {
      // Priorité : hub depuis FCM si complet, sinon fetch Firestore
      LiveHubState? hub = data['syncLiveActivity'] == '1'
          ? _hubFromFcmData(data)
          : await _fetchHub();
      // Si les logos manquent dans le FCM, on fetch Firestore pour les récupérer
      if (hub != null && hub.isMatchLive &&
          hub.matchLogo1.isEmpty && hub.matchLogo2.isEmpty) {
        final fetched = await _fetchHub();
        if (fetched != null && fetched.isMatchLive) hub = fetched;
      }
      if (hub == null || !hub.isMatchLive) return;

      await _pushToNative(
        hub,
        prefs,
        eventLineOverride: (data['lastEventLine'] ?? '').toString(),
      );

      // iOS : notif locale gérée nativement dans LiveActivityFcmSync.
      if (!Platform.isIOS) {
        await _showPushIfNoLiveActivity(data);
      }
    } catch (e, st) {
      debugPrint('LiveActivityPushSync: $e\n$st');
    }
  }

  static Future<void> persistNativeSnapshot({
    required String? activityId,
    required String logo1Url,
    required String logo2Url,
    required String logo1Path,
    required String logo2Path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (activityId != null && activityId.isNotEmpty) {
      await prefs.setString(_prefActivityId, activityId);
    }
    await prefs.setString(_prefLogo1Url, logo1Url);
    await prefs.setString(_prefLogo2Url, logo2Url);
    if (logo1Path.isNotEmpty) await prefs.setString(_prefLogo1Path, logo1Path);
    if (logo2Path.isNotEmpty) await prefs.setString(_prefLogo2Path, logo2Path);
    if (Platform.isIOS) {
      try {
        await _nativeChannel.invokeMethod<void>('mirrorSnapshot', {
          'activityId': activityId ?? '',
          'logo1Path': logo1Path,
          'logo2Path': logo2Path,
          'logo1Url': logo1Url,
          'logo2Url': logo2Url,
        });
      } catch (e) {
        debugPrint('LiveActivityPushSync mirrorSnapshot: $e');
      }
    }
  }

  static bool _shouldSync(Map<String, dynamic> data) {
    if (data['endLive'] == '1' || data['type'] == 'live_end') return true;
    if (data['syncLiveActivity'] == '1') return true;
    final type = (data['type'] ?? '').toString();
    return _syncTypes.contains(type);
  }

  static Future<bool> hasActiveLiveActivity() async {
    if (Platform.isIOS) {
      try {
        final active =
            await _nativeChannel.invokeMethod<bool>('hasActiveLiveActivity');
        if (active == true) return true;
      } catch (_) {}
    }
    try {
      final plugin = LiveActivities();
      await plugin.init(appGroupId: appGroupId, urlScheme: 'dvcr');
      final ids = await plugin.getAllActivitiesIds();
      return ids.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _showPushIfNoLiveActivity(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    if (type == 'live_sync' || type == 'live_end') return;

    final title = (data['alertTitle'] ?? '').toString().trim();
    if (title.isEmpty) return;
    if (await hasActiveLiveActivity() &&
        !allowsVisibleBannerWithLiveActivity(data)) {
      return;
    }

    final short = (data['alertShortBody'] ?? '').toString().trim();
    final body = short.isNotEmpty
        ? short
        : (data['alertBody'] ?? data['lastEventLine'] ?? '').toString().trim();
    await NotificationService.showLiveEvent(
      title: title,
      body: body.isEmpty ? title : body,
      type: type,
    );
  }

  static Future<void> dismissLiveActivity() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
    try {
      final plugin = LiveActivities();
      await plugin.init(appGroupId: appGroupId, urlScheme: 'dvcr');
      await plugin.endAllActivities();
    } catch (e) {
      debugPrint('LiveActivityPushSync dismiss: $e');
    }
    await clearCachedActivity();
    if (Platform.isIOS) {
      try {
        await _nativeChannel.invokeMethod<void>('endLiveActivity');
      } catch (_) {}
    }
  }

  static Future<void> clearCachedActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefActivityId);
    await prefs.remove(_prefLogo1Path);
    await prefs.remove(_prefLogo2Path);
    await prefs.remove(_prefLogo1Url);
    await prefs.remove(_prefLogo2Url);
  }

  static LiveHubState? _hubFromFcmData(Map<String, dynamic> data) {
    final matchId = (data['matchId'] ?? '').toString().trim();
    if (matchId.isEmpty) return null;

    final lastEvent = (data['lastEvent'] ?? '').toString();
    return LiveHubState(
      isMatchLive: true,
      isEmissionLive: false,
      scoreHome: _int(data['scoreHome']),
      scoreAway: _int(data['scoreAway']),
      matchTeam1: (data['team1'] ?? '').toString(),
      matchTeam2: (data['team2'] ?? '').toString(),
      matchLogo1: (data['logo1'] ?? '').toString(),
      matchLogo2: (data['logo2'] ?? '').toString(),
      minute: _int(data['minute']),
      chronoRunning: data['chronoRunning'] == '1',
      chronoBaseSeconds: _int(data['chronoBaseSeconds']),
      chronoStartedAtMs: _int(data['chronoStartedAtMs']),
      isHalftime: lastEvent == 'halftime',
      isExtraHalftime: lastEvent == 'extra_halftime',
      isFulltime: lastEvent == 'fulltime',
      isExtraFulltime: lastEvent == 'extra_fulltime',
      isExtraTimePlaying: lastEvent == 'extra_time',
      liveMatchId: matchId,
    );
  }

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Future<LiveHubState?> _fetchHub() async {
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get(const GetOptions(source: Source.cache));
    }
    if (!snap.exists) return null;
    return LiveHubState.fromSnapshots(current: snap, emission: null);
  }

  static Future<void> _pushToNative(
    LiveHubState hub,
    SharedPreferences prefs, {
    String eventLineOverride = '',
  }) async {
    final plugin = LiveActivities();
    await plugin.init(appGroupId: appGroupId, urlScheme: 'dvcr');

    final logo1 = hub.matchLogo1.trim();
    final logo2 = hub.matchLogo2.trim();
    final data = await _activityData(
      hub,
      logo1,
      logo2,
      prefs,
      eventLineOverride: eventLineOverride,
    );

    final storedId = prefs.getString(_prefActivityId);
    try {
      if (storedId != null && storedId.isNotEmpty) {
        await plugin.updateActivity(storedId, data);
        await persistNativeSnapshot(
          activityId: storedId,
          logo1Url: logo1,
          logo2Url: logo2,
          logo1Path:
              data['teamALogo'] is String ? data['teamALogo'] as String : '',
          logo2Path:
              data['teamBLogo'] is String ? data['teamBLogo'] as String : '',
        );
        return;
      }
    } catch (e) {
      debugPrint('LiveActivityPushSync update: $e');
    }

    await plugin.createOrUpdateActivity(activityId, data);
    final ids = await plugin.getAllActivitiesIds();
    if (ids.isNotEmpty) {
      await persistNativeSnapshot(
        activityId: ids.first,
        logo1Url: logo1,
        logo2Url: logo2,
        logo1Path:
            data['teamALogo'] is String ? data['teamALogo'] as String : '',
        logo2Path:
            data['teamBLogo'] is String ? data['teamBLogo'] as String : '',
      );
    }
  }

  static Future<Map<String, dynamic>> _activityData(
    LiveHubState hub,
    String logo1,
    String logo2,
    SharedPreferences prefs, {
    String eventLineOverride = '',
  }) async {
    final now = DateTime.now();
    final status = LiveBannerFormat.minuteLabel(hub);
    final fromHub = LiveBannerFormat.lockScreenEventLine(hub);
    final override = eventLineOverride.trim();
    final lastEvent = override.isNotEmpty ? override : fromHub;
    final imageOpts = LiveActivityImageFileOptions(resizeFactor: 1.0);

    final data = <String, dynamic>{
      'matchName': ClubBranding.liveActivityBrand,
      'teamAName': _shortTeam(hub.matchTeam1),
      'teamAState': status,
      'teamAScore': hub.scoreHome,
      'teamBName': _shortTeam(hub.matchTeam2),
      'teamBState': 'LIVE',
      'teamBScore': hub.scoreAway,
      'lastGoalLine': lastEvent,
      'lastEventLine': lastEvent,
      'lastEventIsHome': LiveBannerFormat.lastEventIsHome(hub),
      'matchMinute': status,
      'matchStartDate': now.millisecondsSinceEpoch,
      'matchEndDate': now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
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
      'contentTick': now.millisecondsSinceEpoch,
    };

    if (Platform.isIOS) {
      data['teamALogo'] = await _iosLogo(logo1, prefs, isA: true, imageOpts: imageOpts);
      data['teamBLogo'] = await _iosLogo(logo2, prefs, isA: false, imageOpts: imageOpts);
    } else if (Platform.isAndroid) {
      data['teamAImageUrl'] = logo1;
      data['teamBImageUrl'] = logo2;
    }

    return data;
  }

  static Future<dynamic> _iosLogo(
    String url,
    SharedPreferences prefs, {
    required bool isA,
    required LiveActivityImageFileOptions imageOpts,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    final cachedUrl = prefs.getString(isA ? _prefLogo1Url : _prefLogo2Url) ?? '';
    final cachedPath = prefs.getString(isA ? _prefLogo1Path : _prefLogo2Path) ?? '';
    if (trimmed == cachedUrl && cachedPath.isNotEmpty) return cachedPath;

    try {
      final response = await http
          .get(Uri.parse(trimmed))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final fileName = trimmed.split('/').last.split('?').first;
        return LiveActivityFileFromMemory.image(
          response.bodyBytes,
          fileName.isNotEmpty ? fileName : 'logo.png',
          imageOptions: imageOpts,
        );
      }
    } catch (e) {
      debugPrint('LiveActivityPushSync logo download: $e');
    }
    return '';
  }

  static String _shortTeam(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 16) return t;
    return '${t.substring(0, 14)}…';
  }

  static String _lastEventPhase(LiveHubState hub) {
    if (hub.isFulltime) return 'fulltime';
    if (hub.isExtraFulltime) return 'extra_fulltime';
    if (hub.isHalftime) return 'halftime';
    if (hub.isExtraHalftime) return 'extra_halftime';
    if (hub.isExtraTimePlaying) return 'extra_time';
    return '';
  }
}
