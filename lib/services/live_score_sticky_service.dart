import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/club_branding.dart';
import '../constants/notification_channels.dart';
import 'live_banner_format.dart';
import 'live_state_service.dart';
import 'notification_service.dart';

/// Repli si Live Activity / RemoteViews indisponibles.
class LiveScoreStickyService {
  LiveScoreStickyService._();

  static const _notificationId = 88001;

  static Future<void> showFallback(LiveHubState hub) async {
    if (kIsWeb) return;
    await NotificationService.init();
    final t1 = _shortTeam(hub.matchTeam1);
    final t2 = _shortTeam(hub.matchTeam2);
    final minute = LiveBannerFormat.minuteLabel(hub);
    final lastEvent = LiveBannerFormat.lastEventLine(hub);
    final title = '$minute · ${hub.scoreHome} - ${hub.scoreAway} · ${ClubBranding.shortName}';
    final body = lastEvent.isEmpty
        ? '$t1 — $t2'
        : '$t1 — $t2\n$lastEvent';

    await NotificationService.plugin.show(
      _notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          DvcrNotificationChannels.liveStickyScore,
          'Score live (écran de verrouillage)',
          channelDescription:
              'Score du match affiché en permanence pendant le direct',
          importance: Importance.defaultImportance,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          icon: '@drawable/ic_launcher_foreground',
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: minute,
          ),
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
          interruptionLevel: InterruptionLevel.passive,
          threadIdentifier: DvcrNotificationChannels.liveStickyScore,
          categoryIdentifier: DvcrNotificationChannels.liveStickyScore,
        ),
      ),
      payload: 'live_score_sticky',
    );
  }

  static Future<void> clearFallback() async {
    if (kIsWeb) return;
    await NotificationService.plugin.cancel(_notificationId);
  }

  static String _shortTeam(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 14) return t;
    return '${t.substring(0, 12)}…';
  }

}
