import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/benevole_posts.dart';
import '../models/match_lineup.dart';
import '../models/match_stats_schema.dart';
import 'match_rating_service.dart';

/// Stories 9:16 (1ère Sedan) + ancienne feuille (tests / fallback).
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

  /// 1ère Sedan / CSSA uniquement — pas R2, réserve, Flammes, ni un autre club.
  static bool isSedanPremiereMatch(Map<String, dynamic>? data) {
    if (!isPremiereLiveMatch(data)) return false;
    final team1 = (data?['team1'] as String? ?? '').trim();
    final team2 = (data?['team2'] as String? ?? '').trim();
    return isCssaTeamLabel(team1) || isCssaTeamLabel(team2);
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

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Fusion live → fiche `matches` → `match_stats` : events, XI, logos, score.
  /// Ne calcule jamais un score : on recopie seulement ce qui est déjà écrit.
  static Map<String, dynamic> composeStoryDoc({
    Map<String, dynamic>? live,
    Map<String, dynamic>? match,
    Map<String, dynamic>? stats,
  }) {
    final out = <String, dynamic>{};
    if (stats != null) out.addAll(stats);
    if (match != null) out.addAll(match);
    if (live != null) {
      live.forEach((k, v) {
        if (v != null) out[k] = v;
      });
    }

    out['team1'] = _firstNonEmpty([
          live?['team1'],
          match?['team1'],
          stats?['team1'],
          out['team1'],
        ]) ??
        '';
    out['team2'] = _firstNonEmpty([
          live?['team2'],
          match?['team2'],
          stats?['team2'],
          out['team2'],
        ]) ??
        '';
    out['competition'] = _firstNonEmpty([
          live?['competition'],
          match?['competition'],
          stats?['competition'],
          out['competition'],
        ]) ??
        '';
    final logo1 = _firstNonEmpty([
      live?['logo1'],
      match?['logo1'],
      stats?['logo1'],
      out['logo1'],
    ]);
    final logo2 = _firstNonEmpty([
      live?['logo2'],
      match?['logo2'],
      stats?['logo2'],
      out['logo2'],
    ]);
    if (logo1 != null) {
      out['logo1'] = logo1;
    } else {
      out.remove('logo1');
    }
    if (logo2 != null) {
      out['logo2'] = logo2;
    } else {
      out.remove('logo2');
    }
    final type = _firstNonEmpty([
      live?['benevoleType'],
      match?['benevoleType'],
      stats?['benevoleType'],
      out['benevoleType'],
    ]);
    if (type != null) out['benevoleType'] = type;

    out['date'] = live?['date'] ?? match?['date'] ?? stats?['date'] ?? out['date'];

    final score1 = live?['score1'] ??
        live?['scoreHome'] ??
        live?['homeScore'] ??
        match?['score1'] ??
        match?['scoreHome'] ??
        match?['homeScore'] ??
        stats?['score1'] ??
        stats?['scoreHome'] ??
        stats?['homeScore'];
    final score2 = live?['score2'] ??
        live?['scoreAway'] ??
        live?['awayScore'] ??
        match?['score2'] ??
        match?['scoreAway'] ??
        match?['awayScore'] ??
        stats?['score2'] ??
        stats?['scoreAway'] ??
        stats?['awayScore'];
    if (score1 != null) out['score1'] = score1;
    if (score2 != null) out['score2'] = score2;

    final liveEvents = MatchStatsSchema.eventsFromMatchDoc(live);
    final matchEvents = MatchStatsSchema.eventsFromMatchDoc(match);
    final statsEvents = MatchStatsSchema.eventsFromMatchDoc(stats);
    if (liveEvents.isNotEmpty) {
      out['events'] = live?['events'] ?? liveEvents;
    } else if (matchEvents.isNotEmpty) {
      out['events'] = match?['events'] ?? matchEvents;
    } else if (statsEvents.isNotEmpty) {
      out['events'] = stats?['events'] ?? statsEvents;
    }

    final lineups = MatchLineups.mergeForMotm(live, match, stats);
    if (lineups.home.hasContent) {
      out['lineupHome'] = lineups.home.toMap();
    }
    if (lineups.away.hasContent) {
      out['lineupAway'] = lineups.away.toMap();
    }

    final matchId = _firstNonEmpty([
      live?['matchId'],
      match?['matchId'],
      match?['id'],
      stats?['matchId'],
      out['matchId'],
    ]);
    if (matchId != null) out['matchId'] = matchId;

    return out;
  }

  static String storyMatchIdOf(Map<String, dynamic> data) {
    final a = (data['matchId'] as String? ?? '').trim();
    if (a.isNotEmpty) return a;
    return (data['id'] as String? ?? '').trim();
  }

  /// Live + `matches/{id}` + `match_stats/{id}` pour les stories (pendant et après).
  Future<Map<String, dynamic>> mergeStorySource(Map<String, dynamic> live) async {
    final source = Map<String, dynamic>.from(live);
    var matchId = storyMatchIdOf(source);
    if (matchId.isNotEmpty) source['matchId'] = matchId;
    final mergedLive = await mergeLiveWithMatch(source);

    Map<String, dynamic>? matchDoc;
    Map<String, dynamic>? statsDoc;
    if (matchId.isEmpty) {
      matchId = storyMatchIdOf(mergedLive);
    }
    if (matchId.isNotEmpty && !matchId.startsWith('live_')) {
      try {
        matchDoc = (await _db.collection('matches').doc(matchId).get()).data();
      } catch (_) {}
      try {
        statsDoc = (await _db.collection('match_stats').doc(matchId).get()).data();
      } catch (_) {}
    }
    final out = composeStoryDoc(
      live: mergedLive,
      match: matchDoc,
      stats: statsDoc,
    );
    if (matchId.isNotEmpty) out['matchId'] = matchId;
    return out;
  }

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
