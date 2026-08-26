import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lineup_prediction.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/match_stats_schema.dart';
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
        return 'Le XI probable est verrouillé ${LineupPrediction.lockWindowLabel} '
            '— ${LineupPrediction.lockReasonLabel} '
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
}
