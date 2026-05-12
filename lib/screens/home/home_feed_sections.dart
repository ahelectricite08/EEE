part of 'home_screen.dart';

Stream<String?> _watchHomeStadiumHero(String teamName) => FirebaseFirestore
    .instance
    .collection('teams')
    .where('name', isEqualTo: teamName)
    .limit(1)
    .snapshots()
    .map((snap) {
      if (snap.docs.isEmpty) return null;
      final url = (snap.docs.first.data()['stadiumImageUrl'] as String?)
          ?.trim();
      return (url == null || url.isEmpty) ? null : url;
    });

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':
      return const Color(0xFF4CAF50);
    case 'AVANT-MATCH':
      return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':
      return const Color(0xFF2196F3);
    case 'ANALYSE':
      return const Color(0xFF9C27B0);
    case 'COULISSES':
      return const Color(0xFFFF9800);
    case 'CLUB':
      return _kRed;
    case ArticleModel.kUncategorizedToutOnly:
      return _kGrey;
    default:
      return _kRed;
  }
}

bool _isSedanMatch(MatchModel match) {
  final team1 = match.team1.toUpperCase();
  final team2 = match.team2.toUpperCase();
  return team1.contains('SEDAN') ||
      team1.contains('CSSA') ||
      team2.contains('SEDAN') ||
      team2.contains('CSSA');
}

/// Victoire / défaite / nul du point de vue du CSSA (team1 = domicile, team2 = extérieur).
String _cssaResultLabel(MatchModel match) {
  if (match.score1 == null || match.score2 == null) return 'EN ATTENTE';
  final s1 = match.score1!;
  final s2 = match.score2!;
  final t1 = match.team1.toUpperCase();
  final t2 = match.team2.toUpperCase();
  final sedan1 = t1.contains('SEDAN') || t1.contains('CSSA');
  final sedan2 = t2.contains('SEDAN') || t2.contains('CSSA');
  if (!sedan1 && !sedan2) {
    if (s1 == s2) return 'MATCH NUL';
    return s1 > s2 ? 'VICTOIRE' : 'DÉFAITE';
  }
  final cssaGoals = sedan1 ? s1 : s2;
  final oppGoals = sedan1 ? s2 : s1;
  if (cssaGoals == oppGoals) return 'MATCH NUL';
  return cssaGoals > oppGoals ? 'VICTOIRE' : 'DÉFAITE';
}

bool _looseTeamName(String a, String b) {
  final at = a.trim().toUpperCase();
  final bt = b.trim().toUpperCase();
  if (at.isEmpty || bt.isEmpty) return false;
  final aw = at
      .split(RegExp(r'\s+'))
      .firstWhere((s) => s.isNotEmpty, orElse: () => at);
  final bw = bt
      .split(RegExp(r'\s+'))
      .firstWhere((s) => s.isNotEmpty, orElse: () => bt);
  return at.contains(bw) || bt.contains(aw);
}

bool _hubCoversMatch(LiveHubState hub, MatchModel m) {
  final id = hub.liveMatchId.trim();
  if (id.isNotEmpty) return id == m.id;
  final t1 = hub.matchTeam1.toUpperCase();
  final t2 = hub.matchTeam2.toUpperCase();
  if (t1.isEmpty && t2.isEmpty) return false;
  final m1 = m.team1.toUpperCase();
  final m2 = m.team2.toUpperCase();
  return (_looseTeamName(t1, m1) && _looseTeamName(t2, m2)) ||
      (_looseTeamName(t1, m2) && _looseTeamName(t2, m1));
}

MatchModel? _findMatchForLiveHub(MatchController ctrl, LiveHubState hub) {
  if (!hub.isMatchLive) return null;
  final id = hub.liveMatchId.trim();
  if (id.isNotEmpty) {
    for (final m in [...ctrl.upcoming, ...ctrl.results]) {
      if (m.id == id) return m;
    }
    // Ne pas retomber sur un matching flou : un autre match (ex. futur) pourrait
    // absorber le flux live si le `matchId` du hub ne correspond plus au calendrier.
    return null;
  }
  for (final m in [...ctrl.upcoming, ...ctrl.results]) {
    if (_hubCoversMatch(hub, m)) return m;
  }
  return null;
}

