part of '../home_screen.dart';

class _NextMatchCard extends StatelessWidget {
  final VoidCallback onOpenActu;

  const _NextMatchCard({required this.onOpenActu});

  VoidCallback _openDetail(BuildContext context, MatchModel match) {
    return () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(match: match),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life = lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        if (life.betweenSeasons) {
          return _HomeBetweenSeasonsFeaturedBody(config: life);
        }

        return StreamBuilder<LiveHubState>(
          stream: const HomeLiveHubAdapter().watch(),
          initialData: const HomeLiveHubAdapter().latest,
          builder: (context, hubSnap) {
            final hub = hubSnap.data ?? LiveHubState.empty;
            return ListenableBuilder(
              listenable: const HomeMatchCatalogAdapter().listenable,
              builder: (context, _) {
                final ctrl = const HomeMatchCatalogAdapter();
                if (!_showHomeFeaturedMatchSection(ctrl, hub, life)) {
                  return const SizedBox.shrink();
                }
                final picked = _pickHomeFeaturedMatch(ctrl, hub);
                if (picked == null) {
                  return const SizedBox.shrink();
                }
                final match = _buildHomeDisplayMatch(picked, hub);
                return HomeScaleOnPress(
                  child: _HomeNextMatchHybrid(
                    match: match,
                    footer: _HomeFeaturedShareFooter(
                      match: match,
                      onOpenActu: onOpenActu,
                    ),
                    onTap: _openDetail(context, match),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Mix : rythme / photo généreuse / heure de l’ancienne carte + ivoire / écussons alignés.
class _HomeNextMatchHybrid extends StatelessWidget {
  static const double _crest = 52;
  static const double _stroke = 2;
  static const double _photoH = 188;

  final MatchModel match;
  final Widget? footer;
  final VoidCallback onTap;

  const _HomeNextMatchHybrid({
    required this.match,
    required this.footer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sedanHome = isSedanTeam(match.team1);
    final sedanAway = isSedanTeam(match.team2);
    final sedan = sedanHome || sedanAway;
    final embedded = embeddedStadiumUrl(match);
    final venue = matchVenueLine(match);
    final venueStamp = sedanVenueStamp(match);
    final cacheW = _homeHeroCacheWidth(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
          child: Ink(
            decoration: HomeTheme.paper(
              edge: sedan
                  ? HomeTheme.ink.withValues(alpha: 0.16)
                  : HomeTheme.hairline,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HomeTheme.paperRadius),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _photoH,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (embedded != null)
                              _HomeStadiumPhoto(url: embedded, cacheWidth: cacheW)
                            else
                              StreamBuilder<String?>(
                                stream: watchHomeStadiumImage(match.team1),
                                builder: (context, snap) {
                                  final url = snap.data;
                                  if (url != null && url.isNotEmpty) {
                                    return _HomeStadiumPhoto(
                                      url: url,
                                      cacheWidth: cacheW,
                                    );
                                  }
                                  return Image.asset(
                                    'assets/images/terrain.jpg',
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, 0.2),
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                      color: Color(0xFF0A4438),
                                    ),
                                  );
                                },
                              ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.0, 0.45, 1.0],
                                  colors: [
                                    Color(0x660A1C18),
                                    Color(0x140A1C18),
                                    Color(0xF2FFFDF8),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: WeatherMatchCardLayer(match: match),
                              ),
                            ),
                            if (sedan)
                              Positioned(
                                top: 12,
                                left: 14,
                                child: Text(
                                  venueStamp == null
                                      ? 'PROCHAIN MATCH'
                                      : 'PROCHAIN MATCH  ·  $venueStamp',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              [
                                MatchCompetition.displayLabel(match.competition)
                                    .toUpperCase(),
                                compactDateLabel(match.date),
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HomeType.kicker.copyWith(
                                color: HomeTheme.ink,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (venue != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HomeType.meta.copyWith(
                                  color: HomeTheme.text,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _HomeHybridCrest(
                                      url: match.logo1,
                                      teamName: match.team1,
                                      highlight: sedanHome,
                                    ),
                                  ),
                                ),
                                _HomeKickoffCenter(date: match.date),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _HomeHybridCrest(
                                      url: match.logo2,
                                      teamName: match.team2,
                                      highlight: sedanAway,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    match.team1.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: HomeType.title.copyWith(
                                      fontSize: 15,
                                      color: sedanHome
                                          ? HomeTheme.green
                                          : HomeTheme.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 104),
                                Expanded(
                                  child: Text(
                                    match.team2.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: HomeType.title.copyWith(
                                      fontSize: 15,
                                      color: sedanAway
                                          ? HomeTheme.green
                                          : HomeTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (footer != null) footer!,
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (sedan)
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: HomeTheme.green,
                        child: SizedBox(width: 3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStadiumPhoto extends StatelessWidget {
  final String url;
  final int cacheWidth;

  const _HomeStadiumPhoto({required this.url, required this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    return DvcrNetworkImage(
      url,
      fit: BoxFit.cover,
      alignment: const Alignment(0, 0.2),
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/terrain.jpg',
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.2),
      ),
    );
  }
}

class _HomeKickoffCenter extends StatelessWidget {
  final DateTime date;

  const _HomeKickoffCenter({required this.date});

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final dayDiff = calendarDaysFromToday(date);
    final String countdown;
    if (diff.isNegative) {
      countdown = 'Coup d’envoi';
    } else if (dayDiff == 0 && diff.inMinutes < 60) {
      countdown = '${diff.inMinutes} min';
    } else if (dayDiff == 0) {
      countdown = 'Aujourd’hui';
    } else if (dayDiff == 1) {
      countdown = 'Demain';
    } else {
      countdown = 'Dans $dayDiff j';
    }

    final hour =
        '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hour,
            maxLines: 1,
            style: GoogleFonts.barlowCondensed(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.6,
              color: HomeTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(width: 28, height: 1, color: HomeTheme.green),
          const SizedBox(height: 6),
          Text(
            countdown,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: HomeType.kicker.copyWith(
              letterSpacing: 0.8,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHybridCrest extends StatelessWidget {
  static const double _ruleGap = 4;
  static const double _ruleH = 2;

  final String? url;
  final String teamName;
  final bool highlight;

  const _HomeHybridCrest({
    required this.url,
    required this.teamName,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final cacheW = dvcrCrestCacheWidth(context, _HomeNextMatchHybrid._crest);
    return SizedBox(
      width: _HomeNextMatchHybrid._crest,
      height: _HomeNextMatchHybrid._crest + _ruleGap + _ruleH,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _HomeNextMatchHybrid._crest,
            height: _HomeNextMatchHybrid._crest,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                width: _HomeNextMatchHybrid._stroke,
                color: highlight ? HomeTheme.green : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: u != null && u.isNotEmpty
                  ? DvcrNetworkImage(
                      u,
                      fit: BoxFit.contain,
                      cacheWidth: cacheW,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: HomeTheme.green,
                      ),
                    )
                  : Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: HomeTheme.green,
                    ),
            ),
          ),
          const SizedBox(height: _ruleGap),
          Container(
            width: _HomeNextMatchHybrid._crest * 0.45,
            height: _ruleH,
            color: highlight ? HomeTheme.green : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
