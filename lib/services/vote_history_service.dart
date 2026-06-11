import 'package:cloud_firestore/cloud_firestore.dart';

class VoteHistoryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _ref = _db.collection(
    'vote_history',
  );

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamRecent({
    int limit = 30,
  }) {
    return _ref.orderBy('closedAt', descending: true).limit(limit).snapshots();
  }

  static Future<void> archiveMotmVote(
    Map<String, dynamic> data, {
    String? matchId,
  }) async {
    final sessionId = (data['motmVoteSessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) return;
    final teams = ((data['motmVoteTeams'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    await _ref.doc('motm_$sessionId').set({
      'type': 'motm_matchday',
      'sessionId': sessionId,
      'title': (data['motmVoteTitle'] as String? ?? '').trim(),
      'subtitle': teams
          .map((team) => (team['name'] ?? '').toString())
          .join(' vs '),
      'status': (data['motmVoteStatus'] as String? ?? '').trim(),
      'sponsorId': (data['motmVoteSponsorId'] as String? ?? '').trim(),
      'sponsorName': (data['motmVoteSponsorName'] as String? ?? '').trim(),
      'sponsorLogo': (data['motmVoteSponsorLogo'] as String? ?? '').trim(),
      'sponsorColorHex': (data['motmVoteSponsorColorHex'] as String? ?? '')
          .trim(),
      'sponsorLinkUrl': (data['motmVoteSponsorLinkUrl'] as String? ?? '')
          .trim(),
      'winnerId': (data['motmVoteWinnerId'] as String? ?? '').trim(),
      'winnerName': (data['motmVoteWinnerName'] as String? ?? '').trim(),
      'winnerTeamName': (data['motmVoteWinnerTeamName'] as String? ?? '')
          .trim(),
      'winnerVotes': (data['motmVoteWinnerVotes'] as num?)?.toInt() ?? 0,
      'totalVotes': (data['motmVoteTotal'] as num?)?.toInt() ?? 0,
      'endedReason': (data['motmVoteEndedReason'] as String? ?? '').trim(),
      'closedAt': Timestamp.fromDate(DateTime.now()),
      'matchId': (matchId ?? data['matchId'] ?? '').toString().trim(),
      'teams': teams,
    }, SetOptions(merge: true));
  }

  static Future<void> archiveEmissionPoll(Map<String, dynamic> data) async {
    final sessionId = (data['pollSessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) return;
    final counts = ((data['pollCounts'] as Map?) ?? const {}).map<String, int>(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
    final winnerId = (data['pollWinnerId'] as String? ?? '').trim();
    await _ref.doc('poll_$sessionId').set({
      'type': 'emission_poll',
      'sessionId': sessionId,
      'title': (data['pollTitle'] as String? ?? '').trim(),
      'subtitle': (data['pollSubtitle'] as String? ?? '').trim(),
      'status': (data['pollStatus'] as String? ?? '').trim(),
      'sponsorId': (data['pollSponsorId'] as String? ?? '').trim(),
      'sponsorName': (data['pollSponsorName'] as String? ?? '').trim(),
      'sponsorLogo': (data['pollSponsorLogo'] as String? ?? '').trim(),
      'sponsorColorHex': (data['pollSponsorColorHex'] as String? ?? '').trim(),
      'sponsorLinkUrl': (data['pollSponsorLinkUrl'] as String? ?? '').trim(),
      'winnerId': winnerId,
      'winnerName': (data['pollWinnerLabel'] as String? ?? '').trim(),
      'winnerVotes': counts[winnerId] ?? 0,
      'totalVotes': (data['pollTotal'] as num?)?.toInt() ?? 0,
      'endedReason': (data['pollEndedReason'] as String? ?? '').trim(),
      'closedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }
}
