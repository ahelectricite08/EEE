import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match_lineup.dart';
import 'match_partner_logos_service.dart';
import 'match_rating_service.dart';
import 'vote_history_service.dart';

class MotmVoteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DocumentReference<Map<String, dynamic>> _liveRef = _db
      .collection('live')
      .doc('current');

  static const Duration maxDuration = Duration(minutes: 10);
  static const String defaultSponsorName = 'MANEO';
  static const String defaultSponsorLogo = '';
  static const String defaultTitle = 'Trophee HOMME DU MATCH';

  /// Logo vote si renseigné, sinon logo par défaut Photos & réseaux.
  static String resolveSponsorLogo({
    required String voteLogo,
    String settingsLogo = '',
  }) {
    final vote = voteLogo.trim();
    if (vote.isNotEmpty) return vote;
    return settingsLogo.trim();
  }

  /// Bandeau accueil : « Trophée » + nom du sponsor (le libellé HOMME DU MATCH est à part).
  static String heroDisplayTitle(Map<String, dynamic> liveData) {
    final raw = (liveData['motmVoteTitle'] as String? ?? '').trim();
    final configured = raw.isEmpty ? defaultTitle : raw;
    final sponsor =
        (liveData['motmVoteSponsorName'] as String? ?? '').trim().isEmpty
        ? defaultSponsorName
        : (liveData['motmVoteSponsorName'] as String).trim();

    var headline = configured
        .replaceAll(
          RegExp(r'\s*homme\s+du\s+match\s*', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (headline.isEmpty ||
        RegExp(r'^trophe[eé]?\s*$', caseSensitive: false).hasMatch(headline)) {
      headline = 'Trophée';
    } else if (RegExp(r'^trophe[eé]', caseSensitive: false).hasMatch(headline)) {
      final rest = headline
          .replaceFirst(RegExp(r'^trophe[eé]\s*', caseSensitive: false), '')
          .trim();
      headline = rest.isEmpty ? 'Trophée' : 'Trophée $rest';
    }

    final sponsorLower = sponsor.toLowerCase();
    if (sponsor.isNotEmpty &&
        !headline.toLowerCase().contains(sponsorLower)) {
      headline = '$headline $sponsor';
    }
    return headline;
  }

  static Future<void> startVote({
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    String sponsorId = '',
    String sponsorName = defaultSponsorName,
    String sponsorLogo = '',
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

    var resolvedLogo = sponsorLogo.trim();
    if (resolvedLogo.isEmpty) {
      try {
        resolvedLogo =
            (await MatchPartnerLogosService.instance.getOnce()).motmLogoUrl;
      } catch (_) {}
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
        'motmVoteSponsorLogo': resolvedLogo,
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
        'manOfTheMatchPartnerLogo': resolvedLogo,
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
        'motmVoteSponsorLogo': resolvedLogo,
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
    await MatchRatingService.tryOpenPendingAfterMotmClosed();
  }

  static Future<void> ensureVoteState(Map<String, dynamic> liveData) async {
    if (_isExpired(liveData)) {
      await stopVote(reason: 'timeout');
      await MatchRatingService.tryOpenPendingAfterMotmClosed();
    }
  }

  static bool isVoteTimerExpired(
    Map<String, dynamic> liveData, [
    DateTime? now,
  ]) => _isExpired(liveData, now);

  /// Plaque bord terrain (bénévoles) : qui aller chercher, et si le vote tourne encore.
  static MotmPitchPickupView pitchPickupView(
    Map<String, dynamic>? liveData, {
    DateTime? now,
  }) {
    return MotmPitchPickupView.fromLive(liveData, now: now ?? DateTime.now());
  }

  static DateTime? voteEndsAt(Object? endsAt) {
    if (endsAt is DateTime) return endsAt;
    if (endsAt is Timestamp) return endsAt.toDate();
    return null;
  }

  static Duration remainingVoteTime(
    Map<String, dynamic> liveData, [
    DateTime? now,
  ]) {
    final end = voteEndsAt(liveData['motmVoteEndsAt']);
    if (end == null) return Duration.zero;
    final remaining = end.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static String formatCountdown(Duration remaining) {
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Part des votes du vainqueur (arrondi), ou null si pas de dépouillement.
  static int? winnerVotePercent(Map<String, dynamic> liveData) {
    final total = totalVotes(liveData);
    if (total <= 0) return null;
    var votes = 0;
    final raw = liveData['motmVoteWinnerVotes'];
    if (raw is num) {
      votes = raw.toInt();
    }
    if (votes <= 0) {
      final id = (liveData['motmVoteWinnerId'] as String? ?? '').trim();
      if (id.isEmpty) return null;
      votes = candidateCounts(liveData)[id] ?? 0;
    }
    if (votes <= 0) return null;
    return ((votes / total) * 100).round().clamp(0, 100);
  }

  static ({String number, String name}) splitPlayerLabel(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'^(\d{1,3})\s+(.+)$').firstMatch(trimmed);
    if (match != null) {
      return (number: match.group(1)!, name: match.group(2)!.trim());
    }
    return (number: '', name: trimmed);
  }

  static bool hasVisibleVote(Map<String, dynamic> liveData) {
    if (MatchRatingService.takesPriorityOverMotm(liveData)) return false;
    final status = (liveData['motmVoteStatus'] as String? ?? '').trim();
    return (status == 'active' || status == 'closed') &&
        teamMaps(liveData).isNotEmpty;
  }

  static bool isVoteActive(Map<String, dynamic> liveData, [DateTime? now]) {
    if (_isExpired(liveData, now)) return false;
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

  static int winnerVoteCount(Map<String, dynamic> liveData) {
    final votes = liveData['motmVoteWinnerVotes'];
    if (votes is num) return votes.toInt().clamp(0, 999999);
    return 0;
  }

  static String winnerVotePercentLabel(Map<String, dynamic> liveData) {
    final p = winnerVotePercent(liveData);
    if (p == null) return '';
    return '$p % des votes';
  }

  /// Champs à fusionner sur `matches/{id}` à l’arrêt du live (fiche forever).
  static Map<String, dynamic> persistFieldsForMatch(
    Map<String, dynamic> liveData,
  ) {
    var data = Map<String, dynamic>.from(liveData);
    final status = (data['motmVoteStatus'] as String? ?? '').trim();
    if (status == 'active') {
      data.addAll(_resolvedWinnerFields(data));
    }

    final published = (data['manOfTheMatchName'] as String? ?? '').trim();
    final winner = (data['motmVoteWinnerName'] as String? ?? '').trim();
    final name = published.isNotEmpty ? published : winner;
    if (name.isEmpty) return const {};

    return {
      'manOfTheMatchName': name,
      'manOfTheMatchPartnerName':
          (data['manOfTheMatchPartnerName'] as String? ?? '').trim(),
      'manOfTheMatchPartnerLogo':
          (data['manOfTheMatchPartnerLogo'] as String? ?? '').trim(),
      'showMotm': true,
      'motmVoteStatus': 'closed',
      'motmVoteWinnerId': (data['motmVoteWinnerId'] as String? ?? '').trim(),
      'motmVoteWinnerName': winner.isNotEmpty ? winner : name,
      'motmVoteWinnerVotes': winnerVoteCount(data),
      'motmVoteWinnerTeamId':
          (data['motmVoteWinnerTeamId'] as String? ?? '').trim(),
      'motmVoteWinnerTeamName':
          (data['motmVoteWinnerTeamName'] as String? ?? '').trim(),
      'motmVoteTotal': totalVotes(data),
      'motmVoteCounts': candidateCounts(data),
    };
  }

  static Map<String, dynamic> _resolvedWinnerFields(
    Map<String, dynamic> liveData,
  ) {
    final candidates = candidateMaps(liveData);
    final counts = candidateCounts(liveData);
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
    final winnerName = (winner?['name'] as String? ?? '').trim();
    return {
      'motmVoteWinnerId': (winner?['id'] as String? ?? '').trim(),
      'motmVoteWinnerName': winnerName,
      'motmVoteWinnerVotes': winnerVotes < 0 ? 0 : winnerVotes,
      'motmVoteWinnerTeamId': (winner?['teamId'] as String? ?? '').trim(),
      'motmVoteWinnerTeamName': (winner?['teamName'] as String? ?? '').trim(),
      'manOfTheMatchName': winnerName,
    };
  }

  static String userVotePath(String uid) => 'live/current/motmVotes/$uid';

  static bool _isExpired(Map<String, dynamic> liveData, [DateTime? now]) {
    if ((liveData['motmVoteStatus'] as String? ?? '').trim() != 'active') {
      return false;
    }
    final end = voteEndsAt(liveData['motmVoteEndsAt']);
    if (end == null) return false;
    return end.isBefore(now ?? DateTime.now());
  }

  static List<String> _cleanPlayers(List<String> players) {
    final seen = <String>{};
    final out = <String>[];
    for (final player in players) {
      final name = player.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      out.add(name);
    }
    return out;
  }

  /// Joueurs issus de `lineupHome` / `lineupAway` (live, fiche match, stats).
  static ({
    List<String> team1Players,
    List<String> team2Players,
    bool ready,
  })
  playersFromLineups(
    Map<String, dynamic> liveData, {
    Map<String, dynamic>? matchData,
    Map<String, dynamic>? statsData,
  }) {
    final lineups = MatchLineups.mergeForMotm(liveData, matchData, statsData);
    final team1Players = lineups.home.playerNamesForMotm;
    final team2Players = lineups.away.playerNamesForMotm;
    return (
      team1Players: team1Players,
      team2Players: team2Players,
      ready: lineups.readyForMotmVote,
    );
  }

  /// Si le live a été réinitialisé, la compo peut encore être sur `matches` / `match_stats`.
  static Future<
    ({List<String> team1Players, List<String> team2Players, bool ready})
  >
  resolvePlayersFromLineups(Map<String, dynamic> liveData) async {
    Map<String, dynamic>? matchData;
    Map<String, dynamic>? statsData;
    final matchId = (liveData['matchId'] as String? ?? '').trim();
    if (matchId.isNotEmpty && !matchId.startsWith('live_')) {
      final matchSnap = await _db.collection('matches').doc(matchId).get();
      matchData = matchSnap.data();
      final statsSnap = await _db.collection('match_stats').doc(matchId).get();
      statsData = statsSnap.data();
    }
    return playersFromLineups(
      liveData,
      matchData: matchData,
      statsData: statsData,
    );
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

enum MotmPitchPickupPhase {
  /// Pas de vote Homme du match en cours.
  idle,

  /// Fenêtre de 10 min encore ouverte.
  voting,

  /// Vote expiré ou clos, vainqueur pas encore lisible.
  pending,

  /// Vainqueur connu — aller le chercher en bord de terrain.
  ready,
}

class MotmPitchPickupView {
  final MotmPitchPickupPhase phase;
  final String playerName;
  final String teamName;
  final Duration remaining;
  final int? winnerPercent;
  final bool liveActive;

  const MotmPitchPickupView({
    required this.phase,
    this.playerName = '',
    this.teamName = '',
    this.remaining = Duration.zero,
    this.winnerPercent,
    this.liveActive = true,
  });

  const MotmPitchPickupView.idle({this.liveActive = true})
      : phase = MotmPitchPickupPhase.idle,
        playerName = '',
        teamName = '',
        remaining = Duration.zero,
        winnerPercent = null;

  bool get hasPlayer => playerName.trim().isNotEmpty;

  String get remainingLabel => MotmVoteService.formatCountdown(remaining);

  String get winnerShareLabel {
    final p = winnerPercent;
    if (p == null) return '';
    return '$p % des votes';
  }

  factory MotmPitchPickupView.fromLive(
    Map<String, dynamic>? liveData, {
    required DateTime now,
  }) {
    if (liveData == null) {
      return const MotmPitchPickupView.idle(liveActive: false);
    }

    final status = (liveData['motmVoteStatus'] as String? ?? '').trim();
    final winnerName =
        (liveData['motmVoteWinnerName'] as String? ?? '').trim();
    final publishedName =
        (liveData['manOfTheMatchName'] as String? ?? '').trim();
    final name = winnerName.isNotEmpty ? winnerName : publishedName;
    final team = (liveData['motmVoteWinnerTeamName'] as String? ?? '').trim();
    final remaining = MotmVoteService.remainingVoteTime(liveData, now);
    final total = MotmVoteService.totalVotes(liveData);
    final percent = total > 0
        ? MotmVoteService.winnerVotePercent(liveData)
        : null;

    if (MotmVoteService.isVoteActive(liveData, now)) {
      return MotmPitchPickupView(
        phase: MotmPitchPickupPhase.voting,
        remaining: remaining,
      );
    }

    if (status == 'active') {
      return MotmPitchPickupView(
        phase: name.isEmpty
            ? MotmPitchPickupPhase.pending
            : MotmPitchPickupPhase.ready,
        playerName: name,
        teamName: team,
        remaining: Duration.zero,
        winnerPercent: name.isEmpty ? null : percent,
      );
    }

    if (status == 'closed') {
      if (name.isEmpty) {
        return const MotmPitchPickupView(
          phase: MotmPitchPickupPhase.pending,
        );
      }
      return MotmPitchPickupView(
        phase: MotmPitchPickupPhase.ready,
        playerName: name,
        teamName: team,
        winnerPercent: percent,
      );
    }

    if (name.isNotEmpty) {
      return MotmPitchPickupView(
        phase: MotmPitchPickupPhase.ready,
        playerName: name,
        teamName: team,
        winnerPercent: percent,
      );
    }

    return const MotmPitchPickupView.idle();
  }
}
