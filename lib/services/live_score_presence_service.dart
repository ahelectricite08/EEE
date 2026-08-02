import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Ping « je regarde le score » — **ouverture / retour app uniquement**.
///
/// Pas de timer périodique. Réutilise `tvLiveHeartbeat` → `live/current.viewers`.
class LiveScorePresenceService {
  LiveScorePresenceService._();
  static final instance = LiveScorePresenceService._();

  static const _deviceKey = 'live_score_presence_device_id';
  static final _endpoint = Uri.parse(
    'https://europe-west1-drapeau-vert-app.cloudfunctions.net/tvLiveHeartbeat',
  );

  final _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  bool _liveActive = false;
  bool _appResumed = true;
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    _liveSub = _db.collection('live').doc('current').snapshots().listen((snap) {
      final wasLive = _liveActive;
      _liveActive = snap.exists;
      // Nouveau live qui démarre pendant que l’app est ouverte
      if (_liveActive && !wasLive && _appResumed) {
        unawaited(_heartbeat());
      }
      if (!_liveActive && wasLive) {
        unawaited(_leave());
      }
    });
    if (_liveActive && _appResumed) {
      unawaited(_heartbeat());
    }
  }

  void setAppResumed(bool resumed) {
    _appResumed = resumed;
    if (!resumed) {
      unawaited(_leave());
      return;
    }
    // Retour sur l’app pendant un live → 1 ping
    if (_liveActive) unawaited(_heartbeat());
  }

  Future<String> _viewerId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      id =
          'd${DateTime.now().microsecondsSinceEpoch}_${Object().hashCode.abs()}';
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  Future<void> _heartbeat() async {
    if (!_liveActive || !_appResumed) return;
    try {
      final viewerId = await _viewerId();
      await http
          .post(
            _endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'viewerId': viewerId,
              'platform': 'mobile',
              'action': 'ping',
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('DVCR: live score presence ping: $e');
    }
  }

  Future<void> _leave() async {
    try {
      final viewerId = await _viewerId();
      await http
          .post(
            _endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'viewerId': viewerId,
              'platform': 'mobile',
              'action': 'leave',
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _liveSub?.cancel();
    await _leave();
    _started = false;
  }
}
