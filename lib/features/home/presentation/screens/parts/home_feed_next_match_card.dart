part of '../home_screen.dart';

class _NextMatchCard extends StatelessWidget {
  final HomeMainTabSwitch? onSwitchMainTab;

  const _NextMatchCard({this.onSwitchMainTab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life =
            lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        if (life.betweenSeasons) {
          return _HomeBetweenSeasonsFeaturedBody(config: life);
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            final user = authSnap.data;
            final isLogged = user != null;

            return StreamBuilder<LiveHubState>(
              stream: const HomeLiveHubAdapter().watch(),
              initialData: LiveHubState.empty,
              builder: (context, hubSnap) {
                final hub = hubSnap.data ?? LiveHubState.empty;
                return ListenableBuilder(
                  listenable: FeatureFlagsService.notifier,
                  builder: (context, __) {
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

                    const lockedFooter = Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: Color(0xFF6E776F),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pronos · ouverture 7 j avant le match',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: Color(0xFF6E776F),
                            ),
                          ),
                        ],
                      ),
                    );

                    final hidePronoBar = match.status == MatchStatus.live ||
                        match.status == MatchStatus.finished;

                    Widget? footerOverride;
                    if (!PronoChampionshipRollout.isHubVisible) {
                      footerOverride = null;
                    } else if (hidePronoBar) {
                      footerOverride = null;
                    } else if (isMatchPronoWindowOpen(match.date)) {
                      final demoFeatured =
                          _isHomePronoPlaceholderMatchId(match.id);
                      void openProno() {
                        if (demoFeatured) {
                          onSwitchMainTab?.call(5);
                          return;
                        }
                        openPronoForMatch(context, matchId: match.id);
                      }

                      if (isLogged && demoFeatured) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                          child: HomeScaleOnPress(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(6),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: MatchCard(
                                match: match,
                                surface: MatchCardSurface.homeEditorial,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MatchDetailScreen(match: match),
                                  ),
                                ),
                                showStats: match.showStatsOnCard,
                                showLiveStatsEntry:
                                    _homeShowLiveStatsOnCard(match, hub),
                                footerOverride: _HomeFeaturedPronoFooter(
                                  title: 'Voir l’onglet Pronos',
                                  subtitle:
                                      'Les pronos suivent les matchs réels du calendrier.',
                                  onTap: openProno,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (isLogged && !demoFeatured) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                          child: HomeScaleOnPress(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(6),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: StreamBuilder<DocumentSnapshot>(
                                stream: HomePredictionDatasource()
                                    .watchPrediction(
                                  matchId: match.id,
                                  uid: user.uid,
                                ),
                                builder: (context, pronoSnap) {
                                  final hasPred = pronoSnap.hasData &&
                                      pronoSnap.data!.exists;
                                  final pd = hasPred
                                      ? pronoSnap.data!.data()
                                          as Map<String, dynamic>?
                                      : null;
                                  final s1 = MatchModel.parseScoreField(
                                    pd?['score1Pred'],
                                  );
                                  final s2 = MatchModel.parseScoreField(
                                    pd?['score2Pred'],
                                  );
                                  final sub = hasPred &&
                                          s1 != null &&
                                          s2 != null
                                      ? 'Ton prono : $s1 — $s2'
                                      : 'Tape pour ouvrir le formulaire';

                                  return MatchCard(
                                    match: match,
                                    surface: MatchCardSurface.homeEditorial,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MatchDetailScreen(match: match),
                                      ),
                                    ),
                                    showStats: match.showStatsOnCard,
                                    showLiveStatsEntry:
                                        _homeShowLiveStatsOnCard(match, hub),
                                    footerOverride: _HomeFeaturedPronoFooter(
                                      title: hasPred
                                          ? 'Modifier mon prono'
                                          : 'Pronostiquer ce match',
                                      subtitle: sub,
                                      onTap: openProno,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }

                      footerOverride = _HomeFeaturedPronoFooter(
                        title: demoFeatured
                            ? 'Voir l’onglet Pronos'
                            : 'Pronostiquer ce match',
                        subtitle: demoFeatured
                            ? 'Connecte-toi · vrais matchs dans Pronos'
                            : 'Connecte-toi si besoin · ligue DVCR',
                        onTap: openProno,
                      );
                    } else {
                      footerOverride = lockedFooter;
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: HomeScaleOnPress(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _kBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: MatchCard(
                            match: match,
                            surface: MatchCardSurface.homeEditorial,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MatchDetailScreen(match: match),
                              ),
                            ),
                            showStats: match.showStatsOnCard,
                            showLiveStatsEntry:
                                _homeShowLiveStatsOnCard(match, hub),
                            footerOverride: footerOverride,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
      },
    );
  }
}
