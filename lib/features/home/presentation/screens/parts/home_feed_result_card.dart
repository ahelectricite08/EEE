part of '../home_screen.dart';

class _HomeResultCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  final VoidCallback? onReplay;

  const _HomeResultCard({
    required this.match,
    required this.onTap,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final resultAccent = _cssaResultAccent(match);
    final resultLabel = _cssaResultLabel(match);

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // ── Image + score overlay ──────────────────────────────────
            SizedBox(
              height: 178,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image (avec fallback stade Sedan)
                  _ResultStadiumImage(match: match),

                  // Gradient fort vers le bas
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 1.0],
                          colors: [
                            Colors.black.withAlpha(10),
                            Colors.black.withAlpha(55),
                            Colors.black.withAlpha(205),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Barre colorée résultat (top-left)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 4,
                      height: 178,
                      color: resultAccent,
                    ),
                  ),

                  // Compétition + terminé (top)
                  Positioned(
                    top: 12,
                    left: 18,
                    right: 12,
                    child: Row(
                      children: [
                        _HomeMatchPill(
                          label: match.competition,
                          color: _kText,
                          bg: Colors.white.withAlpha(230),
                        ),
                        const Spacer(),
                        _HomeMatchPill(
                          label: 'TERMINÉ',
                          color: _kGreen,
                          bg: Colors.white.withAlpha(230),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),

                  // Équipes + score (bottom)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Équipe 1
                        Expanded(
                          child: _HomeClubSide(
                            name: match.team1,
                            logoUrl: match.logo1,
                          ),
                        ),

                        // Score central
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (match.score1 != null) ...[
                                Text(
                                  '${match.score1}  –  ${match.score2}',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ] else
                                Text(
                                  'VS',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withAlpha(180),
                                    letterSpacing: 2,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _fmtDate(match.date),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Équipe 2
                        Expanded(
                          child: _HomeClubSide(
                            name: match.team2,
                            logoUrl: match.logo2,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Barre inférieure ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  // Indicateur résultat
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: resultAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        resultLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: resultAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Voir le match
                  GestureDetector(
                    onTap: onReplay ?? onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          onReplay != null ? 'Voir le replay' : 'Voir le match',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: _kGreen),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image du stade avec fallback sur l'image du stade de Sedan.
