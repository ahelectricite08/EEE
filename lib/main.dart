import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'theme/dvcr_theme.dart';
import 'theme/app_colors.dart';
import 'services/app_cache_service.dart';
import 'services/podcast_controller.dart';
import 'services/live_sfx_service.dart';
import 'services/match_controller.dart';
import 'services/match_weather_service.dart';
import 'services/fff_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/articles/articles_list_widgets.dart';
import 'screens/chat_screen.dart';
import 'features/prono/prono_public.dart';
import 'screens/global_search_screen.dart';
import 'screens/admin_web_screen.dart';
import 'features/auth/auth.dart';
import 'screens/tutorial_screen.dart';
import 'app/app_router.dart';
import 'navigation/app_shell_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/network_banner.dart';
import 'services/notification_service.dart';
import 'services/live_match_activity_service.dart';
import 'services/live_activity_push_sync.dart';
import 'services/fcm_token_service.dart';
import 'services/notification_prefs_service.dart';
import 'services/share_templates_cache.dart';
import 'services/feature_flags_service.dart';
import 'services/app_hourly_presence_service.dart';
import 'services/live_score_presence_service.dart';
import 'services/app_version_policy_service.dart';
import 'widgets/app_update_optional_banner.dart';
import 'widgets/adhesion_splash.dart';
import 'screens/force_update_screen.dart';
import 'navigation/community_chat_rollout.dart';
import 'navigation/prono_championship_rollout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

part 'main_bootstrap.dart';
part 'main_navigation.dart';
part 'main_shell_widgets.dart';

Future<void>? _appBootstrap;

void main() async {
  FlutterError.onError = (details) {
    debugPrint('DVCR FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('DVCR FLUTTER ERROR stack: ${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('DVCR PLATFORM ERROR: $error');
    debugPrint('DVCR PLATFORM ERROR stack: $stack');
    return false;
  };
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColorsLight.scaffold,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColorsLight.scaffold,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  debugPrint('DVCR: start init');
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('DVCR: date format error: $e');
  }
  debugPrint('DVCR: date ok');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundLiveSync);
    }
  } catch (e) {
    debugPrint('DVCR: firebase error: $e');
  }
  debugPrint('DVCR: firebase ok');
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('DVCR: firestore cache ok');
  } catch (e) {
    debugPrint('DVCR: firestore cache error: $e');
  }
  final bootstrap = _appBootstrap ??= _bootstrapCriticalServices();
  // Foundation: Riverpod root. No métier providers yet — Auth+ will add them.
  runApp(
    ProviderScope(
      child: DVCRApp(bootstrap: bootstrap),
    ),
  );
  unawaited(_initDeferredServices(bootstrap));
}

Future<void> _bootstrapCriticalServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 700));
  await _runBootstrapStep('app cache', AppCacheService.init);
  await _runBootstrapStep('podcast', PodcastController.instance.init);
  await _runBootstrapStep('live sfx', LiveSfxService.instance.start);
  await _runBootstrapStep('match controller', MatchController.instance.init);
  await _runBootstrapStep('local notifications', NotificationService.init);
  if (!kIsWeb) {
    await _runBootstrapStep(
      'live lock screen score',
      LiveMatchActivityService.start,
    );
    await _runBootstrapStep(
      'live score presence',
      LiveScorePresenceService.instance.start,
    );
  }
}

Future<void> _initDeferredServices(Future<void> bootstrap) async {
  await bootstrap;
  FeatureFlagsService.ensureListener();
  ShareTemplatesCache.start();
  // Météo carte home : fetch Open-Meteo à chaque ouverture app (pas sur rebuild carte).
  unawaited(MatchWeatherService.instance.refreshFromAppOpen());
  // FCM wakes Google Play Services; delaying it avoids a startup memory spike
  // on small Android emulators while keeping notifications enabled normally.
  await Future<void>.delayed(const Duration(seconds: 2));
  await _initMessaging();
}