const Duration _homeMatchHoldAfterKickoff = Duration(hours: 2);

/// 1) `live/current` actif → ce match (carte live éditoriale). 2) Sinon **prochain** Sedan à venir
/// (match terminé = on ne reste plus sur l’écran résultat ici).
MatchModel _pickHomeFeaturedMatch(MatchController ctrl, LiveHubState hub) {
  final liveM = _findMatchForLiveHub(ctrl, hub);
  if (liveM != null) {
    return liveM;
  }

  final sedanUpcoming = ctrl.upcoming.where(_isSedanMatch).toList();
  if (sedanUpcoming.isNotEmpty) {
    return sedanUpcoming.first;
  }

  return MatchModel.mockUpcoming.first;
}

/// IDs `m1`, `m2`… (carte d’illustration) : pas de doc `predictions` alignée avec le hub prono.
bool _isHomePronoPlaceholderMatchId(String id) =>
    RegExp(r'^m\d+$').hasMatch(id.trim());

MatchModel _buildHomeDisplayMatch(MatchModel match, LiveHubState hub) {
  // Tant que `live/current` existe pour ce match, carte **toujours** en mode direct
  // (même si `matches/{id}` est déjà repassé en `finished` — sinon écran TERMINÉ / footer nul).
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return MatchModel(
      id: match.id,
      team1: hub.matchTeam1.isNotEmpty ? hub.matchTeam1 : match.team1,
      team2: hub.matchTeam2.isNotEmpty ? hub.matchTeam2 : match.team2,
      logo1: hub.matchLogo1.isNotEmpty ? hub.matchLogo1 : match.logo1,
      logo2: hub.matchLogo2.isNotEmpty ? hub.matchLogo2 : match.logo2,
      score1: match.score1,
      score2: match.score2,
      date: match.date,
      competition: match.competition,
      status: MatchStatus.live,
      replayVideoId: match.replayVideoId,
      stats: match.stats,
      rank1: match.rank1,
      rank2: match.rank2,
      form1: match.form1,
      form2: match.form2,
      wdl1: match.wdl1,
      wdl2: match.wdl2,
      stadiumImageUrl: match.stadiumImageUrl,
      earlyPublish: match.earlyPublish,
      fffSeason: match.fffSeason,
    );
  }

  return match;
}

String _homeFeaturedSectionTitle(MatchModel match, LiveHubState hub) {
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return 'Match en direct';
  }
  return 'Prochain match';
}

IconData _homeFeaturedSectionIcon(MatchModel match, LiveHubState hub) {
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return Icons.live_tv_rounded;
  }
  return Icons.event_available_rounded;
}

