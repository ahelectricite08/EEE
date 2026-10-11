import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'fff_device_score_sync.dart';
import 'match_controller.dart';
import 'user_service.dart';
import '../models/user_role.dart';

/// Synchro FFF (throttle app + serveur).
///
/// GCP se fait souvent 403 par le WAF FFF. Le cron ne suffit pas :
/// tout staff (admin / CM / stat) qui ouvre Accueil ou Calendrier
/// tire aussi l’API depuis l’appareil.
class FffSyncService {
  FffSyncService._();
  static final instance = FffSyncService._();

  static const _clientCooldown = Duration(minutes: 15);

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
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
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

    // Staff : l’API FFF depuis l’appareil (JSON lourd). Après le 1er paint,
    // pas pendant l’ouverture d’Accueil / Calendrier.
    try {
      final roles = await UserService.getCurrentRoles();
      final isAdmin = roles.contains(UserRole.admin);
      final canWriteScores = isAdmin ||
          roles.contains(UserRole.communityManager) ||
          roles.contains(UserRole.statisticien);
      if (canWriteScores) {
        await Future<void>.delayed(const Duration(seconds: 5));
        final n = await FffDeviceScoreSync.instance.pullAndWriteAll(
          rankings: true,
        );
        if (kDebugMode && (n.scores > 0 || n.rankingRows > 0)) {
          debugPrint(
            '[FffSync] appareil scores=${n.scores} ranking=${n.rankingRows}',
          );
        }
        await MatchController.instance.forceRefresh();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FffSync] device scores: $e');
    }
  }
}