Future<void> _runBootstrapStep(
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
    debugPrint('DVCR: $label ok');
  } catch (e) {
    debugPrint('DVCR: $label error: $e');
  }
}

Future<void> _initMessaging() async {
  try {
    NotificationService.setNotificationTapHandler(handleDvcrNotificationPayload);
    await FcmTokenService.requestPermission().timeout(
      const Duration(seconds: 10),
    );
    debugPrint('DVCR: messaging ok');
    await FcmTokenService.syncToken();
    await FcmTokenService.startListening();
    FirebaseMessaging.onMessage.listen((message) async {
      final data = message.data;
      if (data['endLive'] == '1' || data['type'] == 'live_end') {
        unawaited(LiveMatchActivityService.dismissNow());
        unawaited(NotificationService.showRemoteMessage(message));
        return;
      }
      unawaited(LiveActivityPushSync.handleRemoteMessage(message));
      if (data['syncLiveActivity'] == '1') {
        final eventType = (data['type'] ?? '').toString();
        if (_isNotifiableEventType(eventType) &&
            (!await LiveActivityPushSync.hasActiveLiveActivity() ||
                LiveActivityPushSync.allowsVisibleBannerWithLiveActivity(
                  data,
                ))) {
          final title = (data['alertTitle'] ?? '').toString().trim();
          if (title.isNotEmpty) {
            final short = (data['alertShortBody'] ?? '').toString().trim();
            final body = short.isNotEmpty
                ? short
                : (data['alertBody'] ?? data['lastEventLine'] ?? '')
                    .toString()
                    .trim();
            unawaited(NotificationService.showLiveEvent(
              title: title,
              body: body.isEmpty ? title : body,
              type: eventType,
            ));
          }
        }
        return;
      }
      if (data['notifyVisible'] == '1') {
        if (await LiveActivityPushSync.hasActiveLiveActivity() &&
            !LiveActivityPushSync.allowsVisibleBannerWithLiveActivity(data)) {
          return;
        }
        unawaited(NotificationService.showRemoteMessage(message));
        return;
      }
      if (!NotificationService.shouldDisplayBanner(message)) return;
      unawaited(NotificationService.showRemoteMessage(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(
        pushScreenForNotificationData(
          Map<String, dynamic>.from(message.data),
        ),
      );
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(
        pushScreenForNotificationData(
          Map<String, dynamic>.from(initialMessage.data),
        ),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await NotificationPrefsService.pullFromFirestoreAndCacheLocal(uid);
      } catch (e) {
        debugPrint('DVCR: notification prefs pull: $e');
      }
    }
    bool readNotifBool(String k, String legacy) =>
        prefs.getBool(k) ?? prefs.getBool(legacy) ?? true;
    final notifEnabled = readNotifBool('notif_live', 'profile_notif_live');
    final alertsEnabled = readNotifBool('notif_alerts', 'profile_notif_alerts');
    final actusEnabled = readNotifBool('notif_actus', 'profile_notif_actus');
    final liveEventsEnabled =
        readNotifBool('notif_live_events', 'profile_notif_live_events');
    if (notifEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_live');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live');
    }
    if (alertsEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_alerts');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_alerts');
    }
    if (actusEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_articles');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_articles');
    }
    if (liveEventsEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_live_events');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live_events');
    }
    // Topic admin (rappels match Sedan, etc.) — pas de toggle utilisateur.
    await FirebaseMessaging.instance.subscribeToTopic('dvcr_notifications');
  } catch (e) {
    debugPrint('DVCR: messaging/prefs error: $e');
  }
}

const _kNotifiableTypes = {
  'goal',
  'goal_cancelled',
  'goal_disallowed',
  'yellow',
  'yellow_card',
  'red',
  'red_card',
  'substitution',
  'offside',
  'kickoff',
  'live_start',
  'halftime',
  'fulltime',
  'extra_time',
  'extra_halftime',
  'extra_fulltime',
};

bool _isNotifiableEventType(String type) => _kNotifiableTypes.contains(type);


