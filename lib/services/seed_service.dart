import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestion du document live/current dans Firestore
class SeedService {
  static final _db = FirebaseFirestore.instance;

  /// Démarre un live — crée live/current
  static Future<void> startLive({
    required String url,
    String team1 = '',
    String team2 = '',
    int viewers = 0,
  }) async {
    await _db.collection('live').doc('current').set({
      'url':        url,
      'live_viewers': viewers,
      'team1':      team1,
      'team2':      team2,
      'scoreHome':  0,
      'scoreAway':  0,
    });
  }

  /// Met à jour le score live
  static Future<void> updateLiveScore(int home, int away) async {
    await _db.collection('live').doc('current').update({
      'scoreHome': home,
      'scoreAway': away,
    });
  }

  /// Déclenche la notification mi-temps
  static Future<void> notifyHalftime() async {
    await _db.collection('live').doc('current').update({
      'lastEvent': 'halftime',
    });
  }

  /// Termine le live — supprime live/current
  static Future<void> clearLive() async {
    await _db.collection('live').doc('current').delete();
  }
}
