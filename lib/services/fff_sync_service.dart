import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import 'fff_device_score_sync.dart';
import 'match_controller.dart';
import 'user_service.dart';

/// Pipeline FFF : classement R1/R2, calendrier, résultats, pronos.
///
/// GCP se fait souvent 403 par le WAF FFF. Donc **pas de GitHub / pas de cron** :
/// - **Auto** : tu allumes l’app sur un compte **admin** → 1× / ~8 h
/// - **Forcer** : bouton « Synchroniser classement »
///
/// Les supporters ne tapent pas l’API FFF.
class FffSyncService {
  FffSyncService._();
  static final instance = FffSyncService._();

  static const dailyAutoEvery = Duration(hours: 8);
  static const dailyAutoClaimTtl = Duration(minutes: 25);
  static const _rankingCooldown = Duration(minutes: 2);
  static const _dailyAutoDoc = 'fff_daily_auto';

  DateTime? _lastRankingAt;
  Future<void>? _inFlight;
  Future<int>? _rankingInFlight;
  Future<FffAdminSyncReport>? _pipelineInFlight;
  StreamSubscription<User?>? _authBootSub;
  bool _bootHooked = false;

  /// Au démarrage : dès qu’un admin est connecté, sync du jour (fond).
  void ensureAdminAppOpenSync() {
    if (_bootHooked) return;
    _bootHooked = true;
    _authBootSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(runDailyAutoIfDue());
    });
  }

  /// Ouverture calendrier / accueil : refresh local + auto du jour si due.
  Future<void> refreshOnCalendarOpen({bool forceRankings = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;

    final run = _refreshOnCalendarOpenInternal(forceRankings: forceRankings);
    _inFlight = run.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  /// Classements R1/R2 depuis l’appareil **admin**.
  Future<int> refreshRankingsNow({bool force = false}) async {
    if (!force) {
      final pending = _rankingInFlight;
      if (pending != null) return pending;
    } else {
      final pending = _rankingInFlight;
      if (pending != null) await pending;
    }

    final run = _deviceRankingIfStaff(force: force);
    _rankingInFlight = run.whenComplete(() => _rankingInFlight = null);
    return _rankingInFlight!;
  }

  /// Bouton admin **Synchroniser classement** : force scores, calendrier, pronos, tableau.
  Future<FffAdminSyncReport> syncRankingScoresAndPronos({
    bool force = true,
    String source = 'admin_button',
  }) async {
    final pending = _pipelineInFlight;
    if (pending != null) {
      if (!force) return pending;
      await pending;
    }

    final run = _syncRankingScoresAndPronosInternal(source: source);
    _pipelineInFlight = run.whenComplete(() => _pipelineInFlight = null);
    return _pipelineInFlight!;
  }

  /// 1× / ~8 h au allumage, compte admin seulement.
  Future<FffAdminSyncReport?> runDailyAutoIfDue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final roles = await UserService.getCurrentRoles();
    if (!roles.contains(UserRole.admin)) return null;

    final claimed = await _claimDailyAuto();
    if (!claimed) return null;
    try {
      final report = await syncRankingScoresAndPronos(
        force: false,
        source: 'admin_phone',
      );
      await _markDailyAutoDone('admin_phone');
      return report;
    } catch (e) {
      debugPrint('[FffSync] daily auto: $e');
      await _clearDailyAutoClaim();
      return null;
    }
  }

  Future<FffAdminSyncReport> _syncRankingScoresAndPronosInternal({
    required String source,
  }) async {
    // Classement d’abord (14 lignes) : les 182 matchs paginés ne doivent
    // pas bloquer le tableau si le téléphone coupe au milieu.
    var rankingWrites = 0;
    try {
      rankingWrites = await refreshRankingsNow(force: true);
    } catch (e) {
      debugPrint('[FffSync] ranking: $e');
    }

    var scores = 0;
    var pronosScored = 0;
    try {
      scores = await FffDeviceScoreSync.instance.pullAndWriteScores();
    } catch (e) {
      debugPrint('[FffSync] scores: $e');
    }

    final pronoFuture = _scorePendingPronos();
    final refreshFuture = MatchController.instance.forceRefresh();
    try {
      pronosScored = await pronoFuture;
    } catch (e) {
      debugPrint('[FffSync] pronos: $e');
    }
    try {
      await refreshFuture;
    } catch (e) {
      debugPrint('[FffSync] match refresh: $e');
    }

    if (source == 'admin_button') {
      await _markDailyAutoDone(source);
    }

    final ranking = FffDeviceScoreSync.instance.lastRankingReport;
    return FffAdminSyncReport(
      scores: scores,
      rankingWrites: rankingWrites,
      journee: ranking?.journee ?? 0,
      reason: ranking?.reason ?? '',
      pronosScored: pronosScored,
    );
  }

  Future<int> _scorePendingPronos() async {
    Future<int> call(String region) async {
      final fn = FirebaseFunctions.instanceFor(region: region).httpsCallable(
        'scoreMatchPronos',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final res = await fn.call();
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      final n = data['scored'];
      return n is num ? n.round() : 0;
    }

    try {
      return await call('us-central1');
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        try {
          return await call('europe-west1');
        } catch (e2) {
          debugPrint('[FffSync] pronos europe-west1: $e2');
          return 0;
        }
      }
      debugPrint('[FffSync] pronos: ${e.code} ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('[FffSync] pronos: $e');
      return 0;
    }
  }

  Future<void> _refreshOnCalendarOpenInternal({
    required bool forceRankings,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await MatchController.instance.forceRefresh();
      return;
    }

    final roles = await UserService.getCurrentRoles();
    if (roles.contains(UserRole.admin)) {
      if (forceRankings) {
        await syncRankingScoresAndPronos(source: 'admin_button');
      } else {
        await runDailyAutoIfDue();
      }
    }

    await MatchController.instance.forceRefresh();
  }

  Future<int> _deviceRankingIfStaff({required bool force}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final roles = await UserService.getCurrentRoles();
      if (!roles.contains(UserRole.admin)) return 0;

      final now = DateTime.now();
      if (!force &&
          _lastRankingAt != null &&
          now.difference(_lastRankingAt!) < _rankingCooldown) {
        return 0;
      }
      _lastRankingAt = now;
      final n = await FffDeviceScoreSync.instance.pullAndWriteRankings(
        allowLocalWrite: true,
        force: force,
      );
      if (kDebugMode && n > 0) {
        debugPrint('[FffSync] appareil ranking=$n');
      }
      return n;
    } catch (e) {
      if (kDebugMode) debugPrint('[FffSync] device ranking: $e');
      _lastRankingAt = null;
      return 0;
    }
  }

  DocumentReference<Map<String, dynamic>> get _dailyAutoRef =>
      FirebaseFirestore.instance.collection('app_config').doc(_dailyAutoDoc);

  Future<bool> _claimDailyAuto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      return await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_dailyAutoRef);
        final data = snap.data() ?? {};
        final now = DateTime.now();
        final last = (data['doneAt'] as Timestamp?)?.toDate();
        final claim = (data['claimAt'] as Timestamp?)?.toDate();
        if (!fffDailyAutoIsDue(last, now, claimAt: claim)) return false;
        tx.set(
          _dailyAutoRef,
          {
            'claimAt': FieldValue.serverTimestamp(),
            'claimBy': user.uid,
          },
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (e) {
      debugPrint('[FffSync] daily claim: $e');
      return false;
    }
  }

  Future<void> _markDailyAutoDone(String source) async {
    try {
      await _dailyAutoRef.set(
        {
          'doneAt': FieldValue.serverTimestamp(),
          'source': source,
          'claimAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FffSync] daily stamp: $e');
    }
  }

  Future<void> _clearDailyAutoClaim() async {
    try {
      await _dailyAutoRef.set(
        {'claimAt': FieldValue.delete()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FffSync] daily claim clear: $e');
    }
  }
}

class FffAdminSyncReport {
  final int scores;
  final int rankingWrites;
  final int journee;
  final String reason;
  final int pronosScored;

  const FffAdminSyncReport({
    this.scores = 0,
    this.rankingWrites = 0,
    this.journee = 0,
    this.reason = '',
    this.pronosScored = 0,
  });
}

/// True si on doit relancer la pipeline FFF (1er allumage admin du jour).
@visibleForTesting
bool fffDailyAutoIsDue(
  DateTime? lastDone,
  DateTime now, {
  DateTime? claimAt,
  Duration every = FffSyncService.dailyAutoEvery,
  Duration claimTtl = FffSyncService.dailyAutoClaimTtl,
}) {
  if (claimAt != null && now.difference(claimAt) < claimTtl) return false;
  if (lastDone == null) return true;
  return now.difference(lastDone) >= every;
}

@visibleForTesting
String fffAdminSyncSnackMessage(FffAdminSyncReport r) {
  final bits = <String>[];
  if (r.scores > 0) {
    bits.add('${r.scores} score${r.scores > 1 ? 's' : ''} R1/R2');
  }
  if (r.reason == 'matches' && r.rankingWrites > 0) {
    bits.add(
      r.journee > 0
          ? 'classement recalculé (J${r.journee})'
          : 'classement recalculé',
    );
  } else if (r.rankingWrites > 0) {
    bits.add(
      r.journee > 0 ? 'classement FFF J${r.journee}' : 'classement sync',
    );
  }
  if (r.pronosScored > 0) {
    bits.add(
      '${r.pronosScored} match${r.pronosScored > 1 ? 's' : ''} prono',
    );
  }
  if (bits.isNotEmpty) return bits.join(' · ');
  if (r.reason == 'incomplete') {
    return 'La FFF n’a pas encore publié le classement complet de la journée.';
  }
  if (r.journee > 0) {
    return 'Rien de nouveau (J${r.journee}). Scores et pronos déjà à jour, ou pas encore sur l’API FFF.';
  }
  return 'Pas de nouveau score, classement ou prono pour l’instant.';
}
