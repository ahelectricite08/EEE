import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tournament_service.dart';

// ── Modèles ───────────────────────────────────────────────────────────────────
class EstiDvcrLeagueTopScore {
  final EstiDvcrLeague league;
  /// Score moyen des membres (points totaux ÷ nb membres) — équitable quelle que soit la taille.
  final double avgScore;
  const EstiDvcrLeagueTopScore({required this.league, required this.avgScore});
}

class EstiDvcrLeague {
  final String id;
  final String name;
  final String code;
  final String createdBy;
  final int memberCount;

  const EstiDvcrLeague({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    required this.memberCount,
  });

  factory EstiDvcrLeague.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EstiDvcrLeague(
      id: doc.id,
      name: d['name'] as String? ?? '',
      code: d['code'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
class EstiDvcrLeagueService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _leagues =>
      _db.collection('esti_dvcr_leagues');

  // ── Noms réservés (insensible à la casse + accents) ──────────────────────
  static const _kReservedNames = [
    'drapeau vert',
    'drapeauvert',
    'carton rouge',
    'cartonrouge',
  ];

  static void _checkReservedName(String name) {
    final normalized = name.trim().toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u');
    final compact = normalized.replaceAll(' ', '');
    for (final reserved in _kReservedNames) {
      if (normalized == reserved || compact == reserved.replaceAll(' ', '')) {
        throw Exception('Ce nom est réservé et ne peut pas être utilisé.');
      }
    }
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Vérifie si l'utilisateur est déjà dans une ligue ─────────────────────
  static Future<bool> isAlreadyInLeague() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _leagues
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Créer ─────────────────────────────────────────────────────────────────
  static Future<EstiDvcrLeague> createLeague({
    required String name,
    required String tournamentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');
    if (await isAlreadyInLeague()) {
      throw Exception('Tu fais déjà partie d\'une ligue. Quitte-la avant d\'en créer une nouvelle.');
    }
    _checkReservedName(name);

    String code = _generateCode();
    for (var i = 0; i < 5; i++) {
      final existing = await _leagues.where('code', isEqualTo: code).limit(1).get();
      if (existing.docs.isEmpty) break;
      code = _generateCode();
    }

    final docRef = _leagues.doc();
    await docRef.set({
      'name': name.trim(),
      'code': code,
      'createdBy': user.uid,
      'tournamentId': tournamentId,
      'memberCount': 1,
      // Tableau des UIDs membres — permet de requêter sans collectionGroup
      'memberUids': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Sous-collection pour les détails (displayName, joinedAt)
    await docRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName ?? 'Membre',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return EstiDvcrLeague(
      id: docRef.id,
      name: name.trim(),
      code: code,
      createdBy: user.uid,
      memberCount: 1,
    );
  }

  // ── Rejoindre ─────────────────────────────────────────────────────────────
  static Future<EstiDvcrLeague> joinLeague(String rawCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');
    final code = rawCode.trim().toUpperCase();

    if (await isAlreadyInLeague()) {
      throw Exception('Tu fais déjà partie d\'une ligue. Quitte-la avant d\'en rejoindre une autre.');
    }
    final snap = await _leagues.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) throw Exception('Code invalide — vérifie et réessaie.');

    final leagueDoc = snap.docs.first;
    final memberRef = leagueDoc.reference.collection('members').doc(user.uid);
    final existing = await memberRef.get();
    if (!existing.exists) {
      await memberRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Membre',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await leagueDoc.reference.update({
        'memberCount': FieldValue.increment(1),
        'memberUids': FieldValue.arrayUnion([user.uid]),
      });
    }
    return EstiDvcrLeague.fromDoc(leagueDoc);
  }

  // ── Quitter ───────────────────────────────────────────────────────────────
  static Future<void> leaveLeague(String leagueId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final leagueRef = _leagues.doc(leagueId);
    await leagueRef.collection('members').doc(uid).delete();
    await leagueRef.update({
      'memberCount': FieldValue.increment(-1),
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  // ── Mes ligues (stream) ───────────────────────────────────────────────────
  /// Utilise arrayContains sur `memberUids` — pas besoin d'index composite.
  static Stream<List<EstiDvcrLeague>> myLeaguesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _leagues
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final leagues = snap.docs.map(EstiDvcrLeague.fromDoc).toList();
      leagues.sort((a, b) => a.name.compareTo(b.name));
      return leagues;
    });
  }

  // ── Top ligues pour l'affichage dans CLASSEMENT ───────────────────────────
  /// Retourne toutes les ligues avec le meilleur score parmi leurs membres.
  static Future<List<EstiDvcrLeagueTopScore>> getTopLeagues(
    String tournamentId,
  ) async {
    // 1. Récupérer toutes les ligues (max 50)
    final leaguesSnap = await _leagues.limit(50).get();
    if (leaguesSnap.docs.isEmpty) return [];

    // 2. Récupérer le leaderboard du tournoi une seule fois
    final lbSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('leaderboard')
        .orderBy('points', descending: true)
        .get();

    final lbByUid = {
      for (final d in lbSnap.docs)
        d.id: (d.data()['points'] as num?)?.toInt() ?? 0,
    };

    // 3. Pour chaque ligue, calculer le score MOYEN des membres (équitable quelle que soit la taille)
    final result = <EstiDvcrLeagueTopScore>[];
    for (final doc in leaguesSnap.docs) {
      final league = EstiDvcrLeague.fromDoc(doc);
      final d = doc.data();
      final memberUids = (d['memberUids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (memberUids.isEmpty) continue;
      int total = 0;
      for (final uid in memberUids) {
        total += lbByUid[uid] ?? 0;
      }
      final avg = total / memberUids.length;
      result.add(EstiDvcrLeagueTopScore(league: league, avgScore: avg));
    }

    // 4. Trier par score moyen décroissant
    result.sort((a, b) => b.avgScore.compareTo(a.avgScore));
    return result;
  }

  // ── Classement d'une ligue ────────────────────────────────────────────────
  /// [matchDay] : 0 = général, -1 = finale, >0 = journée spécifique.
  static Stream<List<TournamentEntry>> leagueLeaderboardStream(
    String leagueId,
    String tournamentId, {
    int matchDay = 0,
  }) {
    return _leagues.doc(leagueId).snapshots().asyncMap((leagueSnap) async {
      if (!leagueSnap.exists) return <TournamentEntry>[];
      final d = leagueSnap.data()!;
      final memberUids = (d['memberUids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      if (memberUids.isEmpty) return <TournamentEntry>[];

      // Choisir la bonne sous-collection selon le filtre
      Query<Map<String, dynamic>> lbQuery;
      if (matchDay == 0) {
        lbQuery = _db
            .collection('tournaments')
            .doc(tournamentId)
            .collection('leaderboard')
            .orderBy('points', descending: true);
      } else {
        final dayKey = matchDay == -1 ? 'finale' : '$matchDay';
        lbQuery = _db
            .collection('tournaments')
            .doc(tournamentId)
            .collection('leaderboard_matchday')
            .doc(dayKey)
            .collection('entries')
            .orderBy('points', descending: true);
      }

      final lbSnap = await lbQuery.get();
      return lbSnap.docs
          .where((doc) => memberUids.contains(doc.id))
          .map(TournamentEntry.fromDoc)
          .toList();
    });
  }
}
