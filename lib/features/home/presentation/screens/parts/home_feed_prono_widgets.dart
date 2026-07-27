part of '../home_screen.dart';

class _HomeFeaturedPronoFooter extends StatelessWidget {
  static const _kGreen = Color(0xFF0A4438);
  static const _kMuted = Color(0xFF6E776F);

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _HomeFeaturedPronoFooter({
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    /// Même logique qu’avant (ligne claire + texte vert), mais panneau vitré et bordure légère
    /// pour rester dans le flou du stade sans grosse pilule verte.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _kGreen.withAlpha(20),
          highlightColor: _kGreen.withAlpha(12),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(238),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen.withAlpha(42)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _kGreen.withAlpha(22),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _kGreen.withAlpha(35)),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    size: 19,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _kGreen.withAlpha(160),
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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
