import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_lineup.dart';
import '../screens/matches/match_detail_palette.dart';

/// Bloc compositions sur fiche match (source `matches` + `match_stats`).
class MatchLineupsDetailCard extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;

  const MatchLineupsDetailCard({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .snapshots(),
      builder: (context, matchSnap) {
        final matchDoc = matchSnap.data?.data() ?? {};
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('match_stats')
              .doc(matchId)
              .snapshots(),
          builder: (context, statsSnap) {
            final lineups = MatchLineups.mergeDocs(
              matchDoc,
              statsSnap.data?.data(),
            );
            if (!lineups.hasAnyContent) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: MatchDetailPalette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MatchDetailPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 18,
                        color: MatchDetailPalette.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'COMPOSITIONS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: MatchDetailPalette.green,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _side(
                          team1,
                          lineups.home,
                          CrossAxisAlignment.start,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: MatchDetailPalette.border,
                      ),
                      Expanded(
                        child: _side(
                          team2,
                          lineups.away,
                          CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _side(
    String label,
    MatchLineupSide side,
    CrossAxisAlignment align,
  ) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: MatchDetailPalette.grey,
          ),
        ),
        if (side.coach.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Coach · ${side.coach}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MatchDetailPalette.text,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ...side.starters.map(
          (p) => Text(
            p,
            textAlign: align == CrossAxisAlignment.end
                ? TextAlign.end
                : TextAlign.start,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MatchDetailPalette.text,
            ),
          ),
        ),
        if (side.substitutes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Remplaçants',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: MatchDetailPalette.grey,
            ),
          ),
          ...side.substitutes.map(
            (p) => Text(
              '↔ $p',
              textAlign: align == CrossAxisAlignment.end
                  ? TextAlign.end
                  : TextAlign.start,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MatchDetailPalette.grey,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
