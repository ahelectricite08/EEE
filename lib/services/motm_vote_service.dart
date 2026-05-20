import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'vote_history_service.dart';

class MotmVoteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DocumentReference<Map<String, dynamic>> _liveRef = _db
      .collection('live')
      .doc('current');

  static const Duration maxDuration = Duration(minutes: 10);
  static const String defaultSponsorName = 'MANEO';
  static const String defaultSponsorLogo =
      'https://static.wixstatic.com/media/e91e00_40557d11e6b9461fad85eff84a34a49d~mv2.png';
  static const String defaultTitle = 'Trophee HOMME DU MATCH';

  static Future<void> startVote({
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    String sponsorId = '',
    String sponsorName = defaultSponsorName,
    String sponsorLogo = defaultSponsorLogo,
    String sponsorColorHex = '',
    String sponsorLinkUrl = '',
    String backgroundImageUrl = '',
    bool revealWinner = true,
  }) async {
    final cleanTeam1Name = team1Name.trim();
    final cleanTeam2Name = team2Name.trim();
    final cleanTeam1Players = _cleanPlayers(team1Players);
    final cleanTeam2Players = _cleanPlayers(team2Players);

    if (cleanTeam1Name.isEmpty || cleanTeam2Name.isEmpty) {
      throw StateError('Renseigne les 2 equipes avant de lancer le vote.');
    }
    if (cleanTeam1Players.isEmpty || cleanTeam2Players.isEmpty) {
      throw StateError('Ajoute au moins un joueur dans chaque equipe.');
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final endsAt = Timestamp.fromDate(DateTime.now().add(maxDuration));
    final candidates = <Map<String, dynamic>>[];
    final counts = <String, int>{};
    final teams = <Map<String, dynamic>>[];

    void addTeam({
      required String teamId,
      required String teamName,
      required List<String> players,
    }) {
      final candidateIds = <String>[];
      for (var index = 0; index < players.length; index++) {
        final candidateId = '${teamId}_player_${index + 1}';
        candidates.add({
          'id': candidateId,
          'name': players[index],
          'teamId': teamId,
          'teamName': teamName,
        });
        counts[candidateId] = 0;
        candidateIds.add(candidateId);
      }
      teams.add({'id': teamId, 'name': teamName, 'candidateIds': candidateIds});
    }

    addTeam(
      teamId: 'team_1',
      teamName: cleanTeam1Name,
      players: cleanTeam1Players,
    );
    addTeam(
      teamId: 'team_2',
      teamName: cleanTeam2Name,
      players: cleanTeam2Players,
    );

    String matchId = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_liveRef);
      if (!snap.exists) {
        throw StateError('Aucun live en cours pour lancer le vote.');
      }
      final data = snap.data() ?? <String, dynamic>{};
      matchId = (data['matchId'] as String? ?? '').trim();

      tx.update(_liveRef, {
        'motmVoteEnabled': true,
        'motmVoteStatus': 'active',
        'motmVoteMode': 'team_player',
        'motmVoteSessionId': sessionId,
        'motmVoteTitle': defaultTitle,
        'motmVoteSponsorId': sponsorId.trim(),
        'motmVoteSponsorName': sponsorName.trim().isEmpty
            ? defaultSponsorName
            : sponsorName.trim(),
        'motmVoteSponsorLogo': sponsorLogo.trim().isEmpty
            ? defaultSponsorLogo
            : sponsorLogo.trim(),
        'motmVoteSponsorColorHex': sponsorColorHex.trim(),
        'motmVoteSponsorLinkUrl': sponsorLinkUrl.trim(),
        'motmVoteBackgroundImage': backgroundImageUrl.trim(),
        'motmVoteRevealWinner': revealWinner,
        'motmVoteTeams': teams,
        'motmVoteCandidates': candidates,
        'motmVoteCounts': counts,
        'motmVoteTotal': 0,
        'motmVoteStartedAt': FieldValue.serverTimestamp(),
        'motmVoteEndsAt': endsAt,
        'motmVoteClosedAt': null,
        'motmVoteWinnerId': '',
        'motmVoteWinnerName': '',
        'motmVoteWinnerVotes': 0,
        'motmVoteWinnerTeamId': '',
        'motmVoteWinnerTeamName': '',
        'motmVoteEndedReason': '',
        'showMotm': revealWinner,
        'manOfTheMatchName': '',
        'manOfTheMatchPartnerName': sponsorName.trim().isEmpty
            ? defaultSponsorName
            : sponsorName.trim(),
        'manOfTheMatchPartnerLogo': sponsorLogo.trim().isEmpty
            ? defaultSponsorLogo
            : sponsorLogo.trim(),
      });
    });

    if (matchId.isNotEmpty) {
      await _db.collection('matches').doc(matchId).set({
        'motmVoteMode': 'team_player',
        'motmVoteTitle': defaultTitle,
        'motmVoteSponsorId': sponsorId.trim(),
        'motmVoteSponsorName': sponsorName.trim().isEmpty
            ? defaultSponsorName
            : sponsorName.trim(),
        'motmVoteSponsorLogo': sponsorLogo.trim().isEmpty
            ? defaultSponsorLogo
            : sponsorLogo.trim(),
        'motmVoteSponsorColorHex': sponsorColorHex.trim(),
        'motmVoteSponsorLinkUrl': sponsorLinkUrl.trim(),
        'motmVoteBackgroundImage': backgroundImageUrl.trim(),
        'motmVoteRevealWinner': revealWinner,
        'motmVoteTeams': teams,
        'motmVoteCandidates': candidates,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> castVote({required String candidateId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté pour voter.');
    }

    final voteRef = _liveRef.collection('motmVotes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final liveSnap = await tx.get(_liveRef);
      if (!liveSnap.exists) {
        throw StateError('Aucun vote disponible.');
      }

      final liveData = liveSnap.data() ?? <String, dynamic>{};
      if (_isExpired(liveData)) {
        tx.update(_liveRef, _buildClosePayload(liveData, reason: 'timeout'));
        throw StateError('Le vote est maintenant clos.');
      }

      if ((liveData['motmVoteStatus'] as String? ?? '').trim() != 'active') {
        throw StateError('Le vote est clos.');
      }

      final sessionId = (liveData['motmVoteSessionId'] as String? ?? '').trim();
      final selectedCandidate = candidateById(liveData, candidateId);
      if (selectedCandidate == null) {
        throw StateError('Ce joueur n\'est plus disponible.');
      }

      final voteSnap = await tx.get(voteRef);
      final previousVote = voteSnap.data() ?? <String, dynamic>{};
      final previousSessionId = (previousVote['sessionId'] as String? ?? '')
          .trim();
      final previousCandidateId = previousSessionId == sessionId
          ? (previousVote['candidateId'] as String? ?? '').trim()
          : '';

      if (previousCandidateId == candidateId) {
        return;
      }

      final counts = candidateCounts(liveData);
      var total = totalVotes(liveData);
      if (previousCandidateId.isNotEmpty) {
        counts[previousCandidateId] = ((counts[previousCandidateId] ?? 0) - 1)
            .clamp(0, 999999);
      } else {
        total += 1;
      }
      counts[candidateId] = (counts[candidateId] ?? 0) + 1;

      tx.update(_liveRef, {
        'motmVoteCounts': counts,
        'motmVoteTotal': total,
        'motmVoteUpdatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(voteRef, {
        'uid': user.uid,
        'sessionId': sessionId,
        'candidateId': candidateId,
        'candidateName': (selectedCandidate['name'] as String? ?? '').trim(),
        'teamId': (selectedCandidate['teamId'] as String? ?? '').trim(),
        'teamName': (selectedCandidate['teamName'] as String? ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!voteSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> stopVote({String reason = 'manual'}) async {
    String matchId = '';
    Map<String, dynamic>? finalPayload;
    Map<String, dynamic> originalData = <String, dynamic>{};

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_liveRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      originalData = data;
      matchId = (data['matchId'] as String? ?? '').trim();
      final status = (data['motmVoteStatus'] as String? ?? '').trim();
      if (status.isEmpty || status == 'closed') return;
      finalPayload = _buildClosePayload(data, reason: reason);
      tx.update(_liveRef, finalPayload!);
    });

    if (matchId.isNotEmpty && finalPayload != null) {
      await _db.collection('matches').doc(matchId).set({
        'manOfTheMatchName': finalPayload!['manOfTheMatchName'],
        'manOfTheMatchPartnerName': finalPayload!['manOfTheMatchPartnerName'],
        'manOfTheMatchPartnerLogo': finalPayload!['manOfTheMatchPartnerLogo'],
        'showMotm': finalPayload!['showMotm'],
        'motmVoteStatus': finalPayload!['motmVoteStatus'],
        'motmVoteClosedAt': finalPayload!['motmVoteClosedAt'],
        'motmVoteWinnerId': finalPayload!['motmVoteWinnerId'],
        'motmVoteWinnerName': finalPayload!['motmVoteWinnerName'],
        'motmVoteWinnerVotes': finalPayload!['motmVoteWinnerVotes'],
        'motmVoteWinnerTeamId': finalPayload!['motmVoteWinnerTeamId'],
        'motmVoteWinnerTeamName': finalPayload!['motmVoteWinnerTeamName'],
        'motmVoteCounts': finalPayload!['motmVoteCounts'],
        'motmVoteTotal': finalPayload!['motmVoteTotal'],
        'motmVoteEndedReason': finalPayload!['motmVoteEndedReason'],
      }, SetOptions(merge: true));
    }
    if (finalPayload != null) {
      await VoteHistoryService.archiveMotmVote({
        ...originalData,
        ...finalPayload!,
      }, matchId: matchId);
    }
  }

  static Future<void> ensureVoteState(Map<String, dynamic> liveData) async {
    if (_isExpired(liveData)) {
      await stopVote(reason: 'timeout');
    }
  }

  static bool hasVisibleVote(Map<String, dynamic> liveData) {
    final status = (liveData['motmVoteStatus'] as String? ?? '').trim();
    return (status == 'active' || status == 'closed') &&
        teamMaps(liveData).isNotEmpty;
  }

  static bool isVoteActive(Map<String, dynamic> liveData) {
    if (_isExpired(liveData)) return false;
    return (liveData['motmVoteStatus'] as String? ?? '').trim() == 'active';
  }

  static bool shouldRevealWinner(Map<String, dynamic> liveData) {
    return liveData['motmVoteRevealWinner'] == true;
  }

  static List<Map<String, dynamic>> teamMaps(Map<String, dynamic> liveData) {
    final raw = liveData['motmVoteTeams'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final fallbackTeam = (liveData['motmVoteTeamName'] as String? ?? '').trim();
    if (fallbackTeam.isEmpty) return const [];
    return [
      {
        'id': 'team_1',
        'name': fallbackTeam,
        'candidateIds': candidateMaps(liveData)
            .map((candidate) => (candidate['id'] as String? ?? '').trim())
            .where((id) => id.isNotEmpty)
            .toList(),
      },
    ];
  }

  static List<Map<String, dynamic>> candidateMaps(
    Map<String, dynamic> liveData,
  ) {
    final raw = liveData['motmVoteCandidates'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<Map<String, dynamic>> candidatesForTeam(
    Map<String, dynamic> liveData,
    String teamId,
  ) {
    return candidateMaps(liveData)
        .where(
          (candidate) =>
              (candidate['teamId'] as String? ?? '').trim() == teamId,
        )
        .toList();
  }

  static Map<String, dynamic>? candidateById(
    Map<String, dynamic> liveData,
    String candidateId,
  ) {
    for (final candidate in candidateMaps(liveData)) {
      if ((candidate['id'] as String? ?? '').trim() == candidateId) {
        return candidate;
      }
    }
    return null;
  }

  static Map<String, int> candidateCounts(Map<String, dynamic> liveData) {
    final raw = liveData['motmVoteCounts'];
    if (raw is! Map) return <String, int>{};
    return raw.map<String, int>((key, value) {
      return MapEntry(key.toString(), value is num ? value.toInt() : 0);
    });
  }

  static Map<String, int> teamVoteTotals(Map<String, dynamic> liveData) {
    final counts = candidateCounts(liveData);
    final totals = <String, int>{};
    for (final team in teamMaps(liveData)) {
      final teamId = (team['id'] as String? ?? '').trim();
      totals[teamId] = 0;
    }
    for (final candidate in candidateMaps(liveData)) {
      final teamId = (candidate['teamId'] as String? ?? '').trim();
      final candidateId = (candidate['id'] as String? ?? '').trim();
      totals[teamId] = (totals[teamId] ?? 0) + (counts[candidateId] ?? 0);
    }
    return totals;
  }

  static int totalVotes(Map<String, dynamic> liveData) {
    final total = liveData['motmVoteTotal'];
    return total is num ? total.toInt() : 0;
  }

  static String userVotePath(String uid) => 'live/current/motmVotes/$uid';

  static bool _isExpired(Map<String, dynamic> liveData) {
    if ((liveData['motmVoteStatus'] as String? ?? '').trim() != 'active') {
      return false;
    }
    final endsAt = liveData['motmVoteEndsAt'];
    if (endsAt is! Timestamp) return false;
    return endsAt.toDate().isBefore(DateTime.now());
  }

  static List<String> _cleanPlayers(List<String> players) {
    return players
        .map((player) => player.trim())
        .where((player) => player.isNotEmpty)
        .toSet()
        .toList();
  }

  static Map<String, dynamic> _buildClosePayload(
    Map<String, dynamic> liveData, {
    required String reason,
  }) {
    final candidates = candidateMaps(liveData);
    final counts = candidateCounts(liveData);
    final sponsorName =
        (liveData['motmVoteSponsorName'] as String? ?? '').trim().isEmpty
        ? defaultSponsorName
        : (liveData['motmVoteSponsorName'] as String).trim();
    final sponsorLogo =
        (liveData['motmVoteSponsorLogo'] as String? ?? '').trim().isEmpty
        ? defaultSponsorLogo
        : (liveData['motmVoteSponsorLogo'] as String).trim();
    final revealWinner = shouldRevealWinner(liveData);

    Map<String, dynamic>? winner;
    var winnerVotes = -1;
    for (final candidate in candidates) {
      final candidateId = (candidate['id'] as String? ?? '').trim();
      final votes = counts[candidateId] ?? 0;
      if (votes > winnerVotes) {
        winnerVotes = votes;
        winner = candidate;
      }
    }

    final winnerId = (winner?['id'] as String? ?? '').trim();
    final winnerName = (winner?['name'] as String? ?? '').trim();
    final winnerTeamId = (winner?['teamId'] as String? ?? '').trim();
    final winnerTeamName = (winner?['teamName'] as String? ?? '').trim();

    return {
      'motmVoteEnabled': true,
      'motmVoteStatus': 'closed',
      'motmVoteClosedAt': FieldValue.serverTimestamp(),
      'motmVoteWinnerId': winnerId,
      'motmVoteWinnerName': winnerName,
      'motmVoteWinnerVotes': winnerVotes < 0 ? 0 : winnerVotes,
      'motmVoteWinnerTeamId': winnerTeamId,
      'motmVoteWinnerTeamName': winnerTeamName,
      'motmVoteEndedReason': reason,
      'manOfTheMatchName': revealWinner ? winnerName : '',
      'manOfTheMatchPartnerName': sponsorName,
      'manOfTheMatchPartnerLogo': sponsorLogo,
      'showMotm': revealWinner && winnerName.isNotEmpty,
    };
  }
}
