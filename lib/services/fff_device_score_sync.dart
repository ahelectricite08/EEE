import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/fff_season_config.dart';
import 'season_config_service.dart';

Object? _decodeFffJsonSync(String body) => jsonDecode(body);

Future<Object?> _decodeFffJson(String body) => compute(_decodeFffJsonSync, body);

/// Le cron GCP se fait souvent 403 par le WAF FFF. Le téléphone / le PC
/// récupère scores + classements et les écrit en base.
class FffDeviceScoreSync {
  FffDeviceScoreSync._();
  static final instance = FffDeviceScoreSync._();

  static const _host = 'https://api-dofa.fff.fr';
  static const _minRankingTeams = 8;
  static const _headers = {
    'Accept': 'application/ld+json, application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Origin': 'https://epreuves.fff.fr',
    'Referer': 'https://epreuves.fff.fr/',
    'Accept-Language': 'fr-FR,fr;q=0.9',
  };

  /// Scores + classements R1 / R2. [rankings] exige un compte admin (rules).
  Future<({int scores, int rankingRows})> pullAndWriteAll({
    FffSeasonConfig? config,
    bool rankings = true,
  }) async {
    final cfg = config ?? await SeasonConfigService.getCurrent();
    final scores = await pullAndWriteScores(config: cfg);
    final rankingRows =
        rankings ? await pullAndWriteRankings(config: cfg) : 0;
    return (scores: scores, rankingRows: rankingRows);
  }

  /// Dernière journée FFF complète → `ranking` / `ranking_r2`.
  Future<int> pullAndWriteRankings({FffSeasonConfig? config}) async {
    final cfg = config ?? await SeasonConfigService.getCurrent();
    var n = await _syncRankingCollection(
      cp: cfg.fffCompetitionId,
      ph: cfg.fffPhaseId,
      gp: cfg.fffPouleId,
      collection: 'ranking',
      season: cfg.seasonLabel,
    );
    if (cfg.hasR2FffSource) {
      n += await _syncRankingCollection(
        cp: cfg.fffR2CompetitionId,
        ph: cfg.fffR2PhaseId,
        gp: cfg.fffR2PouleId,
        collection: 'ranking_r2',
        season: cfg.seasonLabel,
      );
    }
    return n;
  }

  /// Met à jour les fiches `matches` (et `matches_r2`) dont le score FFF
  /// est publié mais encore vide en base. Retourne le nombre de docs écrits.
  Future<int> pullAndWriteScores({FffSeasonConfig? config}) async {
    final cfg = config ?? await SeasonConfigService.getCurrent();
    var n = await _syncCompetition(
      cp: cfg.fffCompetitionId,
      ph: cfg.fffPhaseId,
      gp: cfg.fffPouleId,
      prefix: cfg.matchDocIdPrefix,
      collection: 'matches',
      createMissing: true,
      competitionLabel: cfg.competitionDisplayName,
      seasonLabel: cfg.seasonLabel,
    );
    if (cfg.hasR2FffSource) {
      n += await _syncCompetition(
        cp: cfg.fffR2CompetitionId,
        ph: cfg.fffR2PhaseId,
        gp: cfg.fffR2PouleId,
        prefix: 'fff_r2_',
        collection: 'matches_r2',
        sedanOnly: true,
        createMissing: true,
        competitionLabel: cfg.r2CompetitionDisplayName,
        seasonLabel: cfg.seasonLabel,
        benevoleType: 'Réserve',
      );
    }
    return n;
  }

