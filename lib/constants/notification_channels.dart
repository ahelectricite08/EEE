import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'club_branding.dart';

/// Identifiants alignés Android (`NotificationChannel`) et iOS (`category` + `thread-id`).
abstract final class DvcrNotificationChannels {
  static const live = 'dvcr_live';
  static const alerts = 'dvcr_alerts';
  static const articles = 'dvcr_articles';
  static const liveEvents = 'dvcr_live_events';
  static const reminders = 'dvcr_notifications';
  static const matchReminder = 'match_reminder';
  /// Notification persistante : score sur écran de verrouillage (Android / iOS).
  static const liveStickyScore = 'dvcr_live_sticky_score';

  static const all = [
    live,
    alerts,
    articles,
    liveEvents,
    reminders,
    matchReminder,
    liveStickyScore,
  ];

  static String displayName(String id) {
    switch (id) {
      case live:
        return 'Live ${ClubBranding.shortName}';
      case articles:
        return 'DVCR Actus';
      case liveEvents:
        return 'Match ${ClubBranding.shortName} — temps forts';
      case reminders:
        return 'DVCR Rappels';
      case matchReminder:
        return 'Rappels de match';
      case alerts:
      default:
        return 'DVCR Alertes';
    }
  }

  static String description(String id) {
    switch (id) {
      case live:
        return 'Match en direct et émission DVCR (coup d\'envoi, mi-temps, fin)';
      case articles:
        return 'Nouvelles actus et contenus DVCR';
      case liveEvents:
        return 'Buts, cartons et faits de jeu du ${ClubBranding.displayName}';
      case reminders:
        return 'Rappels de match et notifications importantes';
      case matchReminder:
        return 'Rappels personnels pour tes matchs favoris';
      case liveStickyScore:
        return 'Score du match en direct sur l’écran de verrouillage';
      case alerts:
      default:
        return 'Alertes générales DVCR (chat, duels, amis, prono)';
    }
  }

  /// Regroupement iOS (Réglages → Notifications → DVCR affiche des fils séparés).
  static List<DarwinNotificationCategory> get darwinCategories {
    return all
        .map(
          (id) => DarwinNotificationCategory(
            id,
            actions: const <DarwinNotificationAction>[],
          ),
        )
        .toList();
  }

  static String fromMessageType(String? type) {
    switch (type) {
      case 'article':
        return articles;
      case 'goal':
      case 'offside':
      case 'goal_cancelled':
      case 'goal_disallowed':
      case 'yellow_card':
      case 'red_card':
        return liveEvents;
      case 'match_reminder':
        return reminders;
      case 'emission':
      case 'kickoff':
        return live;
      default:
        return alerts;
    }
  }
}
