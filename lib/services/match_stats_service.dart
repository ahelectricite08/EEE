import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';

class MatchStatsService {
  static final _db = FirebaseFirestore.instance;

  static final Map<String, (String, DateTime)>  _formCache = {};
  static final Map<String, (String?, DateTime)> _rankCache = {};
  static const _ttl = Duration(minutes: 10);

  // ── Forme récente (ex: "WWDLW") ─────────────────────────────────────────────
  static Future<String> getForm(String teamName, {int last = 5}) async {
    final cached = _formCache[teamName];
    if (cached != null && DateTime.now().difference(cached.$2) < _ttl) {
      return cached.$1;
    }
    debugPrint('[MatchStatsService] getForm for "$teamName"');
    final results = await Future.wait([
      _db.collection('matches')
          .where('status', isEqualTo: 'finished')
          .where('team1', isEqualTo: teamName)
          .orderBy('date', descending: true)
          .limit(last)
          .get(),
      _db.collection('matches')
          .where('status', isEqualTo: 'finished')
          .where('team2', isEqualTo: teamName)
          .orderBy('date', descending: true)
          .limit(last)
          .get(),
    ]);

    final docs = [...results[0].docs, ...results[1].docs];

    // Trier par date décroissante puis prendre les N derniers
    docs.sort((a, b) {
      final da = (a.data()['date'] as Timestamp).toDate();
      final db2 = (b.data()['date'] as Timestamp).toDate();
      return db2.compareTo(da);
    });

    final form = docs.take(last).map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final isTeam1 = d['team1'] == teamName;
      final s1 = (d['score1'] as num?)?.toInt() ?? 0;
      final s2 = (d['score2'] as num?)?.toInt() ?? 0;
      final myScore = isTeam1 ? s1 : s2;
      final oppScore = isTeam1 ? s2 : s1;
      if (myScore > oppScore) return 'W';
      if (myScore < oppScore) return 'L';
      return 'D';
    }).join('');

    debugPrint('[MatchStatsService] form for "$teamName": "$form" (${docs.length} matchs trouvés)');
    _formCache[teamName] = (form, DateTime.now());
    return form;
  }

  // ── Rang depuis la collection ranking ────────────────────────────────────────
  static Future<String?> getRank(String teamName) async {
    final cached = _rankCache[teamName];
    if (cached != null && DateTime.now().difference(cached.$2) < _ttl) {
      return cached.$1;
    }
    final snap = await _db
        .collection('ranking')
        .where('team', isEqualTo: teamName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      _rankCache[teamName] = (null, DateTime.now());
      return null;
    }
    final pos = snap.docs.first.data()['position']?.toString();
    _rankCache[teamName] = (pos, DateTime.now());
    return pos;
  }

  // ── Enrichit un MatchModel avec forme + rang calculés ────────────────────────
  // Si form1/form2/rank1/rank2 sont déjà dans Firestore, on les garde.
  static Future<MatchModel> enrich(MatchModel match) async {
    final results = await Future.wait([
      match.form1 != null ? Future.value(match.form1!) : getForm(match.team1),
      match.form2 != null ? Future.value(match.form2!) : getForm(match.team2),
      match.rank1 != null ? Future.value(match.rank1)  : getRank(match.team1),
      match.rank2 != null ? Future.value(match.rank2)  : getRank(match.team2),
    ]);

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
    );
  }

  // ── Enrichit une liste entière en parallèle ───────────────────────────────────
  static Future<List<MatchModel>> enrichAll(List<MatchModel> matches) async {
    try {
      return await Future.wait(matches.map(enrich));
    } catch (e) {
      debugPrint('[MatchStatsService] enrichAll error: $e');
      return matches;
    }
  }
}
