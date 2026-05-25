import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Enregistre le token FCM par plateforme (ios / android) dans Firestore.
class FcmTokenService {
  FcmTokenService._();

  static const _maxIosApnsAttempts = 12;
  static const _maxTokenAttempts = 5;

  static StreamSubscription<String>? _refreshSub;

  static String get platformKey {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static bool get isIos => !kIsWeb && Platform.isIOS;

  static Future<NotificationSettings> requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    if (isIos) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> waitForIosApnsToken() async {
    if (!isIos) return;
    for (var i = 0; i < _maxIosApnsAttempts; i++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null && apns.isNotEmpty) {
        debugPrint('DVCR: APNS token ok (attempt ${i + 1})');
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 500 + i * 250));
    }
    debugPrint(
      'DVCR: APNS token unavailable after $_maxIosApnsAttempts attempts',
    );
  }

  static Future<void> syncToken() async {
    if (kIsWeb) return;

    final settings = await requestPermission();
    if (isIos &&
        settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('DVCR: iOS notifications denied — token sync skipped');
      return;
    }

    await waitForIosApnsToken();

    for (var attempt = 0; attempt < _maxTokenAttempts; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await persistToken(token);
          debugPrint(
            'DVCR: FCM token synced ($platformKey, attempt ${attempt + 1})',
          );
          return;
        }
      } catch (e) {
        debugPrint('DVCR: FCM getToken attempt ${attempt + 1}: $e');
      }
      if (attempt < _maxTokenAttempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 + attempt));
        if (isIos) await waitForIosApnsToken();
      }
    }
    debugPrint('DVCR: FCM token sync failed after $_maxTokenAttempts attempts');
  }

  static Future<void> persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = platformKey;
    final flags = <String, dynamic>{
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'fcmPlatform': key,
      'fcmTokens.$key': token,
      'fcmTokensUpdatedAt.$key': FieldValue.serverTimestamp(),
    };
    if (key == 'ios') flags['fcmHasIos'] = true;
    if (key == 'android') flags['fcmHasAndroid'] = true;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(flags, SetOptions(merge: true));
  }

  static Future<void> startListening() async {
    await _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(persistToken(token));
    });
  }
}
