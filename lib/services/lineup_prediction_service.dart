import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/prono/domain/my_compo.dart';
import '../models/crowd_xi.dart';
import '../models/lineup_prediction.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/match_stats_schema.dart';
import '../models/sedan_squad.dart';
import '../utils/player_name_normalize.dart';

/// Jeu « XI probable » Sedan — prédictions fans + scoring Functions.
class LineupPredictionService {
  LineupPredictionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get col =>
      _db.collection('lineup_predictions');

  static DocumentReference<Map<String, dynamic>> ref(
    String matchId,
    String uid,
  ) =>
      col.doc(LineupPrediction.docId(matchId, uid));

  static Stream<LineupPrediction?> watchUserPrediction(
    String matchId,
    String uid,
  ) {
    return ref(matchId, uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return LineupPrediction.fromMap(snap.data(), id: snap.id);
    });
  }

  static Future<void> savePrediction(LineupPrediction prediction) async {
    final names = prediction.playerNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(LineupPrediction.requiredPlayers)
        .toList();
    if (names.length != LineupPrediction.requiredPlayers) {
      throw StateError(
        'Il faut exactement ${LineupPrediction.requiredPlayers} joueurs.',
      );
    }
    final id = LineupPrediction.docId(prediction.matchId, prediction.uid);
    final existing = await col.doc(id).get();
    final data = prediction.toUserWriteMap();
    data['playerNames'] = names;
    if (existing.exists) {
      data.remove('createdAt');
    }
    await col.doc(id).set(data, SetOptions(merge: true));
  }

  /// Message FR pour un `set()` rejeté (verrou 60 h, XI officiel, payload).
  static String userFacingWriteError(
    Object error, {
    required MatchModel match,
    required MatchLineups lineups,
    Map<String, dynamic>? matchDoc,
  }) {
    if (error is StateError) {
      return error.message;
    }
    if (error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.code == 'PERMISSION_DENIED')) {
      if (matchDoc?['lineupPredictionsLocked'] == true) {
        return 'Le XI probable est verrouillé pour ce match.';
      }
      if (hasOfficialSedanLineup(lineups, match)) {
        return 'Le XI probable est fermé : la composition officielle Sedan '
            'est déjà publiée.';
      }
      if (match.status != MatchStatus.upcoming) {
        return 'Ce match n’est plus ouvert pour le XI probable.';
      }
      if (!DateTime.now().isBefore(LineupPrediction.lockAt(match.date))) {
        return 'La composition est verrouillée. '
            'Tu ne peux plus enregistrer ni modifier ton XI.';
      }
      return 'Enregistrement refusé. Il faut exactement 11 joueurs, '
          'et le XI ne doit pas déjà être noté.';
    }
    return 'Impossible d’enregistrer ton XI. Réessaie dans un instant.';
  }

  /// Côté Sedan dans une fiche match (home ou away).
  static MatchLineupSide? sedanSide(MatchLineups lineups, MatchModel match) {
    if (MatchStatsSchema.isSedanTeamLabel(match.team1)) return lineups.home;
    if (MatchStatsSchema.isSedanTeamLabel(match.team2)) return lineups.away;
    return null;
  }

  static bool isSedanMatch(MatchModel match) =>
      MatchStatsSchema.isSedanTeamLabel(match.team1) ||
      MatchStatsSchema.isSedanTeamLabel(match.team2);

  /// Compo officielle Sedan publiée (≥11 titulaires non vides).
  static bool hasOfficialSedanLineup(MatchLineups lineups, MatchModel match) {
    final side = sedanSide(lineups, match);
    if (side == null) return false;
    final starters =
        side.starters.where((e) => e.trim().isNotEmpty).toList();
    return starters.length >= LineupPrediction.requiredPlayers;
  }

  /// Onglet Composition : le jeu XI probable tant que le XI Sedan officiel
  /// n’est pas publié. L’adversaire n’a jamais de XI probable.
  static bool showsXiProbableGame(MatchLineups lineups, MatchModel match) =>
      isSedanMatch(match) && !hasOfficialSedanLineup(lineups, match);

  /// Verrouillage fan (voir doc [LineupPrediction]).
  static bool isPredictionLocked({
    required MatchModel match,
    required MatchLineups lineups,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    if (match.status != MatchStatus.upcoming) return true;
    if (!t.isBefore(LineupPrediction.lockAt(match.date))) return true;
    if (hasOfficialSedanLineup(lineups, match)) return true;
    // Flag posé par CF après scoring / lock explicite.
    return false;
  }

  static bool isPredictionLockedFromMatchDoc(
    Map<String, dynamic> matchDoc, {
    required MatchModel match,
    required MatchLineups lineups,
    DateTime? now,
  }) {
    if (matchDoc['lineupPredictionsLocked'] == true) return true;
    return isPredictionLocked(match: match, lineups: lineups, now: now);
  }

  static int scoreAgainstOfficial({
    required List<String> predicted,
    required List<String> officialStarters,
  }) =>
      countPlayerNameMatches(predicted, officialStarters);

  /// Effectif résolu depuis ids (prioritaires) puis noms.
  static List<SedanSquadPlayer> playersFromPrediction(
    SedanSquad squad,
    LineupPrediction? pred,
  ) {
    if (pred == null) return const [];
    final picked = <SedanSquadPlayer>[];
    final seen = <String>{};
    if (pred.playerIds.isNotEmpty) {
      for (final id in pred.playerIds) {
        final p = squad.byId(id);
        if (p == null || !seen.add(p.id)) continue;
        picked.add(p);
      }
    }
    if (picked.isEmpty) {
      for (final raw in pred.playerNames) {
        final p = squad.matchLineupLabel(raw);
        if (p == null) {
          final ph = SedanSquad.placeholderFromLabel(raw);
          if (ph.name.isEmpty) continue;
          final key = 'n:${normalizePlayerName(ph.name)}';
          if (!seen.add(key)) continue;
          picked.add(ph);
          continue;
        }
        if (!seen.add(p.id)) continue;
        picked.add(p);
      }
    }
    return picked;
  }

  /// Compos de **cet** utilisateur — égalité `uid` seule (pas d’index composite).
  static Stream<List<MyCompoItem>> watchMyCompos(
    String uid, {
    int limit = 40,
  }) {
    return col.where('uid', isEqualTo: uid).snapshots().asyncMap((snap) async {
      final preds = <LineupPrediction>[];
      for (final doc in snap.docs) {
        preds.add(LineupPrediction.fromMap(doc.data(), id: doc.id));
      }
      if (preds.isEmpty) return const <MyCompoItem>[];
      final ids = preds.map((e) => e.matchId).where((e) => e.isNotEmpty).toSet();
      final matches = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in ids) {
        try {
          matches[id] = await _db.collection('matches').doc(id).get();
        } catch (_) {}
      }
      final items = <MyCompoItem>[];
      for (final pred in preds) {
        final snap = matches[pred.matchId];
        if (snap == null || !snap.exists) continue;
        MatchModel match;
        try {
          match = MatchModel.fromFirestore(snap);
        } catch (_) {
          continue;
        }
        if (!isSedanMatch(match)) continue;
        final data = snap.data() ?? const <String, dynamic>{};
        final lineups = MatchLineups.fromDoc(data);
        final official = hasOfficialSedanLineup(lineups, match);
        final starters = sedanSide(lineups, match)
                ?.starters
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const <String>[];
        items.add(MyCompoItem(
          matchId: match.id,
          team1: match.team1,
          team2: match.team2,
          matchDate: match.date,
          logo1: match.logo1,
          logo2: match.logo2,
          competition: match.competition,
          prediction: pred,
          officialSedanStarters: starters,
          officialPublished: official,
          crowdXi: official ? CrowdXi.fromMatchDoc(data) : null,
        ));
      }
      items.sort((a, b) => b.matchDate.compareTo(a.matchDate));
      if (items.length > limit) return items.sublist(0, limit);
      return items;
    });
  }
}
