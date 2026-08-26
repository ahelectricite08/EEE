import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/club_branding.dart';
import '../constants/notification_channels.dart';

enum MatchReminderMode {
  dayBefore,
  hourBefore,
  kickoff;

  String get key {
    switch (this) {
      case MatchReminderMode.dayBefore:
        return '24h';
      case MatchReminderMode.hourBefore:
        return '1h';
      case MatchReminderMode.kickoff:
        return 'kickoff';
    }
  }

  String get label {
    switch (this) {
      case MatchReminderMode.dayBefore:
        return '24h avant';
      case MatchReminderMode.hourBefore:
        return '1h avant';
      case MatchReminderMode.kickoff:
        return 'Au coup d\'envoi';
    }
  }

  Duration get offset {
    switch (this) {
      case MatchReminderMode.dayBefore:
        return const Duration(hours: 24);
      case MatchReminderMode.hourBefore:
        return const Duration(hours: 1);
      case MatchReminderMode.kickoff:
        return Duration.zero;
    }
  }

  static MatchReminderMode fromKey(String? value) {
    switch (value) {
      case '24h':
        return MatchReminderMode.dayBefore;
      case 'kickoff':
        return MatchReminderMode.kickoff;
      case '1h':
      default:
        return MatchReminderMode.hourBefore;
    }
  }
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static bool _initialized = false;
  static void Function(String?)? _tapHandler;

  static const AndroidNotificationChannel _liveChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.live,
        'Live ${ClubBranding.shortName}',
        description:
            'Match en direct du ${ClubBranding.displayName} (coup d\'envoi, mi-temps, fin)',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.alerts,
        'DVCR Alertes',
        description: 'Alertes générales DVCR',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _articlesChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.articles,
        'DVCR Actus',
        description: 'Notifications des articles DVCR',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _liveEventsChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.liveEvents,
        'Match ${ClubBranding.shortName} — temps forts',
        description:
            'Buts, cartons et faits de jeu du ${ClubBranding.displayName}',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _notificationsChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.reminders,
        'DVCR Rappels',
        description: 'Rappels de match et notifications importantes',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _matchReminderChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.matchReminder,
        'Rappels de match',
        description: 'Notifications pour chaque match favori',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _liveStickyScoreChannel =
      AndroidNotificationChannel(
        DvcrNotificationChannels.liveStickyScore,
        'Score live (écran de verrouillage)',
        description:
            'Score affiché en permanence sur l’écran de verrouillage pendant le direct',
        importance: Importance.high,
      );

  static void setNotificationTapHandler(void Function(String?) handler) {
    _tapHandler = handler;
  }

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: DvcrNotificationChannels.darwinCategories,
    );
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        _tapHandler?.call(response.payload);
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(_liveChannel);
    await androidPlugin?.createNotificationChannel(_alertsChannel);
    await androidPlugin?.createNotificationChannel(_articlesChannel);
    await androidPlugin?.createNotificationChannel(_liveEventsChannel);
    await androidPlugin?.createNotificationChannel(_notificationsChannel);
    await androidPlugin?.createNotificationChannel(_matchReminderChannel);
    await androidPlugin?.createNotificationChannel(_liveStickyScoreChannel);

    _initialized = true;
  }

  /// FCM live = sync silencieux ; push visible si notifyVisible ou sans LA.
  static bool shouldDisplayBanner(RemoteMessage message) {
    final data = message.data;
    if (data['syncLiveActivity'] == '1' && data['notifyVisible'] != '1') {
      return false;
    }
    if (data['endLive'] == '1' || data['type'] == 'live_end') {
      return data['notifyVisible'] == '1' || message.notification != null;
    }
    if (data['type'] == 'live_sync') return false;
    return message.notification != null;
  }

  /// Push locale quand pas de Live Activity active (FCM silencieux + alertTitle).
  /// Push locale unique (même id) — un but ne doit pas empiler 3 notifs.
  static const liveEventNotificationId = 8802;

  static Future<void> showLiveEvent({
    required String title,
    required String body,
    required String type,
  }) async {
    await init();
    final channelId = DvcrNotificationChannels.fromMessageType(
      type.isEmpty ? 'live' : type,
    );

    await _plugin.show(
      liveEventNotificationId,
      title,
      body.isEmpty ? title : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          DvcrNotificationChannels.displayName(channelId),
          channelDescription: DvcrNotificationChannels.description(channelId),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
          onlyAlertOnce: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: channelId,
          categoryIdentifier: channelId,
        ),
      ),
      payload: jsonEncode({'type': type}),
    );
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    if (!shouldDisplayBanner(message)) return;
    await init();

    final remoteNotification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title =
        remoteNotification?.title ?? data['title']?.toString() ?? 'DVCR';
    final body = remoteNotification?.body ?? data['body']?.toString() ?? '';
    final channelId = _channelIdForMessage(message);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          DvcrNotificationChannels.displayName(channelId),
          channelDescription: DvcrNotificationChannels.description(channelId),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: channelId,
          categoryIdentifier: channelId,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> scheduleMatchReminder({
    required String matchId,
    required String team1,
    required String team2,
    required DateTime matchDate,
    MatchReminderMode mode = MatchReminderMode.hourBefore,
  }) async {
    await init();

    final reminderTime = matchDate.subtract(mode.offset);
    if (reminderTime.isBefore(DateTime.now())) return;

    const channelId = DvcrNotificationChannels.matchReminder;

    await _plugin.zonedSchedule(
      _notificationId(matchId, mode),
      mode == MatchReminderMode.kickoff
          ? 'Coup d\'envoi imminent'
          : 'Match ${mode.label.toLowerCase()}',
      '$team1 vs $team2',
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          DvcrNotificationChannels.displayName(channelId),
          channelDescription: DvcrNotificationChannels.description(channelId),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: channelId,
          categoryIdentifier: channelId,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'match_reminder',
        'matchId': matchId,
      }),
    );
  }

  static Future<void> cancelMatchReminder(String matchId) async {
    await init();
    for (final mode in MatchReminderMode.values) {
      await _plugin.cancel(_notificationId(matchId, mode));
    }
  }

  static int _notificationId(String matchId, MatchReminderMode mode) {
    return '${matchId}_${mode.key}'.hashCode.abs() % 100000;
  }

  static String _channelIdForMessage(RemoteMessage message) {
    final androidChannelId = message.notification?.android?.channelId;
    if (androidChannelId != null && androidChannelId.isNotEmpty) {
      return androidChannelId;
    }

    return DvcrNotificationChannels.fromMessageType(
      message.data['type']?.toString(),
    );
  }
}
