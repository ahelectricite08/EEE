import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/benevole_posts.dart';
import '../models/match_stats_schema.dart';
import 'match_rating_service.dart';

/// Visuel score + buteurs (1ère uniquement) — même fenêtre 48 h que la note.
class MatchSheetShareService {
  MatchSheetShareService._();
  static final instance = MatchSheetShareService._();

  static const _seenPrefix = 'match_sheet_share_seen_';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool isCssaTeamLabel(String name) {
    final u = name.toUpperCase();
    return u.contains('SEDAN') || u.contains('CSSA');
  }

  static int eventMinute(Map<String, dynamic> e) {
    final v = e['minute'];
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static bool eventIsCssaSide(
    Map<String, dynamic> event,
    String team1,
    String team2,
  ) {
    final teamRaw =
        (event['team'] ?? event['teamName'] ?? '').toString().trim();
    if (teamRaw.isNotEmpty) {
      if (isCssaTeamLabel(teamRaw)) return true;
      final u = teamRaw.toUpperCase();
      if (isCssaTeamLabel(team1) && u == team1.trim().toUpperCase()) {
        return true;
      }
      if (isCssaTeamLabel(team2) && u == team2.trim().toUpperCase()) {
        return true;
      }
    }
    final home = MatchStatsSchema.isHomeTeamEvent(event, team1, team2);
    if (isCssaTeamLabel(team1) && home) return true;
    if (isCssaTeamLabel(team2) && !home) return true;
    return false;
  }

  /// 1ère (R1 / Coupe). Pas R2, réserve, Flammes.
  static bool isPremiereLiveMatch(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    final type = BenevolePosts.normalizeType(
      (data['benevoleType'] ?? '').toString(),
    );
    if (type == BenevolePosts.typeReserve ||
        type == BenevolePosts.typeFlammes) {
      return false;
    }
    final competition = (data['competition'] ?? '').toString();
    final inferred = BenevolePosts.inferTypeFromCompetition(competition);
    if (inferred == BenevolePosts.typeReserve ||
        inferred == BenevolePosts.typeFlammes) {
      return false;
    }
    final c = competition.toLowerCase();
    if (RegExp(r'\br2\b').hasMatch(c) ||
        c.contains('régional 2') ||
        c.contains('regional 2')) {
      return false;
    }
    return true;
  }

  static bool hasShareVisual(Map<String, dynamic>? matchDoc, DateTime now) {
    if (matchDoc == null || matchDoc.isEmpty) return false;
    if (!isPremiereLiveMatch(matchDoc)) return false;
    return MatchRatingService.isWithinSocialVisualWindow(
      MatchRatingService.liveEndedAtOf(matchDoc),
      now,
    );
  }

  static List<MatchSheetScorer> scorersFromDoc(
    Map<String, dynamic> data, {
    required bool cssa,
  }) {
    final team1 = (data['team1'] as String? ?? '').trim();
    final team2 = (data['team2'] as String? ?? '').trim();
    final events = MatchStatsSchema.eventsFromMatchDoc(data);
    final out = <MatchSheetScorer>[];
    for (final e in events) {
      final type = (e['type'] ?? '').toString().trim().toLowerCase();
      if (type != 'goal' && type != 'own_goal') continue;
      final cssaSide = eventIsCssaSide(e, team1, team2);
      final own = type == 'own_goal';
      final countsForCssa = own ? !cssaSide : cssaSide;
      if (countsForCssa != cssa) continue;
      final player = (e['player'] as String? ?? '').trim();
      if (player.isEmpty) continue;
      out.add(
        MatchSheetScorer(
          player: player,
          minute: eventMinute(e),
          ownGoal: own,
        ),
      );
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
  }

  static String seenKey(String matchId, [DateTime? endedAt]) =>
      endedAt == null
          ? '$_seenPrefix$matchId'
          : '$_seenPrefix${matchId}_${endedAt.millisecondsSinceEpoch}';

  Future<bool> hasSeenMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(seenKey(matchId)) == true) return true;
    // Ancienne clé horodatée (arrêt live).
    for (final key in prefs.getKeys()) {
      if (key.startsWith('$_seenPrefix${matchId}_')) return true;
    }
    return false;
  }

  Future<void> markSeenMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey(matchId), true);
  }

  Future<bool> hasSeen(String matchId, DateTime endedAt) =>
      hasSeenMatch(matchId);

  Future<void> markSeen(String matchId, DateTime endedAt) =>
      markSeenMatch(matchId);

  Future<Map<String, dynamic>> _mergeLiveWithMatch(
    Map<String, dynamic> live,
  ) async {
    final merged = Map<String, dynamic>.from(live);
    final matchId = (live['matchId'] as String? ?? '').trim();
    if (matchId.isEmpty || matchId.startsWith('live_')) return merged;
    try {
      final snap = await _db.collection('matches').doc(matchId).get();
      final m = snap.data();
      if (m == null) return merged;
      merged['benevoleType'] ??= m['benevoleType'];
      merged['competition'] ??= m['competition'];
      merged['date'] ??= m['date'];
      merged['logo1'] ??= m['logo1'];
      merged['logo2'] ??= m['logo2'];
      if (merged['events'] == null && m['events'] != null) {
        merged['events'] = m['events'];
      }
      if (merged['team1'] == null) merged['team1'] = m['team1'];
      if (merged['team2'] == null) merged['team2'] = m['team2'];
    } catch (_) {}
    return merged;
  }

  /// Après « Fin de match » / FIN PROLONG. : fusion live + fiche match.
  Future<Map<String, dynamic>> mergeLiveWithMatch(
    Map<String, dynamic> live,
  ) =>
      _mergeLiveWithMatch(live);
}

class MatchSheetScorer {
  final String player;
  final int minute;
  final bool ownGoal;

  const MatchSheetScorer({
    required this.player,
    required this.minute,
    this.ownGoal = false,
  });

  String get line {
    final name = player.trim();
    final stamp = minute > 0 ? "$minute'" : "—'";
    if (ownGoal) return '$name (c.s.c.)  $stamp';
    return '$name  $stamp';
  }
}