  Future<int> _syncCompetition({
    required int cp,
    required int ph,
    required int gp,
    required String prefix,
    required String collection,
    bool sedanOnly = false,
    bool createMissing = false,
    String? competitionLabel,
    String? seasonLabel,
    String? benevoleType,
  }) async {
    if (cp <= 0) return 0;
    final pfx = prefix.endsWith('_') ? prefix : '${prefix}_';
    var url = Uri.parse(
      '$_host/api/compets/$cp/phases/$ph/poules/$gp/matchs?journee=1&itemsPerPage=100',
    );
    var written = 0;
    final seen = <String>{};
    final db = FirebaseFirestore.instance;

    while (true) {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) {
        debugPrint('[FffDeviceScoreSync] HTTP ${res.statusCode} $url');
        break;
      }
      final data = await _decodeFffJson(res.body);
      if (data is! Map) break;
      final members = data['hydra:member'];
      if (members is List) {
        var processed = 0;
        for (final raw in members) {
          if (raw is! Map) continue;
          final maNo = '${raw['ma_no'] ?? ''}';
          if (maNo.isEmpty || !seen.add(maNo)) continue;
          final team1 = _sideName(raw['home']);
          final team2 = _sideName(raw['away']);
          if (sedanOnly && !_isSedanCssa(team1, team2)) continue;
          processed += 1;
          if (processed % 12 == 0) {
            await Future<void>.delayed(Duration.zero);
          }

          final s1 = _parseScore(raw['home_score']);
          final s2 = _parseScore(raw['away_score']);
          final journee = _matchJournee(raw);
          final id = '$pfx$maNo';
          final ref = db.collection(collection).doc(id);
          final snap = await ref.get();

          if (!snap.exists) {
            if (!createMissing || team1.isEmpty || team2.isEmpty) continue;
            final when = _parseMatchDate(raw['date'], raw['time']);
            final finished = s1 != null && s2 != null;
            await ref.set({
              'team1': team1,
              'team2': team2,
              'logo1': _logoOf(raw['home']),
              'logo2': _logoOf(raw['away']),
              'score1': s1,
              'score2': s2,
              'date': Timestamp.fromDate(when),
              'competition': competitionLabel ?? 'Régional 2',
              'status': finished || when.isBefore(DateTime.now())
                  ? 'finished'
                  : 'upcoming',
              'fffId': maNo,
              if (journee != null) 'journee': journee,
              if (seasonLabel != null && seasonLabel.isNotEmpty)
                'fffSeason': seasonLabel,
              if (benevoleType != null) 'benevoleType': benevoleType,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            written += 1;
            continue;
          }

          final cur = snap.data() ?? {};
          final needsJournee =
              journee != null && _asInt(cur['journee']) != journee;
          if (s1 == null || s2 == null) {
            if (!needsJournee) continue;
            await ref.set({
              'journee': journee,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            written += 1;
            continue;
          }
          if (cur['score1'] == s1 &&
              cur['score2'] == s2 &&
              cur['status'] == 'finished' &&
              !needsJournee) {
            continue;
          }
          await ref.set({
            'score1': s1,
            'score2': s2,
            'status': 'finished',
            if (journee != null) 'journee': journee,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          written += 1;
        }
      }
      final next = (data['hydra:view'] is Map)
          ? (data['hydra:view'] as Map)['hydra:next']
          : null;
      if (next is! String || next.isEmpty) break;
      url = next.startsWith('http')
          ? Uri.parse(next)
          : Uri.parse('$_host$next');
    }
    return written;
  }

  Future<int> _syncRankingCollection({
    required int cp,
    required int ph,
    required int gp,
    required String collection,
    required String season,
  }) async {
    if (cp <= 0) return 0;
    final members = await _fetchHydraMembers(
      '$_host/api/compets/$cp/phases/$ph/poules/$gp/classement_journees?itemsPerPage=100',
    );
    final picked = _pickLatestCompleteJournee(members);
    if (picked.rows.length < _minRankingTeams) {
      debugPrint(
        '[FffDeviceScoreSync] $collection incomplet '
        '(${picked.rows.length} J${picked.journee})',
      );
      return 0;
    }

    final db = FirebaseFirestore.instance;
    final existing = await db.collection(collection).get();
    final logoByTeam = <String, String>{};
    for (final doc in existing.docs) {
      final t = (doc.data()['team'] ?? '').toString().trim().toUpperCase();
      final logo = (doc.data()['logo'] ?? '').toString().trim();
      if (t.isNotEmpty && logo.isNotEmpty) logoByTeam[t] = logo;
    }

    final keep = <String>{};
    var written = 0;
    final batch = db.batch();
    for (final raw in picked.rows) {
      if (raw is! Map) continue;
      final rank = _asInt(raw['rank']);
      if (rank == null || rank <= 0) continue;
      final equipe = raw['equipe'];
      String teamName = '';
      String? fffLogo;
      if (equipe is Map) {
        teamName = '${equipe['short_name'] ?? equipe['nom'] ?? ''}'.trim();
        final club = equipe['club'];
        if (club is Map) {
          fffLogo = club['logo']?.toString();
        }
        fffLogo ??= equipe['logo']?.toString();
      }
      final docId = 'pos_$rank';
      keep.add(docId);
      final logo = (fffLogo != null && fffLogo.trim().isNotEmpty)
          ? fffLogo.trim()
          : logoByTeam[teamName.toUpperCase()];
      batch.set(db.collection(collection).doc(docId), {
        'season': season,
        'position': rank,
        'team': teamName,
        'logo': logo,
        'mj': _asInt(raw['total_games_count']) ?? 0,
        'v': _asInt(raw['won_games_count']) ?? 0,
        'n': _asInt(raw['draw_games_count']) ?? 0,
        'd': _asInt(raw['lost_games_count']) ?? 0,
        'bf': _asInt(raw['goals_for_count']) ?? 0,
        'bc': _asInt(raw['goals_against_count']) ?? 0,
        'pts': _asInt(raw['point_count']) ?? 0,
        'forme': '${raw['forme'] ?? ''}',
        'journee': _asInt(raw['cj_no']) ?? picked.journee,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      written += 1;
    }
    for (final doc in existing.docs) {
      if (!keep.contains(doc.id)) {
        batch.delete(doc.reference);
        written += 1;
      }
    }
    if (written > 0) await batch.commit();
    return written;
  }

  Future<List<dynamic>> _fetchHydraMembers(String startUrl) async {
    var url = Uri.parse(startUrl);
    final out = <dynamic>[];
    while (true) {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) {
        debugPrint('[FffDeviceScoreSync] HTTP ${res.statusCode} $url');
        break;
      }
      final data = await _decodeFffJson(res.body);
      if (data is! Map) break;
      final members = data['hydra:member'];
      if (members is List) out.addAll(members);
      final next = (data['hydra:view'] is Map)
          ? (data['hydra:view'] as Map)['hydra:next']
          : null;
      if (next is! String || next.isEmpty) break;
      url = next.startsWith('http')
          ? Uri.parse(next)
          : Uri.parse('$_host$next');
    }
    return out;
  }

  static ({List<dynamic> rows, int journee}) _pickLatestCompleteJournee(
    List<dynamic> all,
  ) {
    final byJ = <int, List<dynamic>>{};
    var last = 0;
    for (final entry in all) {
      if (entry is! Map) continue;
      final j = _asInt(entry['cj_no']) ?? 0;
      if (j > last) last = j;
      (byJ[j] ??= []).add(entry);
    }
    final order = byJ.keys.where((j) => j > 0).toList()
      ..sort((a, b) => b.compareTo(a));
    for (final j in order) {
      final rows = byJ[j] ?? const [];
      if (rows.length >= _minRankingTeams) {
        return (rows: rows, journee: j);
      }
    }
    return (rows: all, journee: last);
  }

  static int? _matchJournee(Map raw) {
    final pj = raw['poule_journee'];
    if (pj is Map) {
      final n = _asInt(pj['number']) ?? _asInt(pj['name']);
      if (n != null && n > 0) return n;
    }
    final n = _asInt(raw['journee']) ?? _asInt(raw['cj_no']);
    if (n != null && n > 0) return n;
    return null;
  }

  static int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw.toString().trim());
  }

  static int? _parseScore(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static bool _isSedanCssa(String team1, String team2) {
    bool hit(String s) {
      final u = s.toUpperCase();
      return u.contains('SEDAN') || u.contains('CSSA');
    }
    return hit(team1) || hit(team2);
  }

  static String _sideName(dynamic side) {
    if (side is! Map) return '';
    final nested = side['equipe'];
    final fromNested = nested is Map
        ? '${nested['short_name'] ?? nested['nom'] ?? ''}'.trim()
        : '';
    final direct = '${side['short_name'] ?? side['nom'] ?? ''}'.trim();
    return direct.isNotEmpty ? direct : fromNested;
  }

  static String? _logoOf(dynamic side) {
    if (side is! Map) return null;
    final club = side['club'];
    if (club is Map) {
      final u = '${club['logo'] ?? ''}'.trim();
      if (u.isNotEmpty) return u;
    }
    final u = '${side['logo'] ?? ''}'.trim();
    return u.isEmpty ? null : u;
  }

  static DateTime _parseMatchDate(dynamic dateRaw, dynamic timeRaw) {
    final dateStr = '${dateRaw ?? ''}';
    final parts = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(dateStr);
    if (parts == null) {
      return DateTime.tryParse(dateStr) ?? DateTime.now();
    }
    final y = int.parse(parts.group(1)!);
    final mo = int.parse(parts.group(2)!);
    final day = int.parse(parts.group(3)!);
    var h = 15;
    var min = 0;
    final tm = RegExp(r'(\d+)H(\d+)', caseSensitive: false)
        .firstMatch('${timeRaw ?? ''}');
    if (tm != null) {
      h = int.parse(tm.group(1)!);
      min = int.parse(tm.group(2)!);
    }
    return DateTime(y, mo, day, h, min);
  }
}
