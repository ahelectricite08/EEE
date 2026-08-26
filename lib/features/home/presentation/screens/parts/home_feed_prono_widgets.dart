part of '../home_screen.dart';

class _HomeFeaturedShareFooter extends StatelessWidget {
  final MatchModel match;

  const _HomeFeaturedShareFooter({required this.match});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => DvcrShare.share(
            ShareHelper.matchText(match),
            context: context,
          ),
          borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: HomeTheme.surface,
              borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
              border: Border.all(color: HomeTheme.hairline, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.ios_share_rounded,
                  size: 16,
                  color: HomeTheme.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Partager ce match',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: HomeTheme.ink,
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  'RÉSEAUX',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: HomeTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBetweenSeasonsFeaturedBody extends StatelessWidget {
  final SeasonLifecycleConfig config;

  const _HomeBetweenSeasonsFeaturedBody({required this.config});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
        child: SizedBox(
          height: 212,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/stadebogny.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.25),
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: _kGreen.withAlpha(220),
                  child: const Center(
                    child: Icon(Icons.stadium_rounded,
                        size: 56, color: Colors.white54),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(35),
                      Colors.black.withAlpha(165),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.homeHeadline,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 0.98,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.homeSubline,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(230),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
