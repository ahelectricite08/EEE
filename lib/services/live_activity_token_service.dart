import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Enregistre le push token ActivityKit + FCM iOS pour mises à jour
/// Live Activity en arrière-plan (`apns-push-type: liveactivity`).
class LiveActivityTokenService {
  LiveActivityTokenService._();

  static const collection = 'live_activity_tokens';

  static Future<void> register({
    required String activityId,
    required String activityToken,
    String matchId = '',
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    final token = activityToken.trim();
    if (token.isEmpty || activityId.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('DVCR LA token: skip (not signed in)');
      return;
    }

    String fcmToken = '';
    try {
      fcmToken = (await FirebaseMessaging.instance.getToken())?.trim() ?? '';
    } catch (e) {
      debugPrint('DVCR LA token: FCM getToken $e');
    }
    if (fcmToken.isEmpty) {
      debugPrint('DVCR LA token: skip (no FCM token)');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).set({
        'uid': user.uid,
        'activityId': activityId,
        'activityToken': token,
        'fcmToken': fcmToken,
        'matchId': matchId.trim(),
        'platform': 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('DVCR LA token: registered for ${user.uid}');
    } catch (e) {
      debugPrint('DVCR LA token persist: $e');
    }
  }

  static Future<void> clear() async {
    if (kIsWeb || !Platform.isIOS) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).delete();
    } catch (e) {
      debugPrint('DVCR LA token clear: $e');
    }
  }
}
