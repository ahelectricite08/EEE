import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/prono/presentation/history/recent_prono_row.dart';

// ── Modèles ───────────────────────────────────────────────────────────────────
class TournamentMatch {
  final String id;
  final String team1;
  final String team2;
  final String flag1;
  final String flag2;
  final DateTime date;
  final String status; // upcoming | finished
  final int? result1;
  final int? result2;
  final String phase; // Ex: "Phase de groupes", "Quart de finale"…
  /// Lettre de groupe (A, B, …) pour filtres / en-têtes. Vide si inconnu.
  final String groupKey;
  /// Ouverture des pronos (Firestore `pronoOpensAt` / `opensAt`). Sinon UI = J-7.
  final DateTime? predictionOpensAt;

  const TournamentMatch({
    required this.id,
    required this.team1,
    required this.team2,
    this.flag1 = '',
    this.flag2 = '',
    required this.date,
    required this.status,
    this.result1,
    this.result2,
    required this.phase,
    this.groupKey = '',
    this.predictionOpensAt,
  });

  static String _groupKeyFromMap(Map<String, dynamic> d) {
    final raw = (d['group'] ?? d['groupe'] ?? d['groupLetter'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) {
      if (raw.length == 1) return raw.toUpperCase();
      // A–L (voire plus) : CDM 2026 étendue ; éviter de caper à H.
      final m = RegExp(r'([A-Z])\s*$', caseSensitive: false).firstMatch(raw);
      if (m != null) return m.group(1)!.toUpperCase();
    }
    final phase = (d['phase'] ?? '').toString();
    var m2 = RegExp(r'[Gg]r\.?\s*([A-Z])\b').firstMatch(phase);
    m2 ??= RegExp(r'[Gg]roupe\s*([A-Z])\b').firstMatch(phase);
    if (m2 != null) return m2.group(1)!.toUpperCase();
    return '';
  }

  static DateTime? _opensAtFromMap(Map<String, dynamic> d) {
    for (final key in ['pronoOpensAt', 'opensAt', 'predictionOpensAt']) {
      final v = d[key];
      if (v is Timestamp) return v.toDate();
    }
    return null;
  }

  factory TournamentMatch.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TournamentMatch(
      id: doc.id,
      team1: d['team1'] ?? '',
      team2: d['team2'] ?? '',
      flag1: d['flag1'] ?? '',
      flag2: d['flag2'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      status: d['status'] ?? 'upcoming',
      result1: d['result1'],
      result2: d['result2'],
      phase: d['phase'] ?? '',
      groupKey: _groupKeyFromMap(d),
      predictionOpensAt: _opensAtFromMap(d),
    );
  }
}

class TournamentPrediction {
  final String matchId;
  final int score1;
  final int score2;
  final int points;

  const TournamentPrediction({
    required this.matchId,
    required this.score1,
    required this.score2,
    required this.points,
  });

  factory TournamentPrediction.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TournamentPrediction(
      matchId: d['matchId'] ?? '',
      score1: d['score1'] ?? 0,
      score2: d['score2'] ?? 0,
      points: d['points'] ?? 0,
    );
  }
}

class TournamentEntry {
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final int exactScores;
  /// Rang 1-based (écrit par Cloud Function après chaque match terminé).
  final int? rank;

  const TournamentEntry({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    required this.points,
    required this.exactScores,
    this.rank,
  });

