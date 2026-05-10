import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/match_prono_stats_service.dart';
import 'prono_palette.dart';

/// Barre 1 / N / 2 à partir des agrégats `match_prono_stats`.
class PronoOutcomeCommunityBar extends StatelessWidget {
  final String matchId;

  const PronoOutcomeCommunityBar({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: MatchPronoStatsService.outcomeStream(matchId),
      builder: (context, snap) {
        final m = snap.data ??
            const {'homeWin': 0, 'draw': 0, 'awayWin': 0, 'total': 0};
        final t = m['total'] ?? 0;
        final h = m['homeWin'] ?? 0;
        final d = m['draw'] ?? 0;
        final a = m['awayWin'] ?? 0;
        final ph = t > 0 ? h / t : 0.0;
        final pd = t > 0 ? d / t : 0.0;
        final pa = t > 0 ? a / t : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMMUNAUTÉ (1 · N · 2)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: pronoMutedText,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: (ph * 1000).round().clamp(1, 1000),
                      child: Container(color: pronoGreen),
                    ),
                    Expanded(
                      flex: (pd * 1000).round().clamp(1, 1000),
                      child: Container(color: pronoGrey),
                    ),
                    Expanded(
                      flex: (pa * 1000).round().clamp(1, 1000),
                      child: Container(color: pronoRed.withAlpha(220)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1  ${(ph * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pronoText,
                  ),
                ),
                Text(
                  'N  ${(pd * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pronoText,
                  ),
                ),
                Text(
                  '2  ${(pa * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pronoText,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Raccourcis score typiques pour 1 / N / 2.
class Prono1x2QuickPicks extends StatelessWidget {
  final void Function(int s1, int s2) onPick;

  const Prono1x2QuickPicks({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int s1, int s2) {
      return Expanded(
        child: OutlinedButton(
          onPressed: () => onPick(s1, s2),
          style: OutlinedButton.styleFrom(
            foregroundColor: pronoGreen,
            side: const BorderSide(color: pronoBorder),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('1 · 1-0', 1, 0),
        const SizedBox(width: 8),
        chip('N · 1-1', 1, 1),
        const SizedBox(width: 8),
        chip('2 · 0-1', 0, 1),
      ],
    );
  }
}
