import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';
import '../screens/matches/match_detail_ui.dart';

/// Lecture `matchRating*` depuis un doc Firestore `matches` ou `live/current`.
class MatchRatingSnapshot {
  const MatchRatingSnapshot({
    required this.average,
    required this.total,
    required this.sum,
  });

  final double average;
  final int total;
  final int sum;

  bool get hasVotes => total > 0 && average > 0;

  String get averageLabel => average == average.roundToDouble()
      ? average.toInt().toString()
      : average.toStringAsFixed(1);

  String get verdictLabel {
    if (average >= 9) return 'On était chaud';
    if (average >= 7.5) return 'Solide, ce soir';
    if (average >= 6) return 'Pas mal du tout';
    if (average >= 5) return 'Bof, on a vu mieux';
    if (average >= 3.5) return 'Dur à regarder';
    return 'On oublie ce match';
  }

  Color get verdictColor {
    if (average >= 7) return const Color(0xFF2E7D32);
    if (average >= 5) return const Color(0xFF167A5F);
    return const Color(0xFFD32F2F);
  }

  static MatchRatingSnapshot? fromDoc(Map<String, dynamic>? doc) {
    if (doc == null || doc.isEmpty) return null;
    final totalRaw = doc['matchRatingTotal'];
    final total = totalRaw is num ? totalRaw.toInt() : 0;
    if (total <= 0) return null;
    final avgRaw = doc['matchRatingAverage'];
    final sumRaw = doc['matchRatingSum'];
    var avg = avgRaw is num ? avgRaw.toDouble() : 0.0;
    final sum = sumRaw is num ? sumRaw.toInt() : 0;
    if (avg <= 0 && sum > 0) avg = sum / total;
    if (avg <= 0) return null;
    return MatchRatingSnapshot(average: avg, total: total, sum: sum);
  }

  static Map<String, int> countsFromDoc(Map<String, dynamic>? doc) {
    final raw = doc?['matchRatingCounts'];
    final out = <String, int>{};
    for (var n = 1; n <= 10; n++) {
      out['$n'] = 0;
    }
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key.toString();
        if (int.tryParse(k) != null && e.value is num) {
          out[k] = (e.value as num).toInt();
        }
      }
    }
    return out;
  }
}

/// Encart note du match (carte match, détail).
class MatchRatingPanel extends StatelessWidget {
  final MatchRatingSnapshot rating;
  final bool lightSurface;
  final bool compact;

  const MatchRatingPanel({
    super.key,
    required this.rating,
    this.lightSurface = false,
    this.compact = false,
  });

  factory MatchRatingPanel.fromDoc(
    Map<String, dynamic>? doc, {
    bool lightSurface = false,
    bool compact = false,
  }) {
    final snap = MatchRatingSnapshot.fromDoc(doc);
    assert(snap != null, 'MatchRatingPanel.fromDoc requires votes');
    return MatchRatingPanel(
      rating: snap!,
      lightSurface: lightSurface,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = lightSurface
        ? const Color(0xFFB8860B)
        : const Color(0xFFF5D76E);
    final ink = lightSurface ? const Color(0xFF1A1A1A) : Colors.white;
    final muted = lightSurface ? const Color(0xFF6B7280) : Colors.white70;
    final surface = lightSurface ? Colors.white : const Color(0xFF1E2A1E);
    final border = lightSurface
        ? const Color(0xFFE5E7EB)
        : Colors.white.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: gold, size: compact ? 18 : 22),
          const SizedBox(width: 8),
          Text(
            rating.averageLabel,
            style: GoogleFonts.barlowCondensed(
              fontSize: compact ? 26 : 32,
              fontWeight: FontWeight.w900,
              color: gold,
              height: 1,
            ),
          ),
          Text(
            '/10',
            style: GoogleFonts.inter(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE DU MATCH',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  rating.total <= 1
                      ? '${rating.total} avis'
                      : '${rating.total} avis',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte détail match — note communauté.
class MatchRatingDetailCard extends StatelessWidget {
  final Map<String, dynamic> matchDoc;

  const MatchRatingDetailCard({super.key, required this.matchDoc});

  @override
  Widget build(BuildContext context) {
    final rating = MatchRatingSnapshot.fromDoc(matchDoc);
    if (rating == null) return const SizedBox.shrink();

    const starTone = MatchDetailTheme.greenBright;

    // Barre de progression : note / 10
    final progress = (rating.average / 10).clamp(0.0, 1.0);

    final Color noteColor = rating.verdictColor;

    // Étoiles pleines (sur 5)
    final starsFull = (rating.average / 2).floor();
    final hasHalf = (rating.average / 2 - starsFull) >= 0.4;

    return Container(
      margin: const EdgeInsets.only(bottom: MatchDetailTheme.chapterGap),
      decoration: MatchDetailTheme.paper(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: MatchDetailSectionHeader(
              title: 'Note du match',
              trailing: rating.total <= 1
                  ? '${rating.total} vote'
                  : '${rating.total} votes',
            ),
          ),
          const MatchDetailRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rating.averageLabel,
                          style: MatchDetailType.score.copyWith(
                            fontSize: 56,
                            color: noteColor,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 3),
                          child: Text(
                            '/10',
                            style: MatchDetailType.numeral.copyWith(
                              fontSize: 18,
                              color: MatchDetailTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) {
                        IconData icon;
                        Color color;
                        if (i < starsFull) {
                          icon = Icons.star_rounded;
                          color = starTone;
                        } else if (i == starsFull && hasHalf) {
                          icon = Icons.star_half_rounded;
                          color = starTone;
                        } else {
                          icon = Icons.star_outline_rounded;
                          color = MatchDetailTheme.border;
                        }
                        return Icon(icon, color: color, size: 18);
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text('Communauté DVCR', style: MatchDetailType.caption),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.verdictLabel,
                        style: MatchDetailType.title.copyWith(
                          fontSize: 18,
                          color: noteColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: MatchDetailTheme.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(noteColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0', style: MatchDetailType.meta),
                          Text('10', style: MatchDetailType.meta),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stream Firestore `matches/{id}` pour la fiche détail.
class MatchRatingDetailCardStream extends StatelessWidget {
  final String matchId;

  const MatchRatingDetailCardStream({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .snapshots(),
      builder: (context, snap) {
        final doc = snap.data?.data();
        return MatchRatingDetailCard(matchDoc: doc ?? const {});
      },
    );
  }
}
