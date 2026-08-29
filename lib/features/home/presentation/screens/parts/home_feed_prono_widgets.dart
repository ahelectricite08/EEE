part of '../home_screen.dart';

class _HomeFeaturedShareFooter extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onOpenActu;

  const _HomeFeaturedShareFooter({
    required this.match,
    required this.onOpenActu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
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
          _HomeFeaturedAvantMatchCta(
            match: match,
            onOpenActu: onOpenActu,
          ),
          _HomeFeaturedTicketCta(match: match),
        ],
      ),
    );
  }
}

class _HomeFeaturedAvantMatchCta extends StatelessWidget {
  static const _ivory = Color(0xFFF4F0E6);

  final MatchModel match;
  final VoidCallback onOpenActu;

  const _HomeFeaturedAvantMatchCta({
    required this.match,
    required this.onOpenActu,
  });

  Future<void> _open(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final clean = YoutubeParser.sanitizeShareUrl(trimmed);
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _youtubeUrl(List<SocialNetworkSpec> social) {
    for (final spec in social) {
      if (spec.id == 'youtube' && spec.isOpenable) return spec.url.trim();
    }
    return SocialLinkUrls.youtube;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveHubState>(
      stream: const HomeLiveHubAdapter().watch(),
      initialData: const HomeLiveHubAdapter().latest,
      builder: (context, hubSnap) {
        final hub = hubSnap.data ?? LiveHubState.empty;
        final liveUrl = _hubCoversMatch(hub, match)
            ? (hub.matchStreamUrl ?? '').trim()
            : '';
        return StreamBuilder<List<SocialNetworkSpec>>(
          stream: SocialLinksSettings.watchVisible(),
          initialData: kSocialCatalogDefaults,
          builder: (context, socialSnap) {
            final youtubeUrl = _youtubeUrl(
              socialSnap.data ?? kSocialCatalogDefaults,
            );
            final target = liveUrl.isNotEmpty ? liveUrl : youtubeUrl;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: _ivory,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
                  side: const BorderSide(color: HomeTheme.ink, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: HomeTheme.green,
                      child: InkWell(
                        onTap: () => _open(target),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 18,
                                color: _ivory,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'L’AVANT MATCH DVCR !',
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                        color: _ivory,
                                        height: 1.05,
                                      ),
                                    ),
                                    Text(
                                      '30 min avant le coup d’envoi',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                        color: _ivory.withValues(alpha: 0.78),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'YOUTUBE',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: _ivory.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const ColoredBox(
                      color: HomeTheme.hairline,
                      child: SizedBox(height: 1, width: double.infinity),
                    ),
                    Material(
                      color: _ivory,
                      child: InkWell(
                        onTap: onOpenActu,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_stories_outlined,
                                size: 16,
                                color: HomeTheme.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: HomeTheme.ink,
                                      height: 1.15,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Les '),
                                      TextSpan(
                                        text: 'ACTUS',
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                          color: HomeTheme.ink,
                                          height: 1.15,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' DVCR à consulter avant la rencontre !',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: HomeTheme.ink.withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeFeaturedTicketCta extends StatelessWidget {
  final MatchModel match;

  const _HomeFeaturedTicketCta({required this.match});

  Future<void> _open(MatchTicketing config) async {
    final uri = config.launchUri;
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchTicketing>(
      stream: MatchTicketingService.instance.watch(),
      initialData: MatchTicketingService.instance.lastKnown,
      builder: (context, snap) {
        final config = snap.data ?? MatchTicketing.defaults;
        final sedanHome = isSedanTeam(match.team1);
        if (!config.visibleOnHome(sedanIsHome: sedanHome)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _open(config),
              borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
              child: Ink(
                decoration: BoxDecoration(
                  color: HomeTheme.green,
                  borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
                  border: Border.all(color: HomeTheme.ink, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                      color: Color(0xFFF4F0E6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CHOPPE TON BILLET POUR LE MATCH !',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: const Color(0xFFF4F0E6),
                          height: 1.05,
                        ),
                      ),
                    ),
                    Text(
                      'BILLETTERIE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: const Color(0xFFF4F0E6).withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
