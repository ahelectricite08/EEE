import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'match_controller.dart';

/// Déclenche une synchro FFF à l’ouverture de l’onglet Calendrier (throttle app + serveur).
class FffSyncService {
  FffSyncService._();
  static final instance = FffSyncService._();

  static const _clientCooldown = Duration(minutes: 30);

  DateTime? _lastTriggeredAt;
  Future<void>? _inFlight;

  /// Sync FFF (si connecté) puis rechargement des matchs en cache local.
  Future<void> refreshOnCalendarOpen() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final run = _refreshOnCalendarOpenInternal();
    _inFlight = run.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _refreshOnCalendarOpenInternal() async {
    final now = DateTime.now();
    if (_lastTriggeredAt != null &&
        now.difference(_lastTriggeredAt!) < _clientCooldown) {
      await MatchController.instance.forceRefresh();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await MatchController.instance.forceRefresh();
      return;
    }

    _lastTriggeredAt = now;
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('syncFffDataOnCalendarOpen')
          .call();
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      final skipped = data['skipped'] == true;
      final reason = data['reason']?.toString();
      if (kDebugMode && skipped && reason != null && reason != 'throttled') {
        debugPrint('[FffSync] skipped: $reason');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[FffSync] ${e.code}: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FffSync] $e');
    }

    await MatchController.instance.forceRefresh();
  }
}
