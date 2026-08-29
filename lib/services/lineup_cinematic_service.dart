import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lineup_cinematic_plan.dart';
import '../models/lineup_prediction.dart';
import '../models/match_lineup.dart';
import '../models/sedan_squad.dart';
import '../navigation/lineup_cinematic_rollout.dart';
import '../screens/matches/matches_helpers.dart';
import 'feature_flags_service.dart';
import 'live_team_logo_resolver.dart';
import 'sedan_squad_service.dart';

/// Charge XI + banc déjà stockés (live / fiche match) et gère le « déjà vu ».
class LineupCinematicService {
  LineupCinematicService._();
  static final instance = LineupCinematicService._();

  static const _seenPrefix = 'lineup_cinematic_seen_';
  static const _testSeenPrefix = 'lineup_cinematic_test_';
  static const testDocId = 'lineup_cinematic_test';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get testRef =>
      _db.collection('app_config').doc(testDocId);

  static bool _isSedanClub(String team) {
    final u = team.toUpperCase();
    return u.contains('SEDAN') || u.contains('CSSA');
  }

  static DateTime? parseSavedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  Future<bool> hasPlayed(String matchId, DateTime savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          '$_seenPrefix${LineupCinematicWindow.playKey(matchId, savedAt)}',
        ) ==
        true;
  }

  Future<void> markPlayed(String matchId, DateTime savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      '$_seenPrefix${LineupCinematicWindow.playKey(matchId, savedAt)}',
      true,
    );
  }

  bool flagAllowsAutoPlay() =>
      FeatureFlagsService.isEnabled(
        FeatureFlagsService.notifier.value,
        LineupCinematicRollout.flagKey,
      );

  LineupCinematicShow? showFromDoc({
    required Map<String, dynamic>? data,
    required String matchId,
    required String team1,
    required String team2,
    SedanSquad squad = SedanSquad.empty,
    bool force = false,
  }) {
    if (data == null) return null;
    final lineups = MatchLineups.fromDoc(data);
    final sedanIsHome = _isSedanClub(team1);
    final sedanIsAway = _isSedanClub(team2);
    if (!sedanIsHome && !sedanIsAway) return null;

    final sedanSide = sedanIsHome ? lineups.home : lineups.away;
    final oppSide = sedanIsHome ? lineups.away : lineups.home;
    final sedanStarters =
        sedanSide.starters.where((e) => e.trim().isNotEmpty).length;
    if (sedanStarters < LineupPrediction.requiredPlayers) return null;

    final sedanPlan = LineupCinematicTeamPlan.fromSide(
      side: sedanSide,
      teamName: sedanIsHome ? team1 : team2,
      isSedan: true,
      sedanSquad: squad,
    );
    LineupCinematicTeamPlan? oppPlan;
    final oppStarters =
        oppSide.starters.where((e) => e.trim().isNotEmpty).toList();
    if (oppStarters.isNotEmpty) {
      oppPlan = LineupCinematicTeamPlan.fromSide(
        side: oppSide,
        teamName: sedanIsHome ? team2 : team1,
        isSedan: false,
      );
    }

    final crests = LineupCinematicCrests.fromHomeAway(
      sedanIsHome: sedanIsHome,
      logo1: (data['logo1'] ?? '').toString(),
      logo2: (data['logo2'] ?? '').toString(),
    );

    return LineupCinematicShow(
      matchId: matchId,
      savedAt: parseSavedAt(data['lineupsUpdatedAt']),
      sedan: sedanPlan,
      opponent: oppPlan,
      force: force,
      sedanLogoUrl: crests.sedan,
      opponentLogoUrl: crests.opponent,
    );
  }

  LineupCinematicShow? showFromLiveOrMatch({
    required Map<String, dynamic>? live,
    required Map<String, dynamic>? matchDoc,
    required String matchId,
    required String team1,
    required String team2,
    SedanSquad squad = SedanSquad.empty,
    bool force = false,
  }) {
    final merged = MatchLineups.mergeDocs(live, matchDoc);
    final patch = <String, dynamic>{
      'lineupHome': merged.home.toMap(),
      'lineupAway': merged.away.toMap(),
      'lineupsUpdatedAt':
          live?['lineupsUpdatedAt'] ?? matchDoc?['lineupsUpdatedAt'],
      'logo1': live?['logo1'] ?? matchDoc?['logo1'] ?? '',
      'logo2': live?['logo2'] ?? matchDoc?['logo2'] ?? '',
    };
    return showFromDoc(
      data: patch,
      matchId: matchId,
      team1: team1,
      team2: team2,
      squad: squad,
      force: force,
    );
  }

  /// Écussons réels : match (`logo1`/`logo2`), puis live resolver, puis classement.
  Future<LineupCinematicShow> resolveCrests(
    LineupCinematicShow show, {
    Map<String, dynamic>? live,
    Map<String, dynamic>? matchDoc,
  }) async {
    var sedanUrl = show.sedanLogoUrl.trim();
    var oppUrl = show.opponentLogoUrl.trim();
    if (sedanUrl.isNotEmpty && oppUrl.isNotEmpty) {
      return show.copyWith(sedanLogoUrl: sedanUrl, opponentLogoUrl: oppUrl);
    }

    final testCue = show.force || show.matchId == 'cinematic_test';
    if (!testCue) {
      final t1 = (live?['team1'] ?? matchDoc?['team1'] ?? '').toString();
      final t2 = (live?['team2'] ?? matchDoc?['team2'] ?? '').toString();
      final sedanIsHome = _isSedanClub(t1)
          ? true
          : _isSedanClub(t2)
              ? false
              : true;
      var logo1 = (live?['logo1'] ?? matchDoc?['logo1'] ?? '').toString();
      var logo2 = (live?['logo2'] ?? matchDoc?['logo2'] ?? '').toString();

      try {
        final resolved = await LiveTeamLogoResolver.resolve(
          team1: t1,
          team2: t2,
          logo1: logo1,
          logo2: logo2,
          matchId: show.matchId,
        );
        logo1 = resolved.logo1;
        logo2 = resolved.logo2;
      } catch (_) {}

      final mapped = LineupCinematicCrests.fromHomeAway(
        sedanIsHome: sedanIsHome,
        logo1: logo1,
        logo2: logo2,
      );
      if (sedanUrl.isEmpty) sedanUrl = mapped.sedan;
      if (oppUrl.isEmpty) oppUrl = mapped.opponent;
    }

    if (sedanUrl.isEmpty || oppUrl.isEmpty) {
      try {
        final byTeam = await _crestIndexFromRankingAndMatches();
        if (sedanUrl.isEmpty) {
          sedanUrl = _pickIndexedCrest(byTeam, show.sedan.teamName) ?? '';
        }
        if (oppUrl.isEmpty && show.opponent != null) {
          oppUrl = _pickIndexedCrest(byTeam, show.opponent!.teamName) ?? '';
        }
      } catch (_) {}
    }

    return show.copyWith(sedanLogoUrl: sedanUrl, opponentLogoUrl: oppUrl);
  }

  Future<Map<String, String>> _crestIndexFromRankingAndMatches() async {
    final byExact = <String, String>{};
    final byNorm = <String, String>{};

    void put(String team, String? logo) {
      final t = team.trim();
      final u = logo?.trim() ?? '';
      if (t.isEmpty || u.isEmpty) return;
      byExact.putIfAbsent(t, () => u);
      byNorm.putIfAbsent(normalizeTeamLabel(t), () => u);
    }

    try {
      final rank = await _db.collection('ranking').get();
      for (final doc in rank.docs) {
        final d = doc.data();
        put((d['team'] as String?) ?? '', d['logo'] as String?);
      }
    } catch (_) {}

    try {
      final snap = await _db
          .collection('matches')
          .orderBy('date', descending: true)
          .limit(160)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        put((d['team1'] as String?) ?? '', d['logo1'] as String?);
        put((d['team2'] as String?) ?? '', d['logo2'] as String?);
      }
    } catch (_) {}

    return {
      for (final e in byNorm.entries) e.key: e.value,
      for (final e in byExact.entries) e.key: e.value,
    };
  }

  String? _pickIndexedCrest(Map<String, String> index, String team) {
    final t = team.trim();
    if (t.isEmpty) return null;
    final direct = index[t] ?? index[normalizeTeamLabel(t)];
    if (direct != null && direct.isNotEmpty) return direct;
    for (final e in index.entries) {
      if (teamMatchesPreference(t, e.key) || teamMatchesPreference(e.key, t)) {
        return e.value;
      }
    }
    return null;
  }

  /// TEST admin : toujours un XI aléatoire, pas la dernière compo live.
  Future<LineupCinematicShow> loadLatestForTest() async {
    SedanSquad squad = SedanSquad.empty;
    try {
      squad = await SedanSquadService.get();
    } catch (_) {}
    final show = LineupCinematicShow.randomTest(squad: squad);
    return resolveCrests(show);
  }

  /// Ping admin TEST : l’app mobile joue un XI aléatoire tout de suite.
  /// Pas de switch saison, pas de live requis.
  Future<void> requestAdminTestCue() async {
    await testRef.set({
      'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
      'force': true,
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  static String? testNonce(Map<String, dynamic>? data) {
    final n = (data?['nonce'] ?? '').toString().trim();
    return n.isEmpty ? null : n;
  }

  static bool isForceTest(Map<String, dynamic>? data) {
    return data?['force'] == true && testNonce(data) != null;
  }

  Future<bool> hasPlayedTest(String nonce) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_testSeenPrefix$nonce') == true;
  }

  Future<void> markTestPlayed(String nonce) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_testSeenPrefix$nonce', true);
  }

  bool shouldAutoPlay({
    required LineupCinematicShow show,
    required bool alreadyPlayed,
    required bool liveRunning,
  }) {
    if (show.force) return true;
    return LineupCinematicGate.shouldPlay(
      flagOn: flagAllowsAutoPlay(),
      liveRunning: liveRunning,
      alreadyPlayed: alreadyPlayed,
      lineupAnnouncedAt: show.savedAt,
    );
  }
}
