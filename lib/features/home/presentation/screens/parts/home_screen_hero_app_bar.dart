part of '../home_screen.dart';

int _homeHeroCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

mixin _HomeScreenHeroAppBarMixin on _HomeScreenController {
  double _homeHeroBodyHeight(List<Map<String, dynamic>> heroEvents) {
    if (_isLive) {
      return heroEvents.isNotEmpty ? 248 : 212;
    }
    if (_isEmissionLive) return 192;
    return 176;
  }

  Future<void> _onHeroBackgroundTap() async {
    if (_isLive && !_matchStreamBroadcast) return;
    final url = _isLive
        ? _liveUrl
        : (_isEmissionLive ? _emissionUrl : null);
    if (url != null && url.isNotEmpty) {
      final clean = YoutubeParser.sanitizeShareUrl(url);
      await launchUrl(
        Uri.parse(clean),
        mode: LaunchMode.externalApplication,
      );
    } else if (!_isLive && !_isEmissionLive) {
      _switchMain(1);
    }
  }

  Widget _buildHeroPhoto(Alignment alignment) {
    final cacheW = _homeHeroCacheWidth(context);
    if (_isLive && _liveTeam1.isNotEmpty) {
      return StreamBuilder<String?>(
        stream: _watchHomeStadiumHero(_liveTeam1),
        builder: (context, snap) {
          final stadiumUrl = snap.data;
          if (stadiumUrl != null && stadiumUrl.isNotEmpty) {
            return Image.network(
              stadiumUrl,
              fit: BoxFit.cover,
              alignment: alignment,
              gaplessPlayback: true,
              cacheWidth: cacheW,
              filterQuality: FilterQuality.low,
              headers: kDvcrImageHttpHeaders,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
                fit: BoxFit.cover,
                alignment: alignment,
              ),
            );
          }
          return Image.asset(
            'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
            fit: BoxFit.cover,
            alignment: alignment,
          );
        },
      );
    }
    if (_isEmissionLive) {
      return HubHeroPhoto(
        slot: HubHeroSlot.emission,
        alignment: alignment,
        fallbackAsset: 'assets/images/IMG_0377.JPG',
        cacheWidth: cacheW,
        filterQuality: FilterQuality.low,
      );
    }
    return HubHeroPhoto(
      slot: HubHeroSlot.home,
      alignment: alignment,
      fallbackNetworkUrl: _homeBannerUrl,
      fallbackAsset: 'assets/images/IMG_0842.JPG',
      cacheWidth: cacheW,
      filterQuality: FilterQuality.low,
    );
  }

  Widget _buildHeroFlexibleSpace(List<Map<String, dynamic>> heroEvents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final maxExtent = settings?.maxExtent ?? constraints.maxHeight;
        final minExtent = settings?.minExtent ?? constraints.maxHeight;
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final delta = maxExtent - minExtent;
        final t = delta <= 0
            ? 0.0
            : (1 - (current - minExtent) / delta).clamp(0.0, 1.0);

        final alignment = Alignment.lerp(
          const Alignment(-1.0, 0.6),
          const Alignment(0, -0.3),
          t,
        )!;

        final veilTop = 0.30 + 0.32 * t;
        final veilMid = _isLive ? 0.08 + 0.40 * t : 0.06 + 0.42 * t;
        final veilLow = _isLive ? 0.58 + 0.20 * t : 0.52 + 0.22 * t;
        final veilBottom = _isLive ? 0.80 : 0.70;

        // Live : le score / buteurs restent plus longtemps. Default : fade type TV.
        final lockupOpacity = _isLive
            ? (1 - t * 1.05).clamp(0.0, 1.0)
            : (1 - t * 1.7).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: _onHeroBackgroundTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF151515)),
              ),
              Positioned.fill(child: _buildHeroPhoto(alignment)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: veilTop),
                        Colors.black.withValues(alpha: veilMid),
                        Colors.black.withValues(alpha: veilLow),
                        Colors.black.withValues(alpha: veilBottom),
                      ],
                      stops: const [0.0, 0.34, 0.78, 1.0],
                    ),
                  ),
                ),
              ),
              if (!_isLive && !_isEmissionLive)
                Positioned(
                  top: -8,
                  right: -24,
                  child: Text(
                    'DVCR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 160,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withAlpha(12),
                      letterSpacing: -4,
                      height: 0.85,
                    ),
                  ),
                ),
              if (lockupOpacity > 0)
                Positioned(
                  bottom: 18,
                  left: HomeTheme.gutter - 4,
                  right: HomeTheme.gutter - 4,
                  child: Opacity(
                    opacity: lockupOpacity,
                    child: _isLive
                        ? _buildLiveHeroContent(heroEvents)
                        : _isEmissionLive
                            ? _buildEmissionHeroContent()
                            : _buildDefaultHeroContent(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBarWithHero() {
    final session = ref.watch(authSessionProvider).asData?.value;
    final signedIn = session != null;
    final heroEvents = _heroPreviewEvents();
    final topPad = MediaQuery.paddingOf(context).top;
    const toolbarH = 48.0;
    const stripeH = HomeTheme.stripeHeight;

    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + toolbarH + _homeHeroBodyHeight(heroEvents) + stripeH,
      stretch: false,
      automaticallyImplyLeading: false,
      clipBehavior: Clip.hardEdge,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      toolbarHeight: toolbarH,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _IconBtn(
              icon: Icons.public_rounded,
              color: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialLinksScreen()),
              ),
            ),
            if (_isLive || _isEmissionLive) ...[
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _PulsingLiveBadge(pulse: _pulse.value),
                  ),
                ),
              ),
            ],
            if (_isLive &&
                _liveTeam1.isNotEmpty &&
                _liveTeam2.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: _HomeCollapsedLiveScore(
                  scoreHome: _scoreHome,
                  scoreAway: _scoreAway,
                ),
              ),
            ],
            const Spacer(),
            if (_userRole != null && _userRole != UserRole.supporter)
              _RolePill(role: _userRole!.displayName),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.search_rounded,
              onTap: () {
                final open = widget.onOpenGlobalSearch;
                if (open != null) {
                  open();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: !signedIn
                  ? Icons.person_outline_rounded
                  : Icons.person_rounded,
              onTap: () async {
                if (!signedIn) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthLockScreen()),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        onSwitchMainTab: widget.onSwitchTab,
                      ),
                    ),
                  );
                }
                _loadRole();
              },
            ),
          ],
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          _buildHeroFlexibleSpace(heroEvents),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: stripeH,
            child: DecoratedBox(
              decoration: BoxDecoration(color: HomeTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
