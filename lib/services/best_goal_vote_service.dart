import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Vote « But du match » — 1 vote / user / match, sur un event `goal`.
class BestGoalVoteService {
  BestGoalVoteService._();
  static final instance = BestGoalVoteService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _match(String matchId) =>
      _db.collection('matches').doc(matchId.trim());

  CollectionReference<Map<String, dynamic>> _votes(String matchId) =>
      _match(matchId).collection('goalVotes');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatch(String matchId) =>
      _match(matchId).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>?> watchMyVote(String matchId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(null);
    }
    return _votes(matchId).doc(uid).snapshots().map((s) => s.exists ? s : null);
  }

  static List<Map<String, dynamic>> goalCandidatesFromEvents(
    List<Map<String, dynamic>> events,
  ) {
    return events
        .where((e) {
          final t = (e['type'] ?? '').toString().toLowerCase();
          return t == 'goal' || t == 'own_goal';
        })
        .where((e) => (e['id'] ?? '').toString().trim().isNotEmpty)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Vote (ou change de vote) pour [eventId].
  Future<void> castVote({
    required String matchId,
    required Map<String, dynamic> goalEvent,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('auth_required');
    }
    final mid = matchId.trim();
    final eventId = (goalEvent['id'] ?? '').toString().trim();
    if (mid.isEmpty || eventId.isEmpty) {
      throw StateError('invalid_goal');
    }

    final player = (goalEvent['player'] ?? '').toString().trim();
    final team = (goalEvent['team'] ?? '').toString().trim();
    final minute = (goalEvent['minute'] as num?)?.toInt() ?? 0;
    final type = (goalEvent['type'] ?? 'goal').toString();

    final matchRef = _match(mid);
    final voteRef = _votes(mid).doc(uid);

    await _db.runTransaction((tx) async {
      final matchSnap = await tx.get(matchRef);
      final voteSnap = await tx.get(voteRef);
      final data = matchSnap.data() ?? {};

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status != 'finished') {
        throw StateError('vote_after_match_only');
      }
      if (data['bestGoalVoteEnabled'] == false) {
        throw StateError('vote_disabled');
      }

      final counts = Map<String, dynamic>.from(
        (data['goalVoteCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
            ) ??
            {},
      );
      var total = (data['goalVoteTotal'] as num?)?.toInt() ?? 0;

      final prevId = voteSnap.exists
          ? (voteSnap.data()?['eventId'] ?? '').toString()
          : '';
      if (prevId == eventId) return;

      if (prevId.isNotEmpty) {
        final prev = (counts[prevId] as int? ?? 0) - 1;
        if (prev <= 0) {
          counts.remove(prevId);
        } else {
          counts[prevId] = prev;
        }
        total = (total - 1).clamp(0, 999999);
      }

      counts[eventId] = (counts[eventId] as int? ?? 0) + 1;
      total += 1;

      // Leader = but du match courant
      String bestId = eventId;
      var bestVotes = counts[eventId] as int? ?? 0;
      counts.forEach((id, v) {
        final n = v is int ? v : (v as num?)?.toInt() ?? 0;
        if (n > bestVotes) {
          bestVotes = n;
          bestId = id;
        }
      });

      String bestPlayer = player;
      int bestMinute = minute;
      String bestTeam = team;
      String bestType = type;
      if (bestId != eventId) {
        // Garder meta déjà stockées si on ne change pas le leader via ce vote
        bestPlayer = (data['bestGoalPlayer'] ?? player).toString();
        bestMinute = (data['bestGoalMinute'] as num?)?.toInt() ?? minute;
        bestTeam = (data['bestGoalTeam'] ?? team).toString();
        bestType = (data['bestGoalType'] ?? type).toString();
      }
      // Si nouveau leader = ce but, meta = ce but
      if (bestId == eventId) {
        bestPlayer = player.isEmpty ? 'Inconnu' : player;
        bestMinute = minute;
        bestTeam = team;
        bestType = type;
      } else if (prevId == bestId && bestId != eventId) {
        // leader inchangé côté id — meta match déjà OK
        bestPlayer = (data['bestGoalPlayer'] ?? '').toString();
        if (bestPlayer.isEmpty) bestPlayer = player;
        bestMinute = (data['bestGoalMinute'] as num?)?.toInt() ?? minute;
        bestTeam = (data['bestGoalTeam'] ?? team).toString();
        bestType = (data['bestGoalType'] ?? type).toString();
      }

      // Si on a voté pour un autre but et le leader a changé vers un 3e id,
      // on ne connaît pas le player ici → lire depuis events
      if (bestId != eventId && bestId != prevId) {
        final events = (data['events'] as List?) ?? const [];
        for (final raw in events) {
          if (raw is! Map) continue;
          if ((raw['id'] ?? '').toString() == bestId) {
            bestPlayer = (raw['player'] ?? bestPlayer).toString();
            bestMinute = (raw['minute'] as num?)?.toInt() ?? bestMinute;
            bestTeam = (raw['team'] ?? bestTeam).toString();
            bestType = (raw['type'] ?? bestType).toString();
            break;
          }
        }
      }

      tx.set(voteRef, {
        'uid': uid,
        'eventId': eventId,
        'player': player,
        'team': team,
        'minute': minute,
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!voteSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(matchRef, {
        'goalVoteCounts': counts,
        'goalVoteTotal': total,
        'goalVoteUpdatedAt': FieldValue.serverTimestamp(),
        'bestGoalEventId': bestId,
        'bestGoalPlayer': bestPlayer,
        'bestGoalMinute': bestMinute,
        'bestGoalTeam': bestTeam,
        'bestGoalType': bestType,
        'bestGoalVotes': bestVotes,
        'showBestGoal': true,
      }, SetOptions(merge: true));
    });
  }
}
