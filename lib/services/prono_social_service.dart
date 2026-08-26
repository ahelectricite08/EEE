import 'dart:async';
import 'dart:math';

import 'xp_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/prono/presentation/history/recent_prono_row.dart';
import '../models/match_model.dart';

class PronoPopularPick {
  final String label;
  final int votes;
  final double share;

  const PronoPopularPick({
    required this.label,
    required this.votes,
    required this.share,
  });
}

class LeagueStandingEntry {
  final String uid;
  final String displayName;
  final int points;
  final int exactScores;
  final int goodResults;
  final int totalPredictions;
  final int perfectXiCount;

  const LeagueStandingEntry({
    required this.uid,
    required this.displayName,
    required this.points,
    required this.exactScores,
    required this.goodResults,
    required this.totalPredictions,
    this.perfectXiCount = 0,
  });
}

/// Ligne classement global (saison) — top / voisins.
class GlobalLeaderboardRow {
  final String uid;
  final String displayName;
  final int points;
  final int exactScores;
  final int perfectXiCount;
  final int rank;

  const GlobalLeaderboardRow({
    required this.uid,
    required this.displayName,
    required this.points,
    required this.exactScores,
    this.perfectXiCount = 0,
    required this.rank,
  });
}

/// Vue classement global : top 20 + rang user + voisins (sans charger tout le peloton).
class GlobalLeaderboardView {
  final List<GlobalLeaderboardRow> top;
  final List<GlobalLeaderboardRow> neighbors;
  final int? myRank;
  final int totalCount;
  final GlobalLeaderboardRow? me;

  const GlobalLeaderboardView({
    required this.top,
    required this.neighbors,
    required this.myRank,
    required this.totalCount,
    required this.me,
  });
}

/// Rang « Top ligues » (puissance = moyenne des points prono par membre).
///
/// Intentionnellement **sans** `code` : le classement public ne doit pas
/// exposer les codes d’invitation (rejoindre = saisie manuelle / partage).
class TopLeagueRow {
  final String id;
  final String name;
  final List<String> memberIds;
  final int memberCount;
  final int memberPointsSum;
  final double memberPointsAvg;

  const TopLeagueRow({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.memberCount,
    required this.memberPointsSum,
    required this.memberPointsAvg,
  });

  /// Moyenne affichée (1 décimale si besoin).
  String get memberPointsAvgLabel {
    final rounded = (memberPointsAvg * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return '${rounded.toInt()}';
    return rounded.toStringAsFixed(1);
  }
}

/// Bilan face-à-face agrégé depuis `prono_duels` (duels terminés).
class DuelRivalStat {
  final String opponentUid;
  final String opponentName;
  final int wins;
  final int losses;
  final int draws;

