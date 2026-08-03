import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Enregistre le push token ActivityKit + FCM iOS pour mises à jour
/// Live Activity en arrière-plan (`apns-push-type: liveactivity`).
///
/// Cache local + retry : le token ActivityKit arrive souvent après createActivity,
/// et le FCM / auth peuvent être absents un instant — on rejoue dès qu'ils sont prêts.
class LiveActivityTokenService {
  LiveActivityTokenService._();

  static const collection = 'live_activity_tokens';

  static String? _pendingActivityId;
  static String? _pendingActivityToken;
  static String? _pendingMatchId;
  static StreamSubscription<String>? _fcmRefreshSub;
  static StreamSubscription<User?>? _authSub;
  static bool _flushInFlight = false;

  static void ensureListeners() {
    if (kIsWeb || !Platform.isIOS) return;
    _fcmRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(flushPending());
    });
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(flushPending());
    });
  }

  static Future<void> register({
    required String activityId,
    required String activityToken,
    String matchId = '',
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    final token = activityToken.trim();
    if (token.isEmpty || activityId.trim().isEmpty) return;

    ensureListeners();
    _pendingActivityId = activityId.trim();
    _pendingActivityToken = token;
    _pendingMatchId = matchId.trim();
    await flushPending();
  }

  /// Rejoue l'écriture Firestore si un token ActivityKit est en attente.
  static Future<void> flushPending() async {
    if (kIsWeb || !Platform.isIOS || _flushInFlight) return;
    final activityId = _pendingActivityId;
    final token = _pendingActivityToken;
    if (activityId == null ||
        activityId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return;
    }

    _flushInFlight = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('DVCR LA token: pending (not signed in)');
        return;
      }

      String fcmToken = '';
      for (var i = 0; i < 4; i++) {
        try {
          fcmToken =
              (await FirebaseMessaging.instance.getToken())?.trim() ?? '';
        } catch (e) {
          debugPrint('DVCR LA token: FCM getToken $e');
        }
        if (fcmToken.isNotEmpty) break;
        await Future<void>.delayed(Duration(milliseconds: 400 + i * 350));
      }
      if (fcmToken.isEmpty) {
        debugPrint('DVCR LA token: pending (no FCM token)');
        return;
      }

      await FirebaseFirestore.instance.collection(collection).doc(user.uid).set({
        'uid': user.uid,
        'activityId': activityId,
        'activityToken': token,
        'fcmToken': fcmToken,
        'matchId': _pendingMatchId ?? '',
        'platform': 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('DVCR LA token: registered for ${user.uid}');
    } catch (e) {
      debugPrint('DVCR LA token persist: $e');
    } finally {
      _flushInFlight = false;
    }
  }

  static Future<void> clear() async {
    if (kIsWeb || !Platform.isIOS) return;
    _pendingActivityId = null;
    _pendingActivityToken = null;
    _pendingMatchId = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).delete();
    } catch (e) {
      debugPrint('DVCR LA token clear: $e');
    }
  }
}
