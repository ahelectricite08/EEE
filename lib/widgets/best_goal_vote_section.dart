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
        // Status live du doc (au cas où le model est stale)
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
        final showBest =
            d['showBestGoal'] != false && bestPlayer.isNotEmpty && total > 0;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          stream: BestGoalVoteService.instance.watchMyVote(matchId),
          builder: (context, voteSnap) {
            final myEventId =
                (voteSnap.data?.data()?['eventId'] ?? '').toString();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBest)
                  _BestGoalWinnerCard(
                    matchId: matchId,
                    eventId: bestId,
                    player: bestPlayer,
                    minute: bestMinute,
                    votes: (d['bestGoalVotes'] as num?)?.toInt() ?? 0,
                    total: total,
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  decoration: BoxDecoration(
                    color: MatchDetailPalette.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MatchDetailPalette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOTE · BUT DU MATCH',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: MatchDetailPalette.gold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                        final player =
                            MatchStatsSchema.eventPlayerLine(g);
                        final minute = g['minute'] ?? '?';
                        final isHome = MatchStatsSchema.isHomeTeamEvent(
                          g,
                          team1,
                          team2,
                        );
                        final votes = counts[id] ?? 0;
                        final selected = myEventId == id;
                        final isLeader = bestId == id && total > 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? MatchDetailPalette.gold.withAlpha(28)
                                : MatchDetailPalette.bg,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _onVote(context, g),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected || isLeader
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                    if (selected) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: MatchDetailPalette.gold,
                                      ),
                                    ],
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
    } catch (e) {
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

class _BestGoalWinnerCard extends StatelessWidget {
  final String matchId;
  final String eventId;
  final String player;
  final int minute;
  final int votes;
  final int total;

  const _BestGoalWinnerCard({
    required this.matchId,
    required this.eventId,
    required this.player,
    required this.minute,
    required this.votes,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, MatchHighlightClip>>(
      stream: MatchHighlightService.instance.watchByEventId(matchId),
      builder: (context, snap) {
        final clip = eventId.isEmpty ? null : snap.data?[eventId];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MatchDetailPalette.gold.withAlpha(40),
                MatchDetailPalette.card,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MatchDetailPalette.gold.withAlpha(120)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: MatchDetailPalette.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BUT DU MATCH',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MatchDetailPalette.gold,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                player,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: MatchDetailPalette.text,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                minute > 0
                    ? "$minute' · $votes vote${votes > 1 ? 's' : ''} / $total"
                    : '$votes vote${votes > 1 ? 's' : ''} / $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MatchDetailPalette.grey,
                  fontWeight: FontWeight.w600,
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
                    backgroundColor: MatchDetailPalette.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 44),
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
        );
      },
    );
  }
}
