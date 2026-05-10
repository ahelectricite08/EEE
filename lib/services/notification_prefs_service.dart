import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences de notifications : clés [SharedPreferences] ↔ sous-champs
/// `users/{uid}.notificationPrefs.*` (lus par les Cloud Functions pour les envois ciblés).
abstract final class NotificationPrefsService {
  static const firestorePrefix = 'notificationPrefs';

  /// Clé Firestore → clé SharedPreferences (historique `notif_*` conservé).
  static const Map<String, String> keys = {
    'live': 'notif_live',
    'alerts': 'notif_alerts',
    'liveEvents': 'notif_live_events',
    'articles': 'notif_actus',
    'sedanRemind1h': 'notif_match_remind',
    'chatMention': 'notif_chat_mention',
    'friendRequest': 'notif_friend_request',
    'duelInvite': 'notif_duel_invite',
    'duelResult': 'notif_duel_result',
    'pronoPointsRecap': 'notif_prono_points_recap',
    'tournamentPronoPoints': 'notif_tournament_prono_points',
    // Aligné côté app sur `pronoPointsRecap` (pas de ligne dédiée dans les réglages).
    'rankingMotivation': 'notif_ranking_motivation',
  };

  static Future<void> pullFromFirestoreAndCacheLocal(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final raw = snap.data()?['notificationPrefs'];
    if (raw is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    for (final e in keys.entries) {
      final v = raw[e.key];
      if (v is bool) {
        await prefs.setBool(e.value, v);
      }
    }
  }

  /// Met à jour le doc utilisateur (merge par clé) + cache local.
  static Future<void> updateFirestoreAndLocal({
    required String uid,
    required String firestoreKey,
    required bool value,
  }) async {
    final spKey = keys[firestoreKey];
    if (spKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(spKey, value);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      firestorePrefix: {firestoreKey: value},
    }, SetOptions(merge: true));
  }

  static Future<bool> readLocal(String firestoreKey) async {
    final spKey = keys[firestoreKey];
    if (spKey == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(spKey) ?? true;
  }
}
