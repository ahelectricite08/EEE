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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: HomeTheme.paper(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 178,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ResultStadiumImage(match: match),
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
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 12,
                    child: Row(
                      children: [
                        Text(
                          match.competition.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'TERMINÉ',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: Colors.white.withAlpha(220),
                          ),
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
                  Container(
                    width: 2,
                    height: 12,
                    color: resultAccent,
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
                  const Spacer(),
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