  const DuelRivalStat({
    required this.opponentUid,
    required this.opponentName,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  int get played => wins + losses + draws;

  /// Points « classement duel » : 3 par victoire, 1 par nul (comme le barème prono).
  int get duelPoints => wins * 3 + draws;
}

class LeagueHistoryPrediction {
  final String uid;
  final String displayName;
  final int score1Pred;
  final int score2Pred;
  final int? points;

  const LeagueHistoryPrediction({
    required this.uid,
    required this.displayName,
    required this.score1Pred,
    required this.score2Pred,
    required this.points,
  });
}

class LeagueHistoryMatch {
  final String matchId;
  final String team1;
  final String team2;
  final DateTime? matchDate;
  final List<LeagueHistoryPrediction> predictions;
  /// Score réel (même source que le prono saison / `matches`) si le match est noté.
  final int? resultScore1;
  final int? resultScore2;

  const LeagueHistoryMatch({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.matchDate,
    required this.predictions,
    this.resultScore1,
    this.resultScore2,
  });
}

class PronoSocialService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> _pushActivity({
    required String type,
    required String title,
    required String subtitle,
    required List<String> memberIds,
    String scope = 'social',
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _db.collection('prono_social_activity').add({
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'memberIds': memberIds,
        'scope': scope,
        'createdAt': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }

  static const Map<String, String> _defaultLevelLabels = {
    'recruit': 'Recrue',
    'fan': 'Fan',
    'supporter': 'Membre',
    'ultra': 'Ultra',
    'captain': 'Capitaine',
    'legend': 'Legende',
  };
  static const Map<String, int> _defaultXpRules = {
    'leaderboardPoint': 20,
    'predictionSubmitted': 5,
    'exactScoreBonus': 15,
    'goodResultBonus': 8,
    'duelXpUnit': 1,
    'duelWinBonus': 10,
  };
  static const int _defaultLevelStepXp = 120;

  static String currentUidOrEmpty() => _auth.currentUser?.uid ?? '';

  static String resolveDisplayName({
    Map<String, dynamic>? data,
    String? email,
    String fallback = 'Membre',
  }) {
    final firstName = (data?['firstName'] ?? '').toString().trim();
    final lastName = (data?['lastName'] ?? '').toString().trim();
    final displayName = (data?['displayName'] ?? '').toString().trim();
    final name = (data?['name'] ?? '').toString().trim();
    final pronoName =
        ((data?['pronoProfile'] as Map<String, dynamic>?)?['displayName'] ?? '')
            .toString()
            .trim();

    if (firstName.isNotEmpty) {
      return '$firstName${lastName.isNotEmpty ? ' ${lastName[0]}.' : ''}';
    }
    if (displayName.isNotEmpty) return displayName;
    if (name.isNotEmpty) return name;
    if (pronoName.isNotEmpty) return pronoName;
    final safeEmail = (email ?? data?['email'] ?? '').toString().trim();
    if (safeEmail.isNotEmpty) {
      return safeEmail.split('@').first;
    }
    return fallback;
  }

  static int xpFromStats(Map<String, dynamic>? data) {
    return xpFromStatsWithConfig(data);
  }

  /// Même source de vérité pour l’XP : stats classement + duels sur `users.pronoProfile`.
  static Map<String, dynamic> mergeLeaderboardAndPronoProfileForXp(
    Map<String, dynamic>? leaderboardRow,
    Map<String, dynamic>? userDocData,
  ) {
    final lb = Map<String, dynamic>.from(leaderboardRow ?? const {});
    final pp =
        (userDocData?['pronoProfile'] as Map<String, dynamic>?) ?? const {};
    int pick(String key) {
      final a = lb[key];
      if (a is num) return a.toInt();
      final b = pp[key];
      if (b is num) return b.toInt();
      return 0;
    }
    lb['duelXp'] = pick('duelXp');
    lb['duelWins'] = pick('duelWins');
    return lb;
  }

  static Map<String, int> defaultXpRules() =>
      Map<String, int>.from(_defaultXpRules);

  static Map<String, int> xpRules({Map<String, dynamic>? config}) {
    final raw = (config?['xpRules'] as Map<String, dynamic>?) ?? const {};
    return {
      ..._defaultXpRules,
      ...raw.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0)),
    };
  }

  static int levelStepXp({Map<String, dynamic>? config}) {
    return (config?['levelStepXp'] as num?)?.toInt() ?? _defaultLevelStepXp;
  }

  static int xpFromStatsWithConfig(
    Map<String, dynamic>? data, {
    Map<String, dynamic>? config,
  }) {
    final points = (data?['points'] as num?)?.toInt() ?? 0;
    final exact = (data?['exactScores'] as num?)?.toInt() ?? 0;
    final good = (data?['goodResults'] as num?)?.toInt() ?? 0;
    final total = (data?['totalPredictions'] as num?)?.toInt() ?? 0;
    final duelXp = (data?['duelXp'] as num?)?.toInt() ?? 0;
    final duelWins = (data?['duelWins'] as num?)?.toInt() ?? 0;
    final rules = xpRules(config: config);
    return (points * (rules['leaderboardPoint'] ?? 0)) +
        (total * (rules['predictionSubmitted'] ?? 0)) +
        (exact * (rules['exactScoreBonus'] ?? 0)) +
        (good * (rules['goodResultBonus'] ?? 0)) +
        (duelXp * (rules['duelXpUnit'] ?? 0)) +
        (duelWins * (rules['duelWinBonus'] ?? 0));
  }

  /// XP affiché partout : uniquement `users.xp` (système unifié global + prono).
  static int resolvedPronoDisplayXp({
    required Map<String, dynamic> mergedLeaderboardStats,
    Map<String, dynamic>? userDocData,
    Map<String, dynamic>? config,
  }) {
    return XpService.displayXp(userDocData);
  }

  static int levelFromStats(
    Map<String, dynamic>? data, {
    Map<String, dynamic>? config,
  }) {
    final xp = xpFromStatsWithConfig(data, config: config);
    final step = max(1, levelStepXp(config: config));
    return max(1, (xp / step).floor() + 1);
  }

  static String levelTierKey(int level) {
    if (level <= 1) return 'recruit';
    if (level <= 3) return 'fan';
    if (level <= 6) return 'supporter';
    if (level <= 10) return 'ultra';
    if (level <= 15) return 'captain';
    return 'legend';
  }

  static Map<String, String> defaultLevelLabels() =>
      Map<String, String>.from(_defaultLevelLabels);

  static String levelLabel(int level, {Map<String, dynamic>? config}) {
    final labels = {
      ..._defaultLevelLabels,
      ...((config?['levelLabels'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    };
    return labels[levelTierKey(level)] ?? _defaultLevelLabels['legend']!;
  }

  // ── Système de niveaux dynamiques (app_config/prono_social → levels) ────────

  /// Parse la liste Firestore `levels` (maps parfois typées `_Map<Object?,Object?>`).
  static List<Map<String, dynamic>> levelsListFromFirestore(dynamic raw) {
    if (raw is! List || raw.isEmpty) return [];
    final list = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        list.add(e);
      } else if (e is Map) {
        list.add(Map<String, dynamic>.from(e));
      }
    }
    list.sort(
      (a, b) => ((a['xpRequired'] as num?) ?? 0).compareTo(
        (b['xpRequired'] as num?) ?? 0,
      ),
    );
    return list;
  }

  /// Retourne la liste triée des niveaux personnalisés, ou vide si non définis.
  static List<Map<String, dynamic>> customLevels(Map<String, dynamic>? config) {
    return levelsListFromFirestore(config?['levels']);
  }

  /// Niveau depuis XP — délègue à [XpService] (`app_settings/xp_levels`).
  static int levelFromXp(int xp, {Map<String, dynamic>? config}) {
    return XpService.levelFromXp(xp, levels: XpService.parseLevels(config));
  }

  static String levelLabelFromXp(int xp, {Map<String, dynamic>? config}) {
    return XpService.levelLabelFromXp(
      xp,
      levels: XpService.parseLevels(config),
    );
  }

  static String? levelImageFromXp(int xp, {Map<String, dynamic>? config}) {
    return XpService.levelImageFromXp(
      xp,
      levels: XpService.parseLevels(config),
    );
  }

  static int? xpToNextLevel(int xp, {Map<String, dynamic>? config}) {
    return XpService.xpToNextLevel(
      xp,
      levels: XpService.parseLevels(config),
    );
  }

  static double progressInLevel(int xp, {Map<String, dynamic>? config}) {
    return XpService.progressInLevel(
      xp,
      levels: XpService.parseLevels(config),
    );
  }

  static double levelProgress(
    Map<String, dynamic>? data, {
    Map<String, dynamic>? config,
  }) {
    final xp = xpFromStatsWithConfig(data, config: config);
    final level = levelFromStats(data, config: config);
    final step = max(1, levelStepXp(config: config));
    final currentFloor = (level - 1) * step;
    return ((xp - currentFloor) / step).clamp(0, 1).toDouble();
  }

  static String levelImageUrl(String levelKey, {Map<String, dynamic>? config}) {
    return ((config?['levelVisuals'] as Map<String, dynamic>?)?[levelKey]
                as Map<String, dynamic>?)?['imageUrl']
            ?.toString() ??
        '';
  }

  static String levelImageUrlForLevel(
    int level, {
    Map<String, dynamic>? config,
  }) {
    return levelImageUrl(levelTierKey(level), config: config);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> pronoConfigStream() {
    return _db.collection('app_config').doc('prono_social').snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> leaderboardEntryStream(
    String uid,
  ) {
    return _db.collection('prono_leaderboard').doc(uid).snapshots();
  }

  static const int globalLeaderboardTopN = 20;

  /// Classement global : stream top [globalLeaderboardTopN], puis enrichit
  /// rang user + voisins (rank−1 / moi / rank+1) sans charger 1000 lignes.
  static Stream<GlobalLeaderboardView> watchGlobalLeaderboardWindow(
    String uid, {
    int topN = globalLeaderboardTopN,
  }) {
    return _db
        .collection('prono_leaderboard')
        .orderBy('points', descending: true)
        .limit(topN)
        .snapshots()
        .asyncMap((topSnap) => _buildGlobalLeaderboardView(
              uid: uid,
              topSnap: topSnap,
              topN: topN,
            ));
  }

  static int _compareLeaderboardRows(
    GlobalLeaderboardRow a,
    GlobalLeaderboardRow b,
  ) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    final byXi = b.perfectXiCount.compareTo(a.perfectXiCount);
    if (byXi != 0) return byXi;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  static GlobalLeaderboardRow _rowFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int rank,
  ) {
    final d = doc.data();
    return GlobalLeaderboardRow(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Membre').toString(),
      points: (d['points'] as num?)?.toInt() ?? 0,
      exactScores: (d['exactScores'] as num?)?.toInt() ?? 0,
      perfectXiCount: (d['perfectXiCount'] as num?)?.toInt() ?? 0,
      rank: rank,
    );
  }

  static GlobalLeaderboardRow _rowFromData(
    String id,
    Map<String, dynamic> d,
    int rank,
  ) {
    return GlobalLeaderboardRow(
      uid: id,
      displayName: (d['displayName'] ?? 'Membre').toString(),
      points: (d['points'] as num?)?.toInt() ?? 0,
      exactScores: (d['exactScores'] as num?)?.toInt() ?? 0,
      perfectXiCount: (d['perfectXiCount'] as num?)?.toInt() ?? 0,
      rank: rank,
    );
  }

  static Future<GlobalLeaderboardView> _buildGlobalLeaderboardView({
    required String uid,
    required QuerySnapshot<Map<String, dynamic>> topSnap,
    required int topN,
  }) async {
    final top = <GlobalLeaderboardRow>[];
    for (var i = 0; i < topSnap.docs.length; i++) {
      top.add(_rowFromDoc(topSnap.docs[i], i + 1));
    }
    top.sort(_compareLeaderboardRows);
    for (var i = 0; i < top.length; i++) {
      final r = top[i];
      top[i] = GlobalLeaderboardRow(
        uid: r.uid,
        displayName: r.displayName,
        points: r.points,
        exactScores: r.exactScores,
        perfectXiCount: r.perfectXiCount,
        rank: i + 1,
      );
    }

    final totalAgg =
        await _db.collection('prono_leaderboard').count().get();
    final totalCount = totalAgg.count ?? top.length;

    final myDoc = await _db.collection('prono_leaderboard').doc(uid).get();
    if (!myDoc.exists || myDoc.data() == null) {
      return GlobalLeaderboardView(
        top: top,
        neighbors: const [],
        myRank: null,
        totalCount: totalCount,
        me: null,
      );
    }

    final myData = myDoc.data()!;
    final topIndex = topSnap.docs.indexWhere((d) => d.id == uid);
    if (topIndex >= 0) {
      final me = top[topIndex];
      return GlobalLeaderboardView(
        top: top,
        neighbors: const [],
        myRank: topIndex + 1,
        totalCount: totalCount,
        me: me,
      );
    }

    final myPoints = (myData['points'] as num?)?.toInt() ?? 0;

    // Rang compétition : 1 + nb de joueurs strictement meilleurs en points.
    final betterAgg = await _db
        .collection('prono_leaderboard')
        .where('points', isGreaterThan: myPoints)
        .count()
        .get();
    final myRank = (betterAgg.count ?? 0) + 1;

    final neighbors = <GlobalLeaderboardRow>[];

    // Voisin au-dessus (points juste supérieurs).
    final aboveSnap = await _db
        .collection('prono_leaderboard')
        .where('points', isGreaterThan: myPoints)
        .orderBy('points')
        .limit(1)
        .get();
    if (aboveSnap.docs.isNotEmpty) {
      final aboveRank = myRank - 1;
      // N’affiche le voisin que s’il n’est pas déjà dans le top.
      if (aboveRank > topN) {
        neighbors.add(_rowFromDoc(aboveSnap.docs.first, aboveRank));
      }
    }

    neighbors.add(_rowFromData(uid, myData, myRank));

    // Voisin en-dessous (points juste inférieurs).
    final belowSnap = await _db
        .collection('prono_leaderboard')
        .where('points', isLessThan: myPoints)
        .orderBy('points', descending: true)
        .limit(1)
        .get();
    if (belowSnap.docs.isNotEmpty) {
      neighbors.add(_rowFromDoc(belowSnap.docs.first, myRank + 1));
    }

    return GlobalLeaderboardView(
      top: top,
      neighbors: neighbors,
      myRank: myRank,
      totalCount: totalCount,
      me: _rowFromData(uid, myData, myRank),
    );
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(
    String uid,
  ) {
    return _db.collection('users').doc(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> leaguesForUser(
    String uid,
  ) {
    return _db
        .collection('private_leagues')
        .where('memberIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> friendRequestsForUser(
    String uid,
  ) {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> sentFriendRequestsForUser(
    String uid,
  ) {
    return _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> duelsForUser(String uid) {
    return _db
        .collection('prono_duels')
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> duelStream(
    String duelId,
  ) {
    return _db.collection('prono_duels').doc(duelId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> leagueMembersStream(
    String leagueId,
  ) {
    return _db
        .collection('private_leagues')
        .doc(leagueId)
        .collection('events')
        .snapshots();
  }

  static Stream<List<PronoPopularPick>> popularPickStream(String matchId) {
    return _db
        .collection('predictions')
        .where('matchId', isEqualTo: matchId)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return const <PronoPopularPick>[];
          final counts = <String, int>{};
          for (final doc in snap.docs) {
            final data = doc.data();
            final label =
                '${data['score1Pred'] ?? 0}-${data['score2Pred'] ?? 0}';
            counts[label] = (counts[label] ?? 0) + 1;
          }
          final total = snap.docs.length;
          final entries = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return entries.take(3).map((entry) {
            return PronoPopularPick(
              label: entry.key,
              votes: entry.value,
              share: entry.value / total,
            );
          }).toList();
        });
  }

  static Future<void> syncUserPronoProfile({
    required String uid,
    required String displayName,
  }) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'pronoProfile': {
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    // Index de recherche ami (collection publique) — indépendant du scoring.
    await ensureSearchablePronoProfile(uid: uid, displayName: displayName);
  }

  /// Upsert `prono_leaderboard/{uid}` pour le classement (identité affichée).
  /// La recherche d’amis passe par `searchUsersForFriends` (collection `users`).
  static Future<void> ensureSearchablePronoProfile({
    required String uid,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (uid.isEmpty || name.isEmpty) return;
    final lower = name.toLowerCase();
    final ref = _db.collection('prono_leaderboard').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': uid,
        'displayName': name,
        'displayNameLower': lower,
        'points': 0,
        'exactScores': 0,
        'goodResults': 0,
        'totalPredictions': 0,
        'perfectXiCount': 0,
        'pronoStreak': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    final data = snap.data() ?? const <String, dynamic>{};
    final current = (data['displayName'] ?? '').toString();
    final currentLower = (data['displayNameLower'] ?? '').toString();
    if (current == name && currentLower == lower) return;
    await ref.set({
      'uid': uid,
      'displayName': name,
      'displayNameLower': lower,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> registerPrediction({
    required String uid,
    required String displayName,
    required bool isNewPrediction,
  }) async {
    await syncUserPronoProfile(uid: uid, displayName: displayName);
    final updates = <String, dynamic>{
      'pronoProfile.lastPredictionAt': FieldValue.serverTimestamp(),
      'pronoProfile.displayName': displayName,
    };
    if (isNewPrediction) {
      updates['pronoProfile.totalPredictionsSubmitted'] = FieldValue.increment(
        1,
      );
    }
    await _db
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  /// Clé normalisée pour dédoublonner les noms de ligues (trim + casse).
  static String leagueNameKey(String name) {
    return name.trim().toLowerCase();
  }

  static Future<bool> isLeagueNameTaken(String name) async {
    final key = leagueNameKey(name);
    if (key.isEmpty) return false;
    final snap = await _db
        .collection('private_leagues')
        .where('nameKey', isEqualTo: key)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Crée une ligue. Retourne le code invitation, ou `null` si le nom est déjà pris.
  ///
  /// Initialise `rankingStats` (moyenne points `prono_leaderboard` par membre).
  static Future<String?> createLeague({
    required String ownerUid,
    required String ownerName,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final nameKey = leagueNameKey(trimmed);
    if (await isLeagueNameTaken(trimmed)) {
      return null;
    }
    final code = _leagueCode();
    final ref = _db.collection('private_leagues').doc();
    final ownerPoints = await _leaderboardPointsForUid(ownerUid);
    await ref.set({
      'id': ref.id,
      'name': trimmed,
      'nameKey': nameKey,
      'code': code,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'memberIds': [ownerUid],
      'memberNames': [ownerName],
      'memberCount': 1,
      'rankingStats': {
        'memberPointsSum': ownerPoints,
        'memberPointsAvg': ownerPoints,
        'memberCount': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _pushActivity(
      type: 'league_created',
      title: '$ownerName a créé une ligue',
      subtitle: trimmed,
      memberIds: [ownerUid],
      extra: {'leagueId': ref.id, 'leagueName': trimmed},
    );
    return code;
  }

  static Future<int> _leaderboardPointsForUid(String uid) async {
    if (uid.isEmpty) return 0;
    try {
      final snap = await _db.collection('prono_leaderboard').doc(uid).get();
      return (snap.data()?['points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _sumMemberLeaderboardPoints(List<String> memberIds) async {
    var sum = 0;
    for (var i = 0; i < memberIds.length; i += 10) {
      final end = i + 10 > memberIds.length ? memberIds.length : i + 10;
      final chunk = memberIds.sublist(i, end);
      if (chunk.isEmpty) continue;
      final snap = await _db
          .collection('prono_leaderboard')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        sum += (doc.data()['points'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  static Future<bool> joinLeague({
    required String uid,
    required String displayName,
    required String code,
  }) async {
    final snap = await _db
        .collection('private_leagues')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;
    final ref = snap.docs.first.reference;
    await ref.set({
      'memberIds': FieldValue.arrayUnion([uid]),
      'memberNames': FieldValue.arrayUnion([displayName]),
      'memberCount':
          snap.docs.first.data()['memberIds'] is List &&
              (snap.docs.first.data()['memberIds'] as List).contains(uid)
          ? snap.docs.first.data()['memberCount'] ?? 1
          : FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final league = snap.docs.first.data();
    final memberIds =
        (league['memberIds'] as List?)?.whereType<String>().toList() ??
        <String>[uid];
    await _pushActivity(
      type: 'league_joined',
      title: '$displayName a rejoint une ligue',
      subtitle: (league['name'] ?? 'Ligue privee').toString(),
      memberIds: {...memberIds, uid}.toList(),
      extra: {
        'leagueId': snap.docs.first.id,
        'leagueName': (league['name'] ?? 'Ligue privee').toString(),
      },
    );
    return true;
  }

  static Future<void> deleteLeague({
    required String leagueId,
    required String ownerUid,
  }) async {
    final ref = _db.collection('private_leagues').doc(leagueId);
    final snap = await ref.get();
    if (!snap.exists) return;
    if ((snap.data()?['ownerUid'] ?? '') != ownerUid) return;
    await ref.delete();
  }

  /// Suppression modération (Firestore : `isAdmin()` sur `private_leagues`).
  static Future<void> adminDeleteLeague(String leagueId) async {
    await _db.collection('private_leagues').doc(leagueId).delete();
  }

  /// Tous les duels récents (lecture `isAuth()`), tri par `createdAt`.
  static Stream<QuerySnapshot<Map<String, dynamic>>> allDuelsStream({
    int limit = 200,
  }) {
    return _db
        .collection('prono_duels')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Toutes les ligues récentes, tri par `updatedAt`.
  static Stream<QuerySnapshot<Map<String, dynamic>>> allLeaguesStream({
    int limit = 200,
  }) {
    return _db
        .collection('private_leagues')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Supprime les `duel_picks` puis le document duel (Firestore : admin sur les deux).
  static Future<void> adminDeleteDuel(String duelId) async {
    final picksRef =
        _db.collection('prono_duels').doc(duelId).collection('duel_picks');
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await picksRef.limit(400).get();
      if (snap.docs.isEmpty) break;
      var batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } while (snap.docs.length >= 400);
    await _db.collection('prono_duels').doc(duelId).delete();
  }

  static Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
  }) async {
    if (fromUid == toUid) return;
    final existing = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _db.collection('friend_requests').add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _pushActivity(
      type: 'friend_request',
      title: '$fromName a envoyé une invitation',
      subtitle: 'Invitation pour $toName',
      memberIds: [fromUid, toUid],
      extra: {'fromUid': fromUid, 'toUid': toUid},
    );
  }

  static Future<void> acceptFriendRequest({
    required String requestId,
    required String currentUid,
    required String currentName,
    required String otherUid,
    required String otherName,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(currentUid), {
      'social': {
        'friends': FieldValue.arrayUnion([otherUid]),
        'friendNames': {otherUid: otherName},
      },
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(otherUid), {
      'social': {
        'friends': FieldValue.arrayUnion([currentUid]),
        'friendNames': {currentUid: currentName},
      },
    }, SetOptions(merge: true));
    batch.update(_db.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _pushActivity(
      type: 'friend_accepted',
      title: '$currentName et $otherName sont maintenant amis',
      subtitle: 'Le reseau DVCR s agrandit.',
      memberIds: [currentUid, otherUid],
      extra: {'requestId': requestId},
    );
  }

  static Future<void> declineFriendRequest({required String requestId}) async {
    await _db.collection('friend_requests').doc(requestId).set({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> removeFriend({
    required String currentUid,
    required String otherUid,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(currentUid), {
      'social': {
        'friends': FieldValue.arrayRemove([otherUid]),
        'friendNames': {otherUid: FieldValue.delete()},
      },
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(otherUid), {
      'social': {
        'friends': FieldValue.arrayRemove([currentUid]),
        'friendNames': {currentUid: FieldValue.delete()},
      },
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Crée un duel et retourne l’id du document (picks séparés : sous-collection `duel_picks`).
  static Future<String> createDuel({
    required String ownerUid,
    required String ownerName,
    required String opponentUid,
    required String opponentName,
    required String matchId,
    required String matchLabel,
  }) async {
    final ref = _db.collection('prono_duels').doc();
    await ref.set({
      'duelLabel': '$ownerName vs $opponentName',
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'opponentUid': opponentUid,
      'opponentName': opponentName,
      'participantIds': [ownerUid, opponentUid],
      'matchId': matchId,
      'matchLabel': matchLabel,
      'status': 'pending',
      'winnerUid': null,
      'winnerName': null,
      'ownerPoints': null,
      'opponentPoints': null,
      'duelXpReward': 3,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _pushActivity(
      type: 'duel_created',
      title: '$ownerName a lancé un duel',
      subtitle: '$matchLabel contre $opponentName',
      memberIds: [ownerUid, opponentUid],
      extra: {'matchId': matchId, 'duelId': ref.id},
    );
    return ref.id;
  }

  /// Score « fun » réservé au duel (0–99), indépendant du prono championnat.
  static Future<void> saveDuelPick({
    required String duelId,
    required String uid,
    required int score1,
    required int score2,
  }) async {
    final s1 = score1.clamp(0, 99);
    final s2 = score2.clamp(0, 99);
    await _db
        .collection('prono_duels')
        .doc(duelId)
        .collection('duel_picks')
        .doc(uid)
        .set({
      'score1': s1,
      'score2': s2,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<Map<String, Map<String, dynamic>>> duelPicksStream(
    String duelId,
  ) {
    return _db
        .collection('prono_duels')
        .doc(duelId)
        .collection('duel_picks')
        .snapshots()
        .map((snap) {
      final out = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        out[d.id] = d.data();
      }
      return out;
    });
  }

  static Future<void> acceptDuel({required String duelId}) async {
    final ref = _db.collection('prono_duels').doc(duelId);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    await ref.update({
      'status': 'in_progress',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    final ownerUid = (data['ownerUid'] ?? '').toString();
    final opponentUid = (data['opponentUid'] ?? '').toString();
    await _pushActivity(
      type: 'duel_accepted',
      title: 'Duel accepte',
      subtitle: (data['matchLabel'] ?? 'Le duel peut commencer').toString(),
      memberIds: [ownerUid, opponentUid].where((id) => id.isNotEmpty).toList(),
      extra: {'duelId': duelId},
    );
  }

  static Future<void> declineDuel({required String duelId}) async {
    await _db.collection('prono_duels').doc(duelId).update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> cancelDuel({
    required String duelId,
    required String ownerUid,
  }) async {
    final ref = _db.collection('prono_duels').doc(duelId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if ((data['ownerUid'] ?? '') != ownerUid) return;
    await ref.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<LeagueStandingEntry>> leagueLeaderboard(
    List<dynamic> memberIds,
  ) async {
    final ids = memberIds.whereType<String>().toList();
    if (ids.isEmpty) return const [];

    final entries = <LeagueStandingEntry>[];
    final added = <String>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, min(i + 10, ids.length));
      final snap = await _db
          .collection('prono_leaderboard')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        added.add(doc.id);
        entries.add(
          LeagueStandingEntry(
            uid: doc.id,
            displayName: (d['displayName'] ?? 'Membre').toString(),
            points: (d['points'] as num?)?.toInt() ?? 0,
            exactScores: (d['exactScores'] as num?)?.toInt() ?? 0,
            goodResults: (d['goodResults'] as num?)?.toInt() ?? 0,
            totalPredictions: (d['totalPredictions'] as num?)?.toInt() ?? 0,
            perfectXiCount: (d['perfectXiCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    for (final uid in ids.where((id) => !added.contains(id))) {
      entries.add(
        LeagueStandingEntry(
          uid: uid,
          displayName: 'Membre',
          points: 0,
          exactScores: 0,
          goodResults: 0,
          totalPredictions: 0,
          perfectXiCount: 0,
        ),
      );
    }
    entries.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byXi = b.perfectXiCount.compareTo(a.perfectXiCount);
      if (byXi != 0) return byXi;
      return a.displayName.compareTo(b.displayName);
    });
    return entries;
  }

  static const _scoredPronoPoints = [0, 1, 3];

  static Future<Map<String, String>> _displayNamesFromLeaderboard(
    List<String> ids, {
    Map<String, int>? perfectXiOut,
  }) async {
    final names = <String, String>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, min(i + 10, ids.length));
      final snap = await _db
          .collection('prono_leaderboard')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        names[doc.id] = (d['displayName'] ?? 'Membre').toString();
        if (perfectXiOut != null) {
          perfectXiOut[doc.id] = (d['perfectXiCount'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return names;
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _scoredPredictionsForUid(
    String uid,
  ) {
    return _db
        .collection('predictions')
        .where('uid', isEqualTo: uid)
        .where('points', whereIn: _scoredPronoPoints)
        .get();
  }

  static Future<List<LeagueHistoryMatch>> leagueHistory(
    List<dynamic> memberIds, {
    int limit = 8,
  }) async {
    final ids = memberIds.whereType<String>().toList();
    if (ids.isEmpty) return const [];

    final userNames = await _displayNamesFromLeaderboard(ids);

    final grouped = <String, List<LeagueHistoryPrediction>>{};
    final matchMeta = <String, Map<String, dynamic>>{};

    for (final uid in ids) {
      final snap = await _scoredPredictionsForUid(uid);

      for (final doc in snap.docs) {
        final data = doc.data();
        final matchId = (data['matchId'] ?? '').toString();
        if (matchId.isEmpty) continue;

        grouped.putIfAbsent(matchId, () => <LeagueHistoryPrediction>[]);
        grouped[matchId]!.add(
          LeagueHistoryPrediction(
            uid: uid,
            displayName: (data['displayName'] ?? userNames[uid] ?? 'Membre')
                .toString(),
            score1Pred: (data['score1Pred'] as num?)?.toInt() ?? 0,
            score2Pred: (data['score2Pred'] as num?)?.toInt() ?? 0,
            points: (data['points'] as num?)?.toInt(),
          ),
        );

        matchMeta[matchId] = {
          'team1': (data['team1'] ?? 'Équipe 1').toString(),
          'team2': (data['team2'] ?? 'Equipe 2').toString(),
          'matchDate': (data['matchDate'] as Timestamp?)?.toDate(),
        };
      }
    }

    final history =
        grouped.entries.map((entry) {
          final meta = matchMeta[entry.key] ?? const <String, dynamic>{};
          final predictions = [...entry.value]
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
          return LeagueHistoryMatch(
            matchId: entry.key,
            team1: (meta['team1'] ?? 'Équipe 1').toString(),
            team2: (meta['team2'] ?? 'Equipe 2').toString(),
            matchDate: meta['matchDate'] as DateTime?,
            predictions: predictions,
          );
        }).toList()..sort((a, b) {
          final ad = a.matchDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.matchDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

    final trimmed = history.take(limit).toList();
    final matchIds = trimmed.map((m) => m.matchId).toSet().toList();
    final scoreById = <String, (int?, int?)>{};
    for (var i = 0; i < matchIds.length; i += 10) {
      final chunk = matchIds.sublist(i, min(i + 10, matchIds.length));
      final snap = await _db
          .collection('matches')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final s1 = MatchModel.parseScoreField(d['score1'] ?? d['homeScore']);
        final s2 = MatchModel.parseScoreField(d['score2'] ?? d['awayScore']);
        scoreById[doc.id] = (s1, s2);
      }
    }

    return trimmed
        .map(
          (m) => LeagueHistoryMatch(
            matchId: m.matchId,
            team1: m.team1,
            team2: m.team2,
            matchDate: m.matchDate,
            predictions: m.predictions,
            resultScore1: scoreById[m.matchId]?.$1,
            resultScore2: scoreById[m.matchId]?.$2,
          ),
        )
        .toList();
  }

  /// Classement ligue filtré : sedanOnly=true → pronos Sedan uniquement
  static Future<List<LeagueStandingEntry>> leagueLeaderboardFiltered(
    List<dynamic> memberIds, {
    bool sedanOnly = false,
  }) async {
    if (!sedanOnly) return leagueLeaderboard(memberIds);

    final ids = memberIds.whereType<String>().toList();
    if (ids.isEmpty) return const [];

    final xiByUid = <String, int>{};
    final userNames = await _displayNamesFromLeaderboard(
      ids,
      perfectXiOut: xiByUid,
    );

    final totals = <String, Map<String, int>>{};
    for (final uid in ids) {
      totals[uid] = {
        'points': 0,
        'exactScores': 0,
        'goodResults': 0,
        'totalPredictions': 0,
      };
    }

    for (final uid in ids) {
      final snap = await _scoredPredictionsForUid(uid);
      for (final doc in snap.docs) {
        final data = doc.data();
        final t1 = (data['team1'] ?? '').toString().toUpperCase();
        final t2 = (data['team2'] ?? '').toString().toUpperCase();
        if (!t1.contains('SEDAN') && !t2.contains('SEDAN')) continue;
        final pts = (data['points'] as num?)?.toInt() ?? 0;
        totals[uid]!['totalPredictions'] =
            totals[uid]!['totalPredictions']! + 1;
        totals[uid]!['points'] = totals[uid]!['points']! + pts;
        if (pts >= 3)
          totals[uid]!['exactScores'] = totals[uid]!['exactScores']! + 1;
        else if (pts >= 1)
          totals[uid]!['goodResults'] = totals[uid]!['goodResults']! + 1;
      }
    }

    final entries =
        ids.map((uid) {
          final t = totals[uid]!;
          return LeagueStandingEntry(
            uid: uid,
            displayName: userNames[uid] ?? 'Membre',
            points: t['points']!,
            exactScores: t['exactScores']!,
            goodResults: t['goodResults']!,
            totalPredictions: t['totalPredictions']!,
            perfectXiCount: xiByUid[uid] ?? 0,
          );
        }).toList()..sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          final byXi = b.perfectXiCount.compareTo(a.perfectXiCount);
          if (byXi != 0) return byXi;
          return a.displayName.compareTo(b.displayName);
        });

    return entries;
  }

  /// Duels `won` / `draw` uniquement ; groupe par adversaire.
  static Future<List<DuelRivalStat>> duelRivalStats(String uid) async {
    final snap = await _db
        .collection('prono_duels')
        .where('participantIds', arrayContains: uid)
        .limit(300)
        .get();
    final map = <String, _DuelRivalAgg>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString();
      if (status != 'won' && status != 'draw') continue;
      final owner = (d['ownerUid'] ?? '').toString();
      final oppUid = (d['opponentUid'] ?? '').toString();
      if (owner.isEmpty || oppUid.isEmpty) continue;
      final isOwner = owner == uid;
      final otherUid = isOwner ? oppUid : owner;
      final otherName = isOwner
          ? (d['opponentName'] ?? 'Joueur').toString()
          : (d['ownerName'] ?? 'Joueur').toString();
      final agg = map.putIfAbsent(otherUid, () => _DuelRivalAgg(otherName));
      final winner = (d['winnerUid'] ?? '').toString();
      if (status == 'draw') {
        agg.draws++;
      } else if (winner == uid) {
        agg.wins++;
      } else if (winner.isNotEmpty) {
        agg.losses++;
      }
    }
    final list = map.entries
        .map(
          (e) => DuelRivalStat(
            opponentUid: e.key,
            opponentName: e.value.name,
            wins: e.value.wins,
            losses: e.value.losses,
            draws: e.value.draws,
          ),
        )
        .toList();
    list.sort((a, b) {
      final byPts = b.duelPoints.compareTo(a.duelPoints);
      if (byPts != 0) return byPts;
      final byWins = b.wins.compareTo(a.wins);
      if (byWins != 0) return byWins;
      return a.opponentName.compareTo(b.opponentName);
    });
    return list;
  }

  /// Même agrégat que [duelRivalStats], limité aux **amis confirmés** (`users.social.friends`).
  static Future<List<DuelRivalStat>> duelRivalStatsAmongFriends(
    String uid,
  ) async {
    final userSnap = await _db.collection('users').doc(uid).get();
    final social =
        (userSnap.data()?['social'] as Map<String, dynamic>?) ?? const {};
    final friendIds =
        (social['friends'] as List?)?.whereType<String>().toSet() ?? {};
    final all = await duelRivalStats(uid);
    if (friendIds.isEmpty) return const [];
    return all.where((r) => friendIds.contains(r.opponentUid)).toList();
  }

  /// Ligues triées par moyenne de points `prono_leaderboard` par membre.
  ///
  /// Préfère `rankingStats.memberPointsAvg` (CF / create). Si le champ manque,
  /// calcule somme ÷ effectif (éventuellement à la volée depuis le leaderboard).
  static Stream<List<TopLeagueRow>> topLeaguesByMemberPointsStream({
    int limit = 25,
  }) {
    return _db
        .collection('private_leagues')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snap) async {
          final rows = <TopLeagueRow>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final memberIds =
                (data['memberIds'] as List?)?.whereType<String>().toList() ??
                    const <String>[];
            final stats =
                (data['rankingStats'] as Map<String, dynamic>?) ?? const {};
            final sumRaw = stats['memberPointsSum'];
            final avgRaw = stats['memberPointsAvg'];
            final members = (stats['memberCount'] as num?)?.toInt() ??
                (data['memberCount'] as num?)?.toInt() ??
                memberIds.length;
            final int sum;
            if (sumRaw is num) {
              sum = sumRaw.toInt();
            } else {
              sum = await _sumMemberLeaderboardPoints(memberIds);
            }
            final double avg;
            if (avgRaw is num) {
              avg = avgRaw.toDouble();
            } else if (members > 0) {
              avg = sum / members;
            } else {
              avg = 0;
            }
            // Strip `code` : ne jamais le propager dans le modèle Top ligues
            // (le doc Firestore le contient encore — voir TOP_LEAGUES_HIDE_CODES.md).
            rows.add(
              TopLeagueRow(
                id: doc.id,
                name: (data['name'] ?? 'Ligue').toString(),
                memberIds: memberIds,
                memberCount: members,
                memberPointsSum: sum,
                memberPointsAvg: avg,
              ),
            );
          }
          rows.sort((a, b) {
            final byAvg = b.memberPointsAvg.compareTo(a.memberPointsAvg);
            if (byAvg != 0) return byAvg;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          if (rows.length <= limit) return rows;
          return rows.sublist(0, limit);
        });
  }

  /// Recherche d’amis / admin : **tous les inscrits** via Cloud Function
  /// `searchUsersForFriends` (Admin SDK sur `users`).
  ///
  /// - Pseudo / prénom / nom : préfixe (insensible à la casse)
  /// - Email : correspondance **exacte** (l’email n’est jamais renvoyé au client)
  ///
  /// `users` reste privée côté rules — pas de scan client des emails.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final cleaned = query.trim();
    if (cleaned.length < 2) return const [];

    final result = await FirebaseFunctions.instance
        .httpsCallable('searchUsersForFriends')
        .call(<String, dynamic>{'query': cleaned});

    final raw = result.data;
    final list = raw is Map ? raw['users'] : null;
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((row) {
          final m = Map<String, dynamic>.from(row);
          return <String, dynamic>{
            'uid': (m['uid'] ?? '').toString(),
            'displayName': m['displayName'],
            'firstName': m['firstName'],
            'lastName': m['lastName'],
          };
        })
        .where((m) => (m['uid'] as String).isNotEmpty)
        .toList();
  }

  /// Recherche admin : ligues dont le nom contient [needle] (scan des [fetchCap] dernières MAJ).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      adminSearchLeaguesByName(
    String query, {
    int fetchCap = 400,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.length < 2) return const [];
    final snap = await _db
        .collection('private_leagues')
        .orderBy('updatedAt', descending: true)
        .limit(fetchCap)
        .get();
    return snap.docs.where((d) {
      final m = d.data();
      final n = (m['name'] ?? '').toString().toLowerCase();
      final nk = (m['nameKey'] ?? '').toString().toLowerCase();
      return n.contains(needle) || (nk.isNotEmpty && nk.contains(needle));
    }).toList();
  }

  static String _leagueCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  /// Derniers pronos **déjà scorés** (0 / 1 / 3 pts), tri par résolution.
  static Future<List<RecentPronoRow>> recentResolvedSeasonPredictions(
    String uid, {
    int limit = 10,
  }) async {
    final snap =
        await _db.collection('predictions').where('uid', isEqualTo: uid).get();
    final rough = <RecentPronoRow>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final pts = (d['points'] as num?)?.toInt();
      if (pts == null || pts < 0 || pts > 3) continue;
      final matchId = (d['matchId'] ?? '').toString();
      if (matchId.isEmpty) continue;
      DateTime ord;
      final r = d['resolvedAt'];
      if (r is Timestamp) {
        ord = r.toDate();
      } else {
        final u = d['updatedAt'];
        ord = u is Timestamp ? u.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      }
      rough.add(
        RecentPronoRow(
          matchId: matchId,
          team1: (d['team1'] ?? 'Équipe 1').toString(),
          team2: (d['team2'] ?? 'Équipe 2').toString(),
          orderDate: ord,
          predHome: (d['score1Pred'] as num?)?.toInt() ?? 0,
          predAway: (d['score2Pred'] as num?)?.toInt() ?? 0,
          resHome: null,
          resAway: null,
          pronoPoints: pts,
        ),
      );
    }
    rough.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final sliced =
        rough.length > limit ? rough.sublist(0, limit) : List<RecentPronoRow>.from(rough);
    final ids = sliced.map((e) => e.matchId).toList();
    final scoreById = <String, (int?, int?)>{};
    for (var i = 0; i < ids.length; i += 10) {
      final end = min(i + 10, ids.length);
      if (end <= i) break;
      final chunk = ids.sublist(i, end);
      final ms = await _db
          .collection('matches')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in ms.docs) {
        final md = doc.data();
        final s1 = MatchModel.parseScoreField(md['score1'] ?? md['homeScore']);
        final s2 = MatchModel.parseScoreField(md['score2'] ?? md['awayScore']);
        scoreById[doc.id] = (s1, s2);
      }
    }
    return [
      for (final e in sliced)
        RecentPronoRow(
          matchId: e.matchId,
          team1: e.team1,
          team2: e.team2,
          orderDate: e.orderDate,
          predHome: e.predHome,
          predAway: e.predAway,
          resHome: scoreById[e.matchId]?.$1,
          resAway: scoreById[e.matchId]?.$2,
          pronoPoints: e.pronoPoints,
        ),
    ];
  }
}

class _DuelRivalAgg {
  final String name;
  int wins = 0;
  int losses = 0;
  int draws = 0;
  _DuelRivalAgg(this.name);
}
