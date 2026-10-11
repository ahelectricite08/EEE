import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/prono/presentation/theme/prono_theme.dart';
import '../features/prono/presentation/theme/prono_type.dart';
import '../models/crowd_xi.dart';
import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';

enum CrowdXiBoardTone { matchDetail, prono }

/// Le onze que le vestiaire a posé, vs le onze officiel une fois publié.
class CrowdXiBoard extends StatelessWidget {
  final CrowdXi crowd;
  final CrowdXiBoardTone tone;

  /// Compteurs vestiaire (N pronos, votes par joueur). À n’afficher
  /// qu’après publication du XI Sedan officiel — sinon bandwagon.
  final bool showCounts;

  const CrowdXiBoard({
    super.key,
    required this.crowd,
    this.tone = CrowdXiBoardTone.matchDetail,
    this.showCounts = false,
  });

  bool get _detail => tone == CrowdXiBoardTone.matchDetail;

  @override
  Widget build(BuildContext context) {
    final ink = _detail ? MatchDetailTheme.ink : PronoArenaTheme.ink;
    final muted = _detail ? MatchDetailTheme.textMuted : PronoArenaTheme.textMuted;
    final green = _detail ? MatchDetailTheme.green : PronoArenaTheme.green;
    final paper = _detail
        ? MatchDetailTheme.paper(sedan: true)
        : BoxDecoration(
            color: PronoArenaTheme.surface,
            border: Border.all(color: PronoArenaTheme.hairline),
            borderRadius: BorderRadius.circular(6),
          );

    final ballots = crowd.ballots;
    final ballotLabel = ballots == 1 ? '1 prono' : '$ballots pronos';
    final String body;
    if (crowd.officialComputed) {
      body = crowd.officialHits == 0
          ? 'Aucun titulaire officiel dans le onze du vestiaire.'
          : crowd.officialHits == 11
              ? 'Les 11 du vestiaire sont aussi titulaires officiels.'
              : '${crowd.officialHits}/11 aussi dans le onze officiel.';
    } else {
      body = 'Le onze du vestiaire, avant la compo officielle.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 16, height: 3, color: green),
              const SizedBox(width: 10),
              Text(
                'XI DES SUPPORTERS',
                style: (_detail ? MatchDetailType.kicker : PronoType.kicker)
                    .copyWith(color: _detail ? MatchDetailTheme.text : PronoArenaTheme.text),
              ),
              if (showCounts) ...[
                const Spacer(),
                Text(
                  ballotLabel.toUpperCase(),
                  style: (_detail ? MatchDetailType.kicker : PronoType.kicker)
                      .copyWith(color: muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < crowd.players.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _CrowdXiRow(
              index: i + 1,
              player: crowd.players[i],
              showOfficial: crowd.officialComputed,
              showCounts: showCounts,
              ink: ink,
              muted: muted,
              green: green,
            ),
          ],
        ],
      ),
    );
  }
}

class _CrowdXiRow extends StatelessWidget {
  final int index;
  final CrowdXiPlayer player;
  final bool showOfficial;
  final bool showCounts;
  final Color ink;
  final Color muted;
  final Color green;

  const _CrowdXiRow({
    required this.index,
    required this.player,
    required this.showOfficial,
    required this.showCounts,
    required this.ink,
    required this.muted,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    final inOff = showOfficial && player.inOfficial;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$index',
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            player.name,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showCounts)
          Text(
            '${player.votes}',
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
        if (showOfficial) ...[
          const SizedBox(width: 8),
          Icon(
            inOff ? Icons.check_rounded : Icons.remove_rounded,
            size: 16,
            color: inOff ? green : muted,
          ),
        ],
      ],
    );
  }
}
