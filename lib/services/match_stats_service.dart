import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/fff_season_config.dart';
import '../models/match_model.dart';
import 'season_config_service.dart';

class MatchStatsService {
  static final _db = FirebaseFirestore.instance;

  static final Map<String, (String, DateTime)> _formCache = {};
  static final Map<String, (String?, DateTime)> _rankCache = {};
  static final Map<String, (Map<String, dynamic>?, DateTime)> _statsCache = {};
  static const _ttl = Duration(minutes: 2);

  static void clearCache() {
    _formCache.clear();
    _rankCache.clear();
    _statsCache.clear();
  }

  /// Derniers résultats (W/D/L) pour [teamName], **uniquement** sur la saison [seasonLabel].
  static Future<String> getForm(
    String teamName, {
    int last = 5,
    DateTime? before,
    required String seasonLabel,
  }) async {
    final cacheKey =
        '${_teamKey(teamName)}|$seasonLabel|${before?.toIso8601String() ?? 'now'}';
    final cached = _formCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.$2) < _ttl) {
      return cached.$1;
    }

    final snap = await _db
        .collection('matches')
        .where('status', isEqualTo: 'finished')
        .orderBy('date', descending: true)
        .limit(320)
        .get();

    final cutoff = before ?? DateTime.now();
    final seenMatches = <String>{};
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!FffSeasonConfig.matchDocBelongsToSeason(data, seasonLabel)) {
        continue;
      }
      final rawDate = data['date'];
      if (rawDate is! Timestamp) continue;
      if (!rawDate.toDate().isBefore(cutoff)) continue;
      final team1 = data['team1']?.toString() ?? '';
      final team2 = data['team2']?.toString() ?? '';
      if (!_sameTeam(teamName, team1) && !_sameTeam(teamName, team2)) {
        continue;
      }

      final signature = _matchSignature(data);
      if (!seenMatches.add(signature)) continue;
      docs.add(doc);
      if (docs.length >= last) break;
    }

    final form = docs
        .map((doc) {
          final d = doc.data();
          final isTeam1 = _sameTeam(teamName, d['team1']?.toString() ?? '');
          final s1 = (d['score1'] as num?)?.toInt() ?? 0;
          final s2 = (d['score2'] as num?)?.toInt() ?? 0;
          final myScore = isTeam1 ? s1 : s2;
          final oppScore = isTeam1 ? s2 : s1;
          if (myScore > oppScore) return 'W';
          if (myScore < oppScore) return 'L';
          return 'D';
        })
        .join('');

    _formCache[cacheKey] = (form, DateTime.now());
    return form;
  }

  static Future<String?> getRank(
    String teamName, {
    String? seasonLabel,
  }) async {
    final key = '${_teamKey(teamName)}|r|${seasonLabel ?? '_'}';
    final cached = _rankCache[key];
    if (cached != null && DateTime.now().difference(cached.$2) < _ttl) {
      return cached.$1;
    }
    final snap = await _db
        .collection('ranking')
        .where('team', isEqualTo: teamName)
        .get();

    Map<String, dynamic>? pickRow() {
      if (snap.docs.isEmpty) return null;
      if (seasonLabel != null) {
        for (final doc in snap.docs) {
          final row = doc.data();
          final s = row['season'] as String?;
          if (s == seasonLabel) return row;
        }
        return null;
      }
      for (final doc in snap.docs) {
        final row = doc.data();
        if (row['season'] == null) return row;
      }
      return snap.docs.first.data();
    }

    final row = pickRow();
    if (row == null) {
      _rankCache[key] = (null, DateTime.now());
      return null;
    }
    final pos = row['position']?.toString();
    _rankCache[key] = (pos, DateTime.now());
    return pos;
  }

  static Future<Map<String, dynamic>?> getStats(
    String teamName, {
    String? seasonLabel,
  }) async {
    final key = '${_teamKey(teamName)}|s|${seasonLabel ?? '_'}';
    final cached = _statsCache[key];
    if (cached != null && DateTime.now().difference(cached.$2) < _ttl) {
      return cached.$1;
    }
    final snap = await _db
        .collection('ranking')
        .where('team', isEqualTo: teamName)
        .get();

    Map<String, dynamic>? pickRow() {
      if (snap.docs.isEmpty) return null;
      if (seasonLabel != null) {
        for (final doc in snap.docs) {
          final row = doc.data();
          final s = row['season'] as String?;
          if (s == seasonLabel) return row;
        }
        return null;
      }
      for (final doc in snap.docs) {
        final row = doc.data();
        if (row['season'] == null) return row;
      }
      return snap.docs.first.data();
    }

    final data = pickRow();
    if (data == null) {
      _statsCache[key] = (null, DateTime.now());
      return null;
    }
    final stats = <String, dynamic>{
      'v': data['v'],
      'n': data['n'],
      'd': data['d'],
    };
    _statsCache[key] = (stats, DateTime.now());
    return stats;
  }

  static Future<MatchModel> enrich(MatchModel match) async {
    final cfg = await SeasonConfigService.getCurrent();
    final season = (match.fffSeason != null && match.fffSeason!.trim().isNotEmpty)
        ? match.fffSeason!.trim()
        : cfg.seasonLabel;
    final useLiveRanking = season == cfg.seasonLabel;

    final results = await Future.wait([
      getForm(match.team1, before: match.date, seasonLabel: season),
      getForm(match.team2, before: match.date, seasonLabel: season),
      useLiveRanking
          ? (match.rank1 != null
                ? Future.value(match.rank1)
                : getRank(match.team1, seasonLabel: season))
          : Future.value(match.rank1),
      useLiveRanking
          ? (match.rank2 != null
                ? Future.value(match.rank2)
                : getRank(match.team2, seasonLabel: season))
          : Future.value(match.rank2),
      useLiveRanking
          ? getStats(match.team1, seasonLabel: season)
          : Future.value(null),
      useLiveRanking
          ? getStats(match.team2, seasonLabel: season)
          : Future.value(null),
    ]);

    String? wdl(Map<String, dynamic>? s) {
      if (s == null) return null;
      final v = s['v'];
      final n = s['n'];
      final d = s['d'];
      if (v == null && n == null && d == null) return null;
      return '${v ?? 0}V ${n ?? 0}N ${d ?? 0}D';
    }

    return MatchModel(
      id: match.id,
      team1: match.team1,
      team2: match.team2,
      logo1: match.logo1,
      logo2: match.logo2,
      score1: match.score1,
      score2: match.score2,
      date: match.date,
      competition: match.competition,
      status: match.status,
      replayVideoId: match.replayVideoId,
      stats: match.stats,
      form1: results[0] as String,
      form2: results[1] as String,
      rank1: results[2] as String?,
      rank2: results[3] as String?,
      wdl1: wdl(results[4] as Map<String, dynamic>?),
      wdl2: wdl(results[5] as Map<String, dynamic>?),
      stadiumImageUrl: match.stadiumImageUrl,
      earlyPublish: match.earlyPublish,
      fffSeason: match.fffSeason,
    );
  }

  static Future<List<MatchModel>> enrichAll(List<MatchModel> matches) async {
    try {
      return await Future.wait(matches.map(enrich));
    } catch (e) {
      debugPrint('[MatchStatsService] enrichAll error: $e');
      return matches;
    }
  }

  static String _teamKey(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[ÀÂÄ]'), 'A')
        .replaceAll(RegExp(r'[ÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÔÖ]'), 'O')
        .replaceAll(RegExp(r'[ÛÜÙ]'), 'U')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim();
    if (normalized.contains('SEDAN') || normalized.contains('CSSA')) {
      return 'SEDAN';
    }
    return normalized;
  }

  static bool _sameTeam(String a, String b) {
    final left = _teamKey(a);
    final right = _teamKey(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    if (left.contains(right) || right.contains(left)) return true;
    final leftWords = left.split(' ').where((w) => w.length > 3).toSet();
    final rightWords = right.split(' ').where((w) => w.length > 3).toSet();
    return leftWords.intersection(rightWords).isNotEmpty;
  }

  static String _matchSignature(Map<String, dynamic> data) {
    final date = data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate().toIso8601String()
        : '';
    final teams = <String>[
      _teamKey(data['team1']?.toString() ?? ''),
      _teamKey(data['team2']?.toString() ?? ''),
    ]..sort();
    return [
      date,
      teams.join('|'),
      (data['score1'] as num?)?.toInt() ?? 0,
      (data['score2'] as num?)?.toInt() ?? 0,
    ].join('|');
  }
}