  factory TournamentEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rankRaw = d['rank'];
    return TournamentEntry(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Supporter',
      avatarUrl: d['avatarUrl'],
      points: d['points'] ?? 0,
      exactScores: d['exactScores'] ?? 0,
      rank: rankRaw is num ? rankRaw.toInt() : null,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
class TournamentService {
  static final _db = FirebaseFirestore.instance;

  // Collection racine des tournois
  static CollectionReference _tournaments() =>
      _db.collection('tournaments');

  static DocumentReference _tournament(String id) =>
      _tournaments().doc(id);

  // ── Matchs ────────────────────────────────────────────────────────────────
  static Stream<List<TournamentMatch>> matchesStream(String tournamentId) =>
      _tournament(tournamentId)
          .collection('matches')
          .orderBy('date')
          .snapshots()
          .map((s) => s.docs.map(TournamentMatch.fromDoc).toList());

  // ── Prédiction d'un user pour un match ───────────────────────────────────
  static Future<TournamentPrediction?> getPrediction(
      String tournamentId, String matchId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _tournament(tournamentId)
        .collection('predictions')
        .doc('${matchId}_$uid')
        .get();
    if (!doc.exists) return null;
    return TournamentPrediction.fromDoc(doc);
  }

  static Stream<TournamentPrediction?> predictionStream(
      String tournamentId, String matchId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _tournament(tournamentId)
        .collection('predictions')
        .doc('${matchId}_$uid')
        .snapshots()
        .map((doc) => doc.exists ? TournamentPrediction.fromDoc(doc) : null);
  }

  static Future<void> savePrediction(
      String tournamentId, String matchId, int score1, int score2) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _db.collection('users').doc(uid).get();
    final displayName = (user.data() as Map?)?['displayName'] ?? 'Supporter';
    await _tournament(tournamentId)
        .collection('predictions')
        .doc('${matchId}_$uid')
        .set({
      'matchId': matchId,
      'uid': uid,
      'displayName': displayName,
      'score1': score1,
      'score2': score2,
      'points': 0,
      'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Derniers pronos CDM **déjà scorés** (0 / 1 / 3 pts), tri par date du match.
  static Future<List<RecentPronoRow>> recentResolvedTournamentPredictions(
    String tournamentId,
    String uid, {
    int limit = 10,
  }) async {
    final snap = await _tournament(tournamentId)
        .collection('predictions')
        .where('uid', isEqualTo: uid)
        .get();
    final partial = <RecentPronoRow>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final docUid = (d['uid'] ?? '').toString();
      if (docUid != uid) continue;
      if (!doc.id.endsWith('_$uid')) continue;
      final matchId = (d['matchId'] ?? '').toString();
      if (matchId.isEmpty) continue;
      final pts = (d['points'] as num?)?.toInt();
      if (pts == null || pts < 0 || pts > 3) continue;
      final u = d['updatedAt'];
      final fallback = u is Timestamp
          ? u.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      partial.add(
        RecentPronoRow(
          matchId: matchId,
          team1: '',
          team2: '',
          orderDate: fallback,
          predHome: (d['score1'] as num?)?.toInt() ?? 0,
          predAway: (d['score2'] as num?)?.toInt() ?? 0,
          resHome: null,
          resAway: null,
          pronoPoints: pts,
          isWorldCup: true,
        ),
      );
    }
    final meta = <String, TournamentMatch>{};
    final ids = partial.map((e) => e.matchId).toSet().toList();
    for (var i = 0; i < ids.length; i += 10) {
      final end = math.min(i + 10, ids.length);
      if (end <= i) break;
      final chunk = ids.sublist(i, end);
      final ms = await _tournament(tournamentId)
          .collection('matches')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in ms.docs) {
        meta[doc.id] = TournamentMatch.fromDoc(doc);
      }
    }
    final merged = partial
        .map((e) {
          final m = meta[e.matchId];
          if (m == null || m.status != 'finished') return null;
          return RecentPronoRow(
            matchId: e.matchId,
            team1: m.team1,
            team2: m.team2,
            orderDate: m.date,
            predHome: e.predHome,
            predAway: e.predAway,
            resHome: m.result1,
            resAway: m.result2,
            pronoPoints: e.pronoPoints,
            isWorldCup: true,
          );
        })
        .whereType<RecentPronoRow>()
        .toList();
    merged.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    if (merged.length <= limit) return merged;
    return merged.sublist(0, limit);
  }

  // ── Classement ────────────────────────────────────────────────────────────
  /// Tête du classement (léger en lecture : 20 docs max).
  static Stream<List<TournamentEntry>> leaderboardTopStream(
    String tournamentId, {
    int limit = 20,
  }) =>
      _tournament(tournamentId)
          .collection('leaderboard')
          .orderBy('points', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(TournamentEntry.fromDoc).toList());

  /// Compat : même surface que l’ancien flux (top 20).
  static Stream<List<TournamentEntry>> leaderboardStream(String tournamentId) =>
      leaderboardTopStream(tournamentId, limit: 20);

  /// Fenêtre [rank − window … rank + window] si tu es hors du top `maxTop` et que `rank` existe.
  static Stream<List<TournamentEntry>> leaderboardNeighborWindowStream(
    String tournamentId, {
    int maxTop = 20,
    int window = 3,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <TournamentEntry>[]);
    return _tournament(tournamentId)
        .collection('leaderboard')
        .doc(uid)
        .snapshots()
        .asyncMap((snap) async {
      if (!snap.exists) return const <TournamentEntry>[];
      final data = snap.data();
      if (data is! Map<String, dynamic>) return const <TournamentEntry>[];
      final r = data['rank'];
      if (r is! num) return const <TournamentEntry>[];
      final rank = r.toInt();
      if (rank <= maxTop) return const <TournamentEntry>[];

      final low = math.max(1, rank - window);
      final high = rank + window;
      final q = await _tournament(tournamentId)
          .collection('leaderboard')
          .where('rank', isGreaterThanOrEqualTo: low)
          .where('rank', isLessThanOrEqualTo: high)
          .orderBy('rank')
          .get();
      return q.docs.map(TournamentEntry.fromDoc).toList();
    });
  }

  /// Rang officiel (champ `rank` sur ton doc leaderboard).
  static Stream<int?> myRankStream(String tournamentId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _tournament(tournamentId)
        .collection('leaderboard')
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final r = snap.data()?['rank'];
      if (r is num) return r.toInt();
      return null;
    });
  }

  /// Ta ligne complète au classement (points, exacts, pseudo) — même doc que [myRankStream].
  static Stream<TournamentEntry?> myLeaderboardEntryStream(String tournamentId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _tournament(tournamentId)
        .collection('leaderboard')
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return TournamentEntry.fromDoc(snap);
    });
  }

  // ── Tournoi actif ─────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> activeTournamentsStream() =>
      _tournaments()
          .where('active', isEqualTo: true)
          .limit(1)
          .snapshots();
}
