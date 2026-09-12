import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/match_lineup.dart';
import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';
import '../screens/matches/match_detail_ui.dart';

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
              margin: const EdgeInsets.only(bottom: MatchDetailTheme.chapterGap),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: MatchDetailTheme.paper(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MatchDetailSectionHeader(title: 'Compositions'),
                  const SizedBox(height: 4),
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
                        color: MatchDetailTheme.hairline,
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
          style: MatchDetailType.kicker,
        ),
        if (side.coach.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Coach · ${side.coach}',
            style: MatchDetailType.label,
          ),
        ],
        const SizedBox(height: 8),
        ...side.starters.map(
          (p) => Text(
            p,
            textAlign: align == CrossAxisAlignment.end
                ? TextAlign.end
                : TextAlign.start,
            style: MatchDetailType.caption.copyWith(
              color: MatchDetailTheme.text,
            ),
          ),
        ),
        if (side.substitutes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Remplaçants', style: MatchDetailType.kicker),
          ...side.substitutes.map(
            (p) => Text(
              '↔ $p',
              textAlign: align == CrossAxisAlignment.end
                  ? TextAlign.end
                  : TextAlign.start,
              style: MatchDetailType.caption,
            ),
          ),
        ],
      ],
    );
  }
}
