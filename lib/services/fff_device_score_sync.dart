import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  static String pouleCalendrierUrl(int cp, int ph, int gp) =>
      '$_host/api/compets/$cp/phases/$ph/poules/$gp/calendrier?itemsPerPage=50';

  static String pouleMatchsUrl(int cp, int ph, int gp) =>
      '$_host/api/compets/$cp/phases/$ph/poules/$gp/matchs?itemsPerPage=30';

  static String pouleClassementUrl(int cp, int ph, int gp) =>
      '$_host/api/compets/$cp/phases/$ph/poules/$gp/classement_journees?itemsPerPage=200';

  /// `fffClubNo` admin = affiliation (500266). L’API clubs = `cl_no` (380).
  static const cssaAffiliationNo = 500266;
  static const cssaDofaClubNo = 380;

  static String clubMatchsUrl(int clNo) =>
      '$_host/api/clubs/$clNo/matchs?itemsPerPage=100';
  static const minRankingTeams = 8;

  /// Dernier sync classement (pour le snackbar admin).
  FffRankingSyncReport? lastRankingReport;

  /// Dernier pull scores R1 + R2 (fiches `matches` / `matches_r2` écrites).
  int lastScoreWrites = 0;
  static const _headers = {
    'Accept': 'application/ld+json, application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Origin': 'https://epreuves.fff.fr',
    'Referer': 'https://epreuves.fff.fr/',
    'Accept-Language': 'fr-FR,fr;q=0.9',
  };

  /// Scores + classements R1 / R2. Écriture `ranking*` : staff
  /// (admin / CM / statisticien, `canWriteMatchOperations`).
  /// Classements **d’abord** : les scores paginent match par match et
  /// peuvent être coupés si l’app passe en fond.
  Future<({int scores, int rankingRows})> pullAndWriteAll({
    FffSeasonConfig? config,
    bool rankings = true,
  }) async {
    final cfg = config ?? await SeasonConfigService.getCurrent();
    var rankingRows = 0;
    var scores = 0;
    if (rankings) {
      try {
        rankingRows = await pullAndWriteRankings(
          config: cfg,
          allowLocalWrite: true,
          force: true,
        );
      } catch (e) {
        debugPrint('[FffDeviceScoreSync] rankings: $e');
      }
    }
    try {
      scores = await pullAndWriteScores(config: cfg);
    } catch (e) {
      debugPrint('[FffDeviceScoreSync] scores: $e');
    }
    return (scores: scores, rankingRows: rankingRows);
  }

  /// Dernière journée FFF complète → `ranking` / `ranking_r2`.
  ///
  /// Le téléphone lit la FFF, le serveur écrit (callable). [allowLocalWrite]
  /// = staff, filet si le callable n’est pas encore déployé.
  Future<int> pullAndWriteRankings({
    FffSeasonConfig? config,
    bool allowLocalWrite = false,
    bool force = false,
  }) async {
    final cfg = config ?? await SeasonConfigService.getCurrent();
    var n = 0;
    var journee = 0;
    String reason = '';
    try {
      final r1 = await _syncRankingCollection(
        cp: cfg.fffCompetitionId,
        ph: cfg.fffPhaseId,
        gp: cfg.fffPouleId,
        collection: 'ranking',
        season: cfg.seasonLabel,
        allowLocalWrite: allowLocalWrite,
        force: force,
      );
      n += r1.writes;
      journee = r1.journee;
      reason = r1.reason;
    } catch (e) {
      debugPrint('[FffDeviceScoreSync] ranking R1: $e');
    }
    if (cfg.hasR2FffSource) {
      try {
        final r2 = await _syncRankingCollection(
          cp: cfg.fffR2CompetitionId,
          ph: cfg.fffR2PhaseId,
          gp: cfg.fffR2PouleId,
          collection: 'ranking_r2',
          season: cfg.seasonLabel,
          allowLocalWrite: allowLocalWrite,
          force: force,
        );
        n += r2.writes;
      } catch (e) {
        debugPrint('[FffDeviceScoreSync] ranking R2: $e');
      }
    } else {
      debugPrint(
        '[FffDeviceScoreSync] ranking_r2 ignoré : fffR2CompetitionId=0',
      );
    }
    lastRankingReport = FffRankingSyncReport(
      writes: n,
      journee: journee,
      reason: reason,
    );
    return n;
  }

  /// Met à jour les fiches `matches` (et `matches_r2`) dont le score FFF
  /// est publié mais encore vide en base. Retourne le nombre de docs écrits.
  Future<int> pullAndWriteScores({FffSeasonConfig? config}) async {
    lastScoreWrites = 0;
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
    try {
      n += await _syncSedanCupsAndFriendlies(cfg);
    } catch (e) {
      debugPrint('[FffDeviceScoreSync] coupes/amicaux: $e');
    }
    lastScoreWrites = n;
    return n;
  }

  /// Coupes + amicaux 1ère Sedan. Pas les jeunes, pas la R2, pas Torcy.
  Future<int> _syncSedanCupsAndFriendlies(FffSeasonConfig cfg) async {
    final clNo = resolveCssaDofaClubNo(cfg.fffClubNo);
    if (clNo <= 0) return 0;
    final members = await _fetchHydraMembers(clubMatchsUrl(clNo));
    final col = FirebaseFirestore.instance.collection('matches');
    final seen = <String>{};
    var written = 0;
    var processed = 0;
    for (final raw in members) {
      if (raw is! Map) continue;
      if (!isSeniorFirstTeamClubMatch(raw, clNo)) continue;
      if (!isFffCupOrFriendly(raw)) continue;
      processed += 1;
      if (processed % 12 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final cup = fffCompetitionType(raw) == 'CP';
      final did = await _applyFffMatch(
        col: col,
        raw: raw,
        pfx: 'fff_',
        seen: seen,
        createMissing: true,
        competitionLabel: fffCompetitionDisplayName(raw),
        seasonLabel: cfg.seasonLabel,
        benevoleType: cup ? 'Coupe' : null,
      );
      if (did) written += 1;
    }
    return written;
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
    final byId = <String, Map>{};
    void absorb(List<dynamic> members) {
      for (final raw in members) {
        if (raw is! Map) continue;
        final maNo = '${raw['ma_no'] ?? ''}';
        if (maNo.isEmpty) continue;
        final prev = byId[maNo];
        if (prev == null ||
            (fffMatchHasPublishedScore(raw) &&
                !fffMatchHasPublishedScore(prev))) {
          byId[maNo] = raw;
        }
      }
    }

    absorb(await _fetchHydraMembers(pouleMatchsUrl(cp, ph, gp)));
    absorb(await _fetchHydraMembers(pouleCalendrierUrl(cp, ph, gp)));
    final ordered = byId.values.toList()..sort(compareFffMatchesForSync);

    final col = FirebaseFirestore.instance.collection(collection);
    final seen = <String>{};
    var written = 0;
    const chunk = 10;
    for (var i = 0; i < ordered.length; i += chunk) {
      final slice = ordered.skip(i).take(chunk).toList();
      final results = await Future.wait(
        slice.map(
          (raw) => _applyFffMatch(
            col: col,
            raw: raw,
            pfx: pfx,
            seen: seen,
            sedanOnly: sedanOnly,
            createMissing: createMissing,
            competitionLabel: competitionLabel,
            seasonLabel: seasonLabel,
            benevoleType: benevoleType,
          ),
        ),
      );
      for (final did in results) {
        if (did) written += 1;
      }
    }
    return written;
  }

  Future<bool> _applyFffMatch({
    required CollectionReference<Map<String, dynamic>> col,
    required Map raw,
    required String pfx,
    required Set<String> seen,
    bool sedanOnly = false,
    bool createMissing = false,
    String? competitionLabel,
    String? seasonLabel,
    String? benevoleType,
  }) async {
    final maNo = '${raw['ma_no'] ?? ''}';
    if (maNo.isEmpty || !seen.add(maNo)) return false;
    final team1 = _sideName(raw['home']);
    final team2 = _sideName(raw['away']);
    if (sedanOnly && !_isSedanCssa(team1, team2)) return false;

    final s1 = _fffSideScore(raw, 'home');
    final s2 = _fffSideScore(raw, 'away');
    final journee = _matchJournee(raw);
    final id = '$pfx$maNo';
    final found = await _existingFffMatch(
      col: col,
      docId: id,
      maNo: maNo,
    );
    final ref = found.ref;
    final snapExists = found.data != null;
    if (snapExists && found.data?['manual'] == true) return false;

    if (!snapExists) {
      if (!createMissing || team1.isEmpty || team2.isEmpty) return false;
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
      return true;
    }

    final cur = found.data ?? {};
    final needsJournee =
        journee != null && _asInt(cur['journee']) != journee;
    final needsComp = competitionLabel != null &&
        competitionLabel.isNotEmpty &&
        '${cur['competition'] ?? ''}' != competitionLabel;
    if (s1 == null || s2 == null) {
      if (!needsJournee && !needsComp) return false;
      await ref.set({
        if (needsJournee) 'journee': journee,
        if (needsComp) 'competition': competitionLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }
    if (cur['score1'] == s1 &&
        cur['score2'] == s2 &&
        cur['status'] == 'finished' &&
        !needsJournee &&
        !needsComp) {
      return false;
    }
    await ref.set({
      'score1': s1,
      'score2': s2,
      'status': 'finished',
      if (journee != null) 'journee': journee,
      if (needsComp) 'competition': competitionLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Même `ma_no` FFF → on met à jour la fiche existante, on n’en crée pas une 2e.
  Future<({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic>? data})>
      _existingFffMatch({
    required CollectionReference<Map<String, dynamic>> col,
    required String docId,
    required String maNo,
  }) async {
    final direct = col.doc(docId);
    final snap = await direct.get();
    if (snap.exists) {
      return (ref: direct, data: snap.data());
    }
    try {
      final alt = await col.where('fffId', isEqualTo: maNo).limit(3).get();
      if (alt.docs.isEmpty) return (ref: direct, data: null);
      var pick = alt.docs.first;
      for (final d in alt.docs) {
        if (d.id == docId || d.id.startsWith('fff_')) {
          pick = d;
          break;
        }
      }
      return (ref: pick.reference, data: pick.data());
    } catch (_) {
      return (ref: direct, data: null);
    }
  }

  Future<FffRankingSyncReport> _syncRankingCollection({
    required int cp,
    required int ph,
    required int gp,
    required String collection,
    required String season,
    bool allowLocalWrite = false,
    bool force = false,
  }) async {
    if (cp <= 0) {
      return const FffRankingSyncReport(writes: 0, reason: 'no_id');
    }
    final members = await _fetchHydraMembers(pouleClassementUrl(cp, ph, gp));
    final picked = pickLatestCompleteFffRankingJournee(members);
    if (!picked.complete) {
      debugPrint(
        '[FffDeviceScoreSync] $collection incomplet '
        '(${picked.rows.length} J${picked.journee}) — table inchangée',
      );
      return FffRankingSyncReport(
        writes: 0,
        journee: picked.journee,
        reason: 'incomplete',
      );
    }

    final ingested = await _ingestViaCallable(
      collection: collection,
      season: season,
      rows: picked.rows,
      force: force,
    );
    if (ingested != null && ingested.reason != 'throttled') {
      return ingested;
    }
    if (!allowLocalWrite) {
      return ingested ??
          FffRankingSyncReport(writes: 0, journee: picked.journee);
    }

    final db = FirebaseFirestore.instance;
    final existing = await db.collection(collection).get();
    final existingById = {
      for (final doc in existing.docs) doc.id: doc.data(),
    };
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
      final row = <String, dynamic>{
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
      };
      final prev = existingById[docId];
      if (prev != null && _rankingStoredEquals(prev, row)) {
        continue;
      }
      batch.set(db.collection(collection).doc(docId), {
        ...row,
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
    return FffRankingSyncReport(
      writes: written,
      journee: picked.journee,
      reason: 'local',
    );
  }

  Future<FffRankingSyncReport?> _ingestViaCallable({
    required String collection,
    required String season,
    required List<dynamic> rows,
    bool force = false,
  }) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(
        'ingestFffClassement',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final res = await fn.call(<String, dynamic>{
        'slot': collection == 'ranking_r2' ? 'r2' : 'r1',
        'season': season,
        'force': force,
        'members': rankingMembersForIngest(rows),
      });
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      if (data['success'] != true) return null;
      final writes = data['writes'];
      return FffRankingSyncReport(
        writes: writes is num ? writes.round() : 0,
        journee: (data['journee'] is num) ? (data['journee'] as num).round() : 0,
        reason: (data['reason'] as String?) ??
            ((data['skipped'] == true) ? 'skipped' : 'fff'),
      );
    } catch (e) {
      debugPrint('[FffDeviceScoreSync] ingest $collection: $e');
      return null;
    }
  }

  static bool _rankingStoredEquals(
    Map<String, dynamic> prev,
    Map<String, dynamic> next,
  ) {
    int n(dynamic v) => _asInt(v) ?? 0;
    return n(prev['position']) == n(next['position']) &&
        '${prev['team'] ?? ''}' == '${next['team'] ?? ''}' &&
        n(prev['mj']) == n(next['mj']) &&
        n(prev['v']) == n(next['v']) &&
        n(prev['n']) == n(next['n']) &&
        n(prev['d']) == n(next['d']) &&
        n(prev['bf']) == n(next['bf']) &&
        n(prev['bc']) == n(next['bc']) &&
        n(prev['pts']) == n(next['pts']) &&
        '${prev['season'] ?? ''}' == '${next['season'] ?? ''}' &&
        n(prev['journee']) == n(next['journee']);
  }

  Future<List<dynamic>> _fetchHydraMembers(String startUrl) async {
    final firstRes = await http.get(Uri.parse(startUrl), headers: _headers);
    if (firstRes.statusCode != 200) {
      debugPrint('[FffDeviceScoreSync] HTTP ${firstRes.statusCode} $startUrl');
      return [];
    }
    final firstData = await _decodeFffJson(firstRes.body);
    if (firstData is! Map) return [];
    final out = <dynamic>[];
    final firstMembers = firstData['hydra:member'];
    if (firstMembers is List) out.addAll(firstMembers);

    final lastPage = fffHydraLastPage(firstData);
    if (lastPage > 1) {
      final urls = [
        for (var p = 2; p <= lastPage.clamp(2, 40); p++)
          fffUrlWithPage(startUrl, p),
      ];
      final pages = await Future.wait(urls.map((u) async {
        final res = await http.get(Uri.parse(u), headers: _headers);
        if (res.statusCode != 200) {
          debugPrint('[FffDeviceScoreSync] HTTP ${res.statusCode} $u');
          return const <dynamic>[];
        }
        final data = await _decodeFffJson(res.body);
        if (data is! Map) return const <dynamic>[];
        final members = data['hydra:member'];
        return members is List
            ? List<dynamic>.from(members)
            : const <dynamic>[];
      }));
      for (final members in pages) {
        out.addAll(members);
      }
      return out;
    }

    var next = fffHydraNextUrl(firstData);
    while (next != null) {
      final res = await http.get(Uri.parse(next), headers: _headers);
      if (res.statusCode != 200) {
        debugPrint('[FffDeviceScoreSync] HTTP ${res.statusCode} $next');
        break;
      }
      final data = await _decodeFffJson(res.body);
      if (data is! Map) break;
      final members = data['hydra:member'];
      if (members is List) out.addAll(members);
      next = fffHydraNextUrl(data);
    }
    return out;
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

  static int? _fffSideScore(Map raw, String side) {
    final direct = _parseScore(raw['${side}_score']);
    if (direct != null) return direct;
    final nested = raw[side];
    if (nested is Map) {
      return _parseScore(nested['score']) ??
          _parseScore(nested['buts']) ??
          _parseScore(nested['goals']);
    }
    return null;
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

class FffRankingSyncReport {
  final int writes;
  final int journee;
  final String reason;

  const FffRankingSyncReport({
    required this.writes,
    this.journee = 0,
    this.reason = '',
  });
}

/// Dernière journée FFF avec assez d’équipes (même règle que Functions).
@visibleForTesting
bool fffMatchHasPublishedScore(Map raw) {
  return FffDeviceScoreSync._fffSideScore(raw, 'home') != null &&
      FffDeviceScoreSync._fffSideScore(raw, 'away') != null;
}

@visibleForTesting
int compareFffMatchesForSync(Map a, Map b) {
  final sa = fffMatchHasPublishedScore(a) ? 1 : 0;
  final sb = fffMatchHasPublishedScore(b) ? 1 : 0;
  if (sa != sb) return sb - sa;
  final da = DateTime.tryParse('${a['date'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
  final db = DateTime.tryParse('${b['date'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
  return db.compareTo(da);
}

@visibleForTesting
int fffHydraLastPage(Map data) {
  final view = data['hydra:view'];
  if (view is! Map) return 0;
  final last = view['hydra:last'];
  if (last is! String || last.isEmpty) return 0;
  final uri = Uri.parse(
    last.startsWith('http') ? last : '${FffDeviceScoreSync._host}$last',
  );
  return int.tryParse(uri.queryParameters['page'] ?? '') ?? 0;
}

@visibleForTesting
String fffUrlWithPage(String start, int page) {
  final uri = Uri.parse(start);
  final q = Map<String, String>.from(uri.queryParameters);
  q['page'] = '$page';
  return uri.replace(queryParameters: q).toString();
}

@visibleForTesting
String? fffHydraNextUrl(
  Map data, {
  String host = FffDeviceScoreSync._host,
}) {
  final view = data['hydra:view'];
  if (view is! Map) return null;
  final next = view['hydra:next'];
  if (next is! String || next.isEmpty) return null;
  return next.startsWith('http') ? next : '$host$next';
}

@visibleForTesting
({List<dynamic> rows, int journee, bool complete})
    pickLatestCompleteFffRankingJournee(
  List<dynamic> all, {
  int minTeams = FffDeviceScoreSync.minRankingTeams,
}) {
  final byJ = <int, List<dynamic>>{};
  var last = 0;
  for (final entry in all) {
    if (entry is! Map) continue;
    final j = FffDeviceScoreSync._asInt(entry['cj_no']) ?? 0;
    if (j > last) last = j;
    (byJ[j] ??= []).add(entry);
  }
  if (all.isEmpty) {
    return (rows: const [], journee: 0, complete: false);
  }

  final order = byJ.keys.where((j) => j > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  for (final j in order) {
    final rows = byJ[j] ?? const [];
    if (rows.length >= minTeams) {
      return (rows: rows, journee: j, complete: true);
    }
  }

  final unlabeled = byJ[0] ?? const <dynamic>[];
  if (unlabeled.length >= minTeams && byJ.length <= 1) {
    return (rows: unlabeled, journee: last, complete: true);
  }

  return (
    rows: last > 0 ? (byJ[last] ?? all) : all,
    journee: last,
    complete: false,
  );
}

/// Payload compact pour `ingestFffClassement` (pas tout le dump Hydra).
@visibleForTesting
List<Map<String, dynamic>> rankingMembersForIngest(List<dynamic> rows) {
  final out = <Map<String, dynamic>>[];
  for (final raw in rows) {
    if (raw is! Map) continue;
    final rank = FffDeviceScoreSync._asInt(raw['rank']);
    if (rank == null || rank <= 0) continue;
    final equipe = raw['equipe'];
    final eq = equipe is Map ? Map<dynamic, dynamic>.from(equipe) : const {};
    final club = eq['club'];
    final cl = club is Map ? Map<dynamic, dynamic>.from(club) : const {};
    final clNo = FffDeviceScoreSync._asInt(cl['cl_no']);
    out.add({
      'rank': rank,
      'cj_no': FffDeviceScoreSync._asInt(raw['cj_no']) ?? 0,
      'total_games_count':
          FffDeviceScoreSync._asInt(raw['total_games_count']) ?? 0,
      'won_games_count': FffDeviceScoreSync._asInt(raw['won_games_count']) ?? 0,
      'draw_games_count':
          FffDeviceScoreSync._asInt(raw['draw_games_count']) ?? 0,
      'lost_games_count':
          FffDeviceScoreSync._asInt(raw['lost_games_count']) ?? 0,
      'goals_for_count': FffDeviceScoreSync._asInt(raw['goals_for_count']) ?? 0,
      'goals_against_count':
          FffDeviceScoreSync._asInt(raw['goals_against_count']) ?? 0,
      'point_count': FffDeviceScoreSync._asInt(raw['point_count']) ?? 0,
      'forme': '${raw['forme'] ?? ''}',
      'equipe': {
        'short_name': '${eq['short_name'] ?? eq['nom'] ?? ''}',
        'nom': '${eq['nom'] ?? eq['short_name'] ?? ''}',
        'logo': '${eq['logo'] ?? ''}',
        'club': {
          'logo': '${cl['logo'] ?? ''}',
          if (clNo != null) 'cl_no': clNo,
        },
      },
    });
  }
  return out;
}

@visibleForTesting
int resolveCssaDofaClubNo(int configured) {
  if (configured <= 0 || configured == FffDeviceScoreSync.cssaAffiliationNo) {
    return FffDeviceScoreSync.cssaDofaClubNo;
  }
  return configured;
}

@visibleForTesting
String fffCompetitionType(Map raw) {
  final comp = raw['competition'];
  if (comp is Map) return '${comp['type'] ?? ''}'.trim().toUpperCase();
  return '';
}

@visibleForTesting
bool isFffCupOrFriendly(Map raw) {
  final t = fffCompetitionType(raw);
  return t == 'CP' || t == 'AC';
}

@visibleForTesting
bool isSeniorFirstTeamClubMatch(Map raw, int clNo) {
  if (clNo <= 0) return false;
  for (final key in ['home', 'away']) {
    final side = raw[key];
    if (side is! Map) continue;
    final club = side['club'];
    final sideCl = club is Map ? FffDeviceScoreSync._asInt(club['cl_no']) : null;
    if (sideCl != clNo) continue;
    final cat = '${side['category_code'] ?? ''}'.toUpperCase();
    final number = FffDeviceScoreSync._asInt(side['number']) ?? 0;
    if (cat == 'SEM' && number == 1) return true;
  }
  return false;
}

@visibleForTesting
String fffCompetitionLabel(String? name, String? type) {
  final n = (name ?? '').trim().toUpperCase();
  final t = (type ?? '').trim().toUpperCase();
  if (t == 'AC' || n.contains('AMICAL')) return 'Match Amical';
  if (n.contains('COUPE DE FRANCE')) return 'Coupe de France';
  if (n.contains('COUPE DU GRAND EST') || n.contains('COUPE GRAND EST')) {
    return 'Coupe Grand Est';
  }
  if (n.contains('COUPE DES ARDENNES')) return 'Coupe des Ardennes';
  final raw = (name ?? '').trim();
  if (raw.isEmpty) return t == 'CP' ? 'Coupe' : 'Match Amical';
  return raw
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

@visibleForTesting
String fffCompetitionDisplayName(Map raw) {
  final comp = raw['competition'];
  if (comp is! Map) return fffCompetitionLabel('', '');
  return fffCompetitionLabel(
    '${comp['name'] ?? ''}',
    '${comp['type'] ?? ''}',
  );
}
