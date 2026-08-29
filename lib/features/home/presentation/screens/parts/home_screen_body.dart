part of '../home_screen.dart';

mixin _HomeScreenBodyMixin on _HomeScreenController {
  @override
  Widget build(BuildContext context) {
    _layoutHints = ref.watch(homeLayoutHintsProvider).asData?.value ??
        HomeLayoutHints.defaults;
    _homeBannerUrl = ref.watch(homeBannerPhotoUrlProvider).asData?.value;
    final sectionsConfig =
        ref.watch(homeSectionsConfigProvider).asData?.value ??
            HomeSectionsConfig.defaults;
    final podcastRendezVousAt = sectionsConfig.podcastNextEventAt;
    return Scaffold(
      backgroundColor: HomeTheme.scaffold,
      body: RefreshIndicator(
        color: HomeTheme.green,
        backgroundColor: HomeTheme.surface,
        onRefresh: () => ref.read(homeMatchCatalogAdapterProvider).forceRefresh(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // â"€â"€ AppBar + Hero intégrés (photo du tout haut) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            _buildAppBarWithHero(),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 28),
                child: const LiveInteractionHomeSlot(),
              ),
            ),
            // « Rejoins la famille DVCR » — immediately above Prochaine rencontre.
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 32),
                child: const AdhesionBanner(slot: 'home'),
              ),
            ),
            if (!_isLive) ...[
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 36),
                  child: _NextMatchSectionHeader(
                    onSeeAll: () => _switchMain(2, matchesSubTab: 0),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 44),
                  child: _NextMatchCard(
                    onOpenActu: () => _switchMain(3),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],

            // Sous « Prochain match » — jamais sous le hero live.
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 50),
                child: const DugauguezPlaceHomeSlot(),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 56),
                child: const EmissionPollHomeSlot(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // DVCR TV -> photo pub (DonationBanner) -> Podcast DVCR
            if (!(_layoutHints.hideDvcrTvBlockWhenAnyLive &&
                (_isLive || _isEmissionLive))) ...[
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 76),
                child: HomeSectionHeader(
                  title: 'DVCR TV',
                  subtitle: 'Les derniers replays et contenus DVCR',
                  icon: Icons.play_circle_outline_rounded,
                  onSeeAll: () => _switchMain(1),
                ),
              ),
            ),
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 82),
                  child: _DVCRTVRow(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
            ],

            if (!(_layoutHints.hideDonationBannerWhenAnyLive &&
                (_isLive || _isEmissionLive)))
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 220),
                  child: const DonationBanner(
                    slot: SoutenezDvcrBannerSlot.home,
                  ),
                ),
              ),

            if (!(_layoutHints.hidePodcastBlockWhenAnyLive &&
                (_isLive || _isEmissionLive))) ...[
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 62),
                  child: HomeSectionHeader(
                    title: 'PODCAST DVCR',
                    subtitle: podcastRendezVousAt == null
                        ? 'Chroniques, débats et Dudule Quiz'
                        : _formatPodcastRendezVous(podcastRendezVousAt),
                    icon: Icons.headphones_rounded,
                    trailing: _roles.contains(UserRole.admin)
                        ? _PodcastQuickEditButton(
                            onTap: () => _openPodcastRendezVousEditor(
                              podcastRendezVousAt,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 175),
                  child: const _PodcastSection(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ACTUS
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'ACTUS',
                subtitle: 'Les nouvelles du club, de la commu et du terrain',
                icon: Icons.article_outlined,
                showBadge: false,
                onSeeAll: () => _switchMain(3),
              ),
            ),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            SliverToBoxAdapter(
              child: _ArticlesFeed(category: _categories[_categoryIndex]),
            ),

            // â"€â"€ Derniers résultats â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            SliverToBoxAdapter(
              child: HomeSectionHeader(
            title: 'RÉSULTATS',
            subtitle: 'Retrouve les derniers résultats du CSSA',
                icon: Icons.emoji_events_rounded,
                accent: _kGreen,
                showBadge: false,
                onSeeAll: () => _switchMain(2, matchesSubTab: 1),
              ),
            ),
            SliverToBoxAdapter(child: _ResultsFeed()),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // â"€â"€ Mini-classement pronos â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            if (_publicPronoFeaturesEnabled)
              SliverToBoxAdapter(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          HomeSectionHeader(
                            title: 'CLASSEMENT PRONOS',
                            subtitle: 'Les meilleurs pronostiqueurs du moment',
                            icon: Icons.leaderboard_rounded,
                            onSeeAll: null,
                          ),
                          _PronoLeaderboardMiniCard(onSeeAll: null),
                        ],
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            color: Colors.white.withAlpha(140),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: homeBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFD8D2C4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Color(0xFF6E776F),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Bientôt disponible',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6E776F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: MainShellInsets.tabScrollTail(context)),
            ),
          ],
        ),
      ),
    );
  }
}
