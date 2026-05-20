import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
  static bool _initialized = false;
  static void Function(String?)? _tapHandler;

  static const AndroidNotificationChannel _liveChannel =
      AndroidNotificationChannel(
        'dvcr_live',
        'DVCR Live',
        description: 'Notifications des lives et emissions DVCR',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
        'dvcr_alerts',
        'DVCR Alertes',
        description: 'Alertes générales DVCR',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _articlesChannel =
      AndroidNotificationChannel(
        'dvcr_articles',
        'DVCR Actus',
        description: 'Notifications des articles DVCR',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _liveEventsChannel =
      AndroidNotificationChannel(
        'dvcr_live_events',
        'DVCR Evenements live',
        description: 'Buts, cartons et temps forts du live',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _notificationsChannel =
      AndroidNotificationChannel(
        'dvcr_notifications',
        'DVCR Rappels',
        description: 'Rappels de match et notifications importantes',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _matchReminderChannel =
      AndroidNotificationChannel(
        'match_reminder',
        'Rappels de match',
        description: 'Notifications pour chaque match favori',
        importance: Importance.high,
      );

  static void setNotificationTapHandler(void Function(String?) handler) {
    _tapHandler = handler;
  }

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
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

    _initialized = true;
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
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
          _channelNameForId(channelId),
          channelDescription: _channelDescriptionForId(channelId),
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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

    await _plugin.zonedSchedule(
      _notificationId(matchId, mode),
      mode == MatchReminderMode.kickoff
          ? 'Coup d\'envoi imminent'
          : 'Match ${mode.label.toLowerCase()}',
      '$team1 vs $team2',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'match_reminder',
          'Rappels de match',
          channelDescription: 'Notification pour chaque match favori',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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

    switch ((message.data['type'] ?? '').toString()) {
      case 'article':
        return _articlesChannel.id;
      case 'goal':
      case 'offside':
      case 'yellow_card':
      case 'red_card':
        return _liveEventsChannel.id;
      case 'match_reminder':
        return _notificationsChannel.id;
      case 'emission':
      case 'kickoff':
        return _liveChannel.id;
      default:
        return _alertsChannel.id;
    }
  }

  static String _channelNameForId(String id) {
    switch (id) {
      case 'dvcr_live':
        return _liveChannel.name;
      case 'dvcr_articles':
        return _articlesChannel.name;
      case 'dvcr_live_events':
        return _liveEventsChannel.name;
      case 'dvcr_notifications':
        return _notificationsChannel.name;
      case 'match_reminder':
        return _matchReminderChannel.name;
      case 'dvcr_alerts':
      default:
        return _alertsChannel.name;
    }
  }

  static String _channelDescriptionForId(String id) {
    switch (id) {
      case 'dvcr_live':
        return _liveChannel.description ?? '';
      case 'dvcr_articles':
        return _articlesChannel.description ?? '';
      case 'dvcr_live_events':
        return _liveEventsChannel.description ?? '';
      case 'dvcr_notifications':
        return _notificationsChannel.description ?? '';
      case 'match_reminder':
        return _matchReminderChannel.description ?? '';
      case 'dvcr_alerts':
      default:
        return _alertsChannel.description ?? '';
    }
  }
}
