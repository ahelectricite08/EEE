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
import 'services/app_version_policy_service.dart';
import 'widgets/app_update_optional_banner.dart';
import 'services/helloasso_adhesion_service.dart';
import 'widgets/adhesion_splash.dart';
import 'widgets/lineup_cinematic_overlay.dart';
import 'widgets/match_sheet_share_host.dart';
import 'widgets/splash_loading_ball.dart';
import 'widgets/hub_hero_photo.dart';
import 'widgets/dvcr_network_image.dart';
import 'services/app_settings_service.dart';
import 'utils/remote_image_url.dart';
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
    if (details.silent) return;
    if (isBenignRemoteImageFailureMessage(details.exceptionAsString())) {
      return;
    }
    debugPrint('DVCR FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('DVCR FLUTTER ERROR stack: ${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (isBenignRemoteImageFailureMessage(error.toString())) return true;
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
  FeatureFlagsService.ensureListener();
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
    await FcmTokenService.startListening(
      onTokenRefreshExtra: () => unawaited(_syncFcmTopics()),
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_syncFcmAfterAuth(user));
    });
    FirebaseMessaging.onMessage.listen((message) async {
      final data = message.data;
      if (data['endLive'] == '1' || data['type'] == 'live_end') {
        final hadLa = await LiveActivityPushSync.hasActiveLiveActivity();
        unawaited(LiveMatchActivityService.dismissNow());
        unawaited(
          LiveActivityPushSync.syncLiveBannerTopic(liveActivityActive: false),
        );
        if (!hadLa) {
          unawaited(NotificationService.showRemoteMessage(message));
        }
        return;
      }
      unawaited(LiveActivityPushSync.handleRemoteMessage(message));
      if (data['syncLiveActivity'] == '1') {
        final eventType = (data['type'] ?? '').toString();
        final laActive = await LiveActivityPushSync.hasActiveLiveActivity();
        if (laActive) return;
        // FCM `notification` déjà affiché par l’OS (iOS willPresent).
        // Android 1er plan : l’OS n’affiche pas, on pose la locale.
        final osShowsBanner = message.notification != null &&
            defaultTargetPlatform != TargetPlatform.android;
        if (data['notifyVisible'] == '1' &&
            _isNotifiableEventType(eventType) &&
            !osShowsBanner) {
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
        if (await LiveActivityPushSync.hasActiveLiveActivity()) return;
        unawaited(NotificationService.showRemoteMessage(message));
        return;
      }
      if (!NotificationService.shouldDisplayBanner(message)) return;
      if (await LiveActivityPushSync.hasActiveLiveActivity() &&
          _isNotifiableEventType((data['type'] ?? '').toString())) {
        return;
      }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await NotificationPrefsService.pullFromFirestoreAndCacheLocal(uid);
      } catch (e) {
        debugPrint('DVCR: notification prefs pull: $e');
      }
    }
    await _syncFcmTopics();
  } catch (e) {
    debugPrint('DVCR: messaging/prefs error: $e');
  }
}

/// Relance token + topics après login (le boot peut précéder l’auth restaurée).
Future<void> _syncFcmAfterAuth(User? user) async {
  if (user == null) return;
  try {
    await NotificationPrefsService.pullFromFirestoreAndCacheLocal(user.uid);
  } catch (e) {
    debugPrint('DVCR: notification prefs pull (auth): $e');
  }
  try {
    await FcmTokenService.syncToken();
  } catch (e) {
    debugPrint('DVCR: FCM token sync (auth): $e');
  }
  await _syncFcmTopics();
}

Future<void> _syncFcmTopics() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    bool readNotifBool(String k, String legacy) =>
        prefs.getBool(k) ?? prefs.getBool(legacy) ?? true;
    final notifEnabled = readNotifBool('notif_live', 'profile_notif_live');
    final alertsEnabled = readNotifBool('notif_alerts', 'profile_notif_alerts');
    final actusEnabled = readNotifBool('notif_actus', 'profile_notif_actus');
    final clubEnabled = readNotifBool('notif_club', 'profile_notif_club');
    final liveEventsEnabled =
        readNotifBool('notif_live_events', 'profile_notif_live_events');
    final messaging = FirebaseMessaging.instance;
    if (notifEnabled) {
      await messaging.subscribeToTopic('dvcr_live');
    } else {
      await messaging.unsubscribeFromTopic('dvcr_live');
    }
    if (alertsEnabled) {
      await messaging.subscribeToTopic('dvcr_alerts');
    } else {
      await messaging.unsubscribeFromTopic('dvcr_alerts');
    }
    if (actusEnabled) {
      await messaging.subscribeToTopic('dvcr_articles');
    } else {
      await messaging.unsubscribeFromTopic('dvcr_articles');
    }
    if (liveEventsEnabled) {
      await messaging.subscribeToTopic('dvcr_live_events');
    } else {
      await messaging.unsubscribeFromTopic('dvcr_live_events');
    }
    if (clubEnabled) {
      await messaging.subscribeToTopic('dvcr_notifications');
    } else {
      await messaging.unsubscribeFromTopic('dvcr_notifications');
    }
    await LiveActivityPushSync.syncLiveBannerTopic();
  } catch (e) {
    debugPrint('DVCR: FCM topics: $e');
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