class _NextMatchSectionHeader extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const _NextMatchSectionHeader({this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life =
            lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        if (life.betweenSeasons) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: const Color(0xFF1E6B56),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A4438).withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF0A4438).withAlpha(48),
                    ),
                  ),
                  child: const Icon(
                    Icons.stadium_rounded,
                    size: 22,
                    color: Color(0xFF0A4438),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        life.homeHeadline,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _kText,
                          letterSpacing: 0.2,
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        life.homeSubline,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextSub,
                          letterSpacing: 0.12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  InkWell(
                    onTap: onSeeAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Calendrier',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0A4438),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: _kText.withAlpha(160),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return StreamBuilder<LiveHubState>(
          stream: LiveStateService.watch(),
          initialData: LiveHubState.empty,
          builder: (context, hubSnap) {
            final hub = hubSnap.data ?? LiveHubState.empty;
            return ListenableBuilder(
              listenable: MatchController.instance,
              builder: (context, _) {
                final ctrl = MatchController.instance;
                final match = _buildHomeDisplayMatch(
                  _pickHomeFeaturedMatch(ctrl, hub),
                  hub,
                );
                final subtitle = _buildContextLabel(match, hub);
                final title = _homeFeaturedSectionTitle(match, hub);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: const Color(0xFF1E6B56),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A4438).withAlpha(12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF0A4438).withAlpha(48),
                          ),
                        ),
                        child: Icon(
                          _homeFeaturedSectionIcon(match, hub),
                          size: 22,
                          color: const Color(0xFF0A4438),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              key: ValueKey<String>(title),
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kText,
                                letterSpacing: 0.2,
                                height: 0.95,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: Text(
                                subtitle,
                                key: ValueKey<String>(subtitle),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextSub,
                                  letterSpacing: 0.12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onSeeAll != null)
                        InkWell(
                          onTap: onSeeAll,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tout voir',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0A4438),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: _kText.withAlpha(160),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _buildContextLabel(MatchModel match, LiveHubState hub) {
    if (match.status == MatchStatus.live) {
      if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
        final minBit = hub.minute > 0 ? "${hub.minute}' · " : '';
        return 'En direct · $minBit${match.competition}';
      }
      return '${match.competition}';
    }
    final now = DateTime.now();
    final difference = match.date.difference(now);
    if (difference.isNegative) {
      final elapsed = now.difference(match.date);
      if (elapsed <= _homeMatchHoldAfterKickoff) {
        return 'Depuis ${_timeLabel(match.date)} · ${match.competition}';
      }
      return 'Terminé · ${_dateLabel(match.date)}';
    }
    if (difference.inDays <= 0) {
      return 'Aujourd\'hui à ${_timeLabel(match.date)} · ${match.competition}';
    }
    if (difference.inDays == 1) {
      return 'Demain à ${_timeLabel(match.date)} · ${match.competition}';
    }
    if (difference.inDays < 7) {
      return 'Dans ${difference.inDays} jours · ${match.competition}';
    }
    if (difference.inDays < 14) {
      return 'La semaine prochaine · ${_dateLabel(match.date)}';
    }
    final weeks = (difference.inDays / 7).floor();
    if (weeks >= 2) {
      return 'Dans $weeks semaines · ${_dateLabel(match.date)}';
    }
    return _dateLabel(match.date);
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${hour}h$minute';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return 'Le ${date.day} ${months[date.month - 1]} à ${_timeLabel(date)}';
  }
}

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
              stream: LiveStateService.watch(),
              initialData: LiveHubState.empty,
              builder: (context, hubSnap) {
                final hub = hubSnap.data ?? LiveHubState.empty;
                return ListenableBuilder(
                  listenable: FeatureFlagsService.notifier,
                  builder: (context, __) {
                    return ListenableBuilder(
                      listenable: MatchController.instance,
                      builder: (context, _) {
                        final ctrl = MatchController.instance;
                        final match = _buildHomeDisplayMatch(
                          _pickHomeFeaturedMatch(ctrl, hub),
                          hub,
                        );

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
                                showStats: true,
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
                                stream: FirebaseFirestore.instance
                                    .collection('predictions')
                                    .doc('${match.id}_${user.uid}')
                                    .snapshots(),
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
                                    showStats: true,
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
                            showStats: true,
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

class _ArticlesFeed extends StatelessWidget {
  final String category;
  const _ArticlesFeed({required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArticleModel>>(
      stream: ArticleService.all(
        category: category == 'TOUT' ? null : category,
        limit: 5,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Column(
            children: const [
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
            ],
          );
        }
        final articles = snap.data!;
        if (articles.isEmpty) return const SizedBox();

        return Column(
          children: articles.asMap().entries.map((e) {
            final article = e.value;
            final color = _catColor(article.category);

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArticleDetailScreen(article: article),
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (article.displayCategoryLabel.isNotEmpty) ...[
                                Text(
                                  article.displayCategoryLabel.toUpperCase(),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '  ·  ',
                                  style: GoogleFonts.barlow(
                                    fontSize: 11,
                                    color: _kGrey,
                                  ),
                                ),
                              ],
                              Text(
                                _relDate(article.date),
                                style: GoogleFonts.barlow(
                                  fontSize: 11,
                                  color: _kGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _kText,
                              height: 1.08,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 86,
                      height: 62,
                      decoration: BoxDecoration(
                        color: homeSurfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: article.imageUrl != null
                          ? Image.network(
                              article.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.article_outlined,
                                size: 20,
                                color: color.withAlpha(80),
                              ),
                            )
                          : Icon(
                              Icons.article_outlined,
                              size: 20,
                              color: color.withAlpha(80),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResultsFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MatchController.instance,
      builder: (context, _) {
        final raw = MatchController.instance.results.isNotEmpty
            ? MatchController.instance.results
            : MatchModel.mockResults;
        final matches = raw.where(_isSedanMatch).take(3).toList();

        return Column(
          children: matches
              .map(
                (m) => _HomeResultCard(
                  match: m,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(match: m),
                    ),
                  ),
                  onReplay: m.replayVideoId != null
                      ? () {
                          final video = VideoModel(
                            id: m.id,
                            title: '${m.team1} - ${m.team2}',
                            youtubeId: m.replayVideoId!,
                            duration: '',
                            date: m.date,
                            category: 'resume',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoWebScreen(video: video),
                            ),
                          );
                        }
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HomeResultCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  final VoidCallback? onReplay;

  const _HomeResultCard({
    required this.match,
    required this.onTap,
    this.onReplay,
  });

  bool get _isSedanMatch {
    final t1 = match.team1.toUpperCase();
    final t2 = match.team2.toUpperCase();
    return t1.contains('SEDAN') ||
        t1.contains('CSSA') ||
        t2.contains('SEDAN') ||
        t2.contains('CSSA');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 156,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (match.stadiumImageUrl != null &&
                      match.stadiumImageUrl!.isNotEmpty)
                    Image.network(
                      match.stadiumImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: homeSurfaceMuted),
                    )
                  else
                    StreamBuilder<String?>(
                      stream: _watchHomeStadiumHero(match.team1),
                      builder: (context, snapshot) {
                        final url = snapshot.data;
                        if (url != null && url.isNotEmpty) {
                          return Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: homeSurfaceMuted),
                          );
                        }
                        return Container(color: homeSurfaceMuted);
                      },
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(40),
                            Colors.black.withAlpha(10),
                            Colors.black.withAlpha(55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _HomeMatchPill(
                      label: match.competition,
                      color: _kText,
                      bg: Colors.white.withAlpha(220),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _HomeMatchPill(
                      label: 'TERMINE',
                      color: _kGreen,
                      bg: Colors.white.withAlpha(220),
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 46,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _HomeClubSide(
                            name: match.team1,
                            logoUrl: match.logo1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                match.score1 != null
                                    ? '${match.score1} · ${match.score2}'
                                    : 'Bientôt',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: match.score1 != null ? 38 : 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 0.9,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _fmtDate(match.date),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kGreen.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kGreen.withAlpha(70)),
                    ),
                    child: Text(
                      _cssaResultLabel(match),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onReplay ?? onTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isSedanMatch ? _kGreen.withAlpha(14) : _kCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isSedanMatch
                              ? _kGreen.withAlpha(48)
                              : _kBorder,
                        ),
                      ),
                      child: Text(
                        _isSedanMatch && onReplay != null
                            ? 'Voir le replay'
                            : 'Voir le match',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _isSedanMatch ? _kGreen : _kText,
                        ),
                      ),
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

class _HomeClubSide extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool alignEnd;

  const _HomeClubSide({
    required this.name,
    required this.logoUrl,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(180)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: logoUrl != null && logoUrl!.isNotEmpty
                ? Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF173C31),
                    ),
                  )
                : const Icon(Icons.shield_outlined, color: Color(0xFF173C31)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _HomeMatchPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;

  const _HomeMatchPill({
    required this.label,
    required this.color,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(150)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
