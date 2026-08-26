import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_stats_schema.dart';
import '../screens/matches/match_detail_palette.dart';
import '../services/best_goal_vote_service.dart';
import '../services/match_highlight_service.dart';
import 'match_event_video_play_button.dart';

/// Vote but du match + carte vainqueur + revivre le clip.
/// Visible **uniquement après le match** (status finished).
class BestGoalVoteSection extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;
  final List<Map<String, dynamic>> events;
  final String matchStatus;

  const BestGoalVoteSection({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.events,
    required this.matchStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = matchStatus.trim().toLowerCase();
    if (status != 'finished') return const SizedBox.shrink();

    final goals = BestGoalVoteService.goalCandidatesFromEvents(events);
    if (goals.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: BestGoalVoteService.instance.watchMatch(matchId),
      builder: (context, matchSnap) {
        final d = matchSnap.data?.data() ?? {};
        final liveStatus =
            (d['status'] ?? matchStatus).toString().trim().toLowerCase();
        if (liveStatus != 'finished') return const SizedBox.shrink();
        if (d['bestGoalVoteEnabled'] == false) {
          return const SizedBox.shrink();
        }
        final counts = <String, int>{};
        final rawCounts = d['goalVoteCounts'];
        if (rawCounts is Map) {
          rawCounts.forEach((k, v) {
            counts[k.toString()] = (v as num?)?.toInt() ?? 0;
          });
        }
        final total = (d['goalVoteTotal'] as num?)?.toInt() ?? 0;
        final bestId = (d['bestGoalEventId'] ?? '').toString();
        final bestPlayer = (d['bestGoalPlayer'] ?? '').toString().trim();
        final bestMinute = (d['bestGoalMinute'] as num?)?.toInt() ?? 0;
        final bestVotes = (d['bestGoalVotes'] as num?)?.toInt() ?? 0;
        final showBest =
            d['showBestGoal'] != false && bestPlayer.isNotEmpty && total > 0;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          stream: BestGoalVoteService.instance.watchMyVote(matchId),
          builder: (context, voteSnap) {
            final voteData = voteSnap.data?.data();
            final myEventId = (voteData?['eventId'] ?? '').toString().trim();
            final hasVoted = myEventId.isNotEmpty;

            // Après vote : carte résultat seulement (pas de liste cliquable).
            if (hasVoted) {
              Map<String, dynamic>? myGoal;
              for (final g in goals) {
                if ((g['id'] ?? '').toString() == myEventId) {
                  myGoal = g;
                  break;
                }
              }
              final votePlayer = (voteData?['player'] as String?)?.trim() ?? '';
              final myPlayer = votePlayer.isNotEmpty
                  ? votePlayer
                  : (myGoal != null
                      ? MatchStatsSchema.eventPlayerLine(myGoal)
                      : '');
              final myMinute = (voteData?['minute'] as num?)?.toInt() ??
                  (myGoal?['minute'] as num?)?.toInt() ??
                  0;

              final displayPlayer =
                  showBest ? bestPlayer : (myPlayer.isEmpty ? 'Inconnu' : myPlayer);
              final displayMinute = showBest ? bestMinute : myMinute;
              final displayEventId = showBest ? bestId : myEventId;
              final displayVotes = showBest ? bestVotes : (counts[myEventId] ?? 1);

              return _BestGoalResultCard(
                matchId: matchId,
                eventId: displayEventId,
                player: displayPlayer,
                minute: displayMinute,
                votes: displayVotes,
                total: total > 0 ? total : 1,
                confirmation: showBest && myEventId != bestId
                    ? 'Ton vote est enregistré · tu as choisi ${myPlayer.isEmpty ? 'un autre but' : myPlayer}'
                    : 'Ton vote est enregistré',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBest)
                  _BestGoalResultCard(
                    matchId: matchId,
                    eventId: bestId,
                    player: bestPlayer,
                    minute: bestMinute,
                    votes: bestVotes,
                    total: total,
                  ),
                _BestGoalVotePicker(
                  team1: team1,
                  team2: team2,
                  goals: goals,
                  counts: counts,
                  bestId: bestId,
                  total: total,
                  onVote: (g) => _onVote(context, g),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onVote(
    BuildContext context,
    Map<String, dynamic> goal,
  ) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecte-toi pour voter.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    try {
      await BestGoalVoteService.instance.castVote(
        matchId: matchId,
        goalEvent: goal,
      );
    } on StateError catch (e) {
      if (!context.mounted) return;
      final msg = e.message == 'already_voted'
          ? 'Tu as déjà voté pour ce match.'
          : 'Vote impossible.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vote impossible.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }
}

/// Liste de buts à voter (uniquement avant le premier vote).
class _BestGoalVotePicker extends StatelessWidget {
  final String team1;
  final String team2;
  final List<Map<String, dynamic>> goals;
  final Map<String, int> counts;
  final String bestId;
  final int total;
  final ValueChanged<Map<String, dynamic>> onVote;

  const _BestGoalVotePicker({
    required this.team1,
    required this.team2,
    required this.goals,
    required this.counts,
    required this.bestId,
    required this.total,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MatchDetailPalette.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MatchDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MatchDetailPalette.border),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: MatchDetailPalette.gold,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'BUT DU MATCH',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: MatchDetailPalette.gold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (total > 0)
                  Text(
                    total <= 1 ? '$total vote' : '$total votes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MatchDetailPalette.grey,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FirebaseAuth.instance.currentUser == null
                      ? 'Connecte-toi pour voter pour ton but préféré.'
                      : 'Tape le but que tu as préféré.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MatchDetailPalette.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ...goals.map((g) {
                  final id = (g['id'] ?? '').toString();
                  final player = MatchStatsSchema.eventPlayerLine(g);
                  final minute = g['minute'] ?? '?';
                  final isHome =
                      MatchStatsSchema.isHomeTeamEvent(g, team1, team2);
                  final votes = counts[id] ?? 0;
                  final isLeader = bestId == id && total > 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: MatchDetailPalette.bg,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onVote(g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isLeader
                                  ? MatchDetailPalette.gold
                                  : MatchDetailPalette.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "$minute'",
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: MatchDetailPalette.gold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player.isEmpty ? 'Inconnu' : player,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: MatchDetailPalette.text,
                                      ),
                                    ),
                                    Text(
                                      isHome ? team1 : team2,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: MatchDetailPalette.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (votes > 0)
                                Text(
                                  '$votes',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: MatchDetailPalette.gold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte résultat — même langage visuel que « note du match » (fiche détail).
class _BestGoalResultCard extends StatelessWidget {
  final String matchId;
  final String eventId;
  final String player;
  final int minute;
  final int votes;
  final int total;
  final String? confirmation;

  const _BestGoalResultCard({
    required this.matchId,
    required this.eventId,
    required this.player,
    required this.minute,
    required this.votes,
    required this.total,
    this.confirmation,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, MatchHighlightClip>>(
      stream: MatchHighlightService.instance.watchByEventId(matchId),
      builder: (context, snap) {
        final clip = eventId.isEmpty ? null : snap.data?[eventId];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: MatchDetailPalette.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MatchDetailPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MatchDetailPalette.border),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: MatchDetailPalette.gold,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BUT DU MATCH',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: MatchDetailPalette.gold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      total <= 1 ? '$total vote' : '$total votes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (confirmation != null) ...[
                      Text(
                        confirmation!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MatchDetailPalette.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      player,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: MatchDetailPalette.text,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      minute > 0
                          ? "$minute' · $votes vote${votes > 1 ? 's' : ''}"
                          : '$votes vote${votes > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MatchDetailPalette.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Communauté DVCR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MatchDetailPalette.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (clip != null && clip.isReady) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => playMatchHighlightClip(
                          context,
                          matchId: matchId,
                          clip: clip,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: MatchDetailPalette.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: const RoundedRectangleBorder(),
                        ),
                        icon: const Icon(Icons.play_circle_filled_rounded),
                        label: Text(
                          'Revivre le but',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
