import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../navigation/main_shell_insets.dart';
import '../../models/fff_season_config.dart';
import '../../services/season_config_service.dart';
import '../../services/user_preferences_service.dart';
import '../../widgets/cssa_favorite_ranking_share_button.dart';
import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';
import '../calendar/widgets/calendar_ui.dart';
import 'matches_division_bar.dart';
import 'matches_helpers.dart';

class MatchesRankingTab extends StatefulWidget {
  const MatchesRankingTab({super.key});

  @override
  State<MatchesRankingTab> createState() => _MatchesRankingTabState();
}

class _MatchesRankingTabState extends State<MatchesRankingTab> {
  /// Choix utilisateur (session). Null = saison courante à l’arrivée.
  String? _pickedSeason;
  String? _pickedWhileCalendarSeason;
  String? _favoriteTeam;
  MatchesFffDivision _division = MatchesFffDivision.r1;

  /// Logos absents du doc classement → matchs, `ranking` R1, cache `fff_club_logos`.
  final Map<String, String> _matchLogoByTeam = {};
  String _lastHydrateKey = '';

  @override
  void initState() {
    super.initState();
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    UserPreferencesService.instance.addListener(_handleFavoriteTeamChanged);
    unawaited(UserPreferencesService.instance.init());
  }

  @override
  void dispose() {
    UserPreferencesService.instance.removeListener(_handleFavoriteTeamChanged);
    super.dispose();
  }

  void _handleFavoriteTeamChanged() {
    final next = UserPreferencesService.instance.favoriteTeam;
    if (!mounted || _favoriteTeam == next) {
      return;
    }
    setState(() => _favoriteTeam = next);
  }

  void _scheduleLogoHydration(String seasonKey, List<_RankEntry> entries) {
    if (entries.isEmpty) return;
    final needs = entries.where((e) => (e.logo ?? '').trim().isEmpty).toList();
    if (needs.isEmpty) return;

    final key = '$seasonKey|${entries.map((e) => e.team).join('\u0001')}';
    if (key == _lastHydrateKey) return;
    _lastHydrateKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateLogosFromMatches(needs.map((e) => e.team).toSet()));
    });
  }

  Future<void> _hydrateLogosFromMatches(Set<String> teamsNeeding) async {
    if (teamsNeeding.isEmpty) return;
    try {
      final byExact = <String, String>{};
      final byNorm = <String, String>{};

      void put(String team, String? logo) {
        final t = team.trim();
        final u = logo?.trim();
        if (t.isEmpty || u == null || u.isEmpty) return;
        byExact.putIfAbsent(t, () => u);
        byNorm.putIfAbsent(normalizeTeamLabel(t), () => u);
      }

      final matchesSnap = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('date', descending: true)
          .limit(160)
          .get();
      for (final doc in matchesSnap.docs) {
        final d = doc.data();
        put((d['team1'] as String?) ?? '', d['logo1'] as String?);
        put((d['team2'] as String?) ?? '', d['logo2'] as String?);
      }

      try {
        final r2Matches = await FirebaseFirestore.instance
            .collection('matches_r2')
            .orderBy('date', descending: true)
            .limit(160)
            .get();
        for (final doc in r2Matches.docs) {
          final d = doc.data();
          put((d['team1'] as String?) ?? '', d['logo1'] as String?);
          put((d['team2'] as String?) ?? '', d['logo2'] as String?);
        }
      } catch (_) {}

      // Écussons R1 / cache clubs si le calendrier n’a pas l’équipe.
      try {
        final r1 = await FirebaseFirestore.instance.collection('ranking').get();
        for (final doc in r1.docs) {
          final d = doc.data();
          put((d['team'] as String?) ?? '', d['logo'] as String?);
        }
      } catch (_) {}
      try {
        final cache =
            await FirebaseFirestore.instance.collection('fff_club_logos').get();
        for (final doc in cache.docs) {
          final d = doc.data();
          put(
            (d['shortName'] as String?) ?? (d['team'] as String?) ?? '',
            d['logo'] as String?,
          );
        }
      } catch (_) {}

      String? pickLogo(String rankingTeam) {
        final t = rankingTeam.trim();
        if (t.isEmpty) return null;
        final direct = byExact[t] ?? byNorm[normalizeTeamLabel(t)];
        if (direct != null) return direct;
        for (final e in byExact.entries) {
          if (teamMatchesPreference(t, e.key) ||
              teamMatchesPreference(e.key, t)) {
            return e.value;
          }
        }
        return null;
      }

      var changed = false;
      final next = Map<String, String>.from(_matchLogoByTeam);
      for (final team in teamsNeeding) {
        final url = pickLogo(team);
        if (url != null && next[team] != url) {
          next[team] = url;
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {
          _matchLogoByTeam
            ..clear()
            ..addAll(next);
        });
      }
    } catch (_) {
      // Pas d’index / réseau : rester sur initiales + logo ranking si présent
    }
  }

  String? _resolvedLogo(_RankEntry e) {
    final fromRanking = e.logo?.trim();
    if (fromRanking != null && fromRanking.isNotEmpty) return fromRanking;
    final cached = _matchLogoByTeam[e.team.trim()];
    if (cached != null && cached.isNotEmpty) return cached;
    for (final o in _matchLogoByTeam.entries) {
      if (teamMatchesPreference(e.team, o.key) ||
          teamMatchesPreference(o.key, e.team)) {
        return o.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, fffSnap) {
        final cfg = fffSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('ranking_archive').snapshots(),
          builder: (context, archSnap) {
            final archived =
                archSnap.data?.docs.map((d) => d.id).toList() ?? <String>[];
            final chips = FffSeasonConfig.seasonChips(cfg, archived);
            final calendar = FffSeasonConfig.frenchFootballSeasonLabel();
            final arrival = FffSeasonConfig.arrivalSeason(
              available: chips,
              configSeasonLabel: cfg.seasonLabel,
            );
            final pickValid = _pickedSeason != null &&
                chips.contains(_pickedSeason) &&
                _pickedWhileCalendarSeason == calendar;
            final displaySeason = pickValid ? _pickedSeason! : arrival;
            final useLive = displaySeason == cfg.seasonLabel ||
                (displaySeason == calendar && !archived.contains(displaySeason));
            final leagueHdr = useLive
                ? cfg.competitionDisplayName
                : _leagueLabelFromArchive(archSnap, displaySeason);
            final r2LeagueHdr = cfg.r2CompetitionDisplayName;
                final viewingR2 = _division == MatchesFffDivision.r2;

            Widget rankingBody() {
              if (viewingR2) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('ranking_r2')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _RankingLoadingBody();
                    }
                    if (snapshot.hasError) {
                      return _RankingErrorCard(
                        onRetry: () => setState(() {}),
                      );
                    }
                    final entries = _entriesFromLiveRanking(
                      snapshot,
                      displaySeason,
                    );
                    return _buildRankingList(
                      displaySeason,
                      entries,
                      leagueLabel: r2LeagueHdr,
                      hydrateLogosFromMatches: true,
                      r2Unwired: !cfg.hasR2FffSource,
                    );
                  },
                );
              }
              if (useLive) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('ranking')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _RankingLoadingBody();
                    }
                    if (snapshot.hasError) {
                      return _RankingErrorCard(
                        onRetry: () => setState(() {}),
                      );
                    }
                    final entries = _entriesFromLiveRanking(
                      snapshot,
                      displaySeason,
                    );
                    return _buildRankingList(
                      displaySeason,
                      entries,
                      leagueLabel: leagueHdr,
                    );
                  },
                );
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ranking_archive')
                    .doc(displaySeason)
                    .snapshots(),
                builder: (context, docSnap) {
                  if (docSnap.connectionState == ConnectionState.waiting &&
                      !docSnap.hasData) {
                    return const _RankingLoadingBody();
                  }
                  if (docSnap.hasError) {
                    return _RankingErrorCard(
                      onRetry: () => setState(() {}),
                    );
                  }
                  final entries = _entriesFromArchiveDoc(docSnap);
                  return _buildRankingList(
                    displaySeason,
                    entries,
                    leagueLabel: leagueHdr,
                  );
                },
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: _RankingClassementHeader(
                    season: displaySeason,
                    seasonChips: viewingR2 ? const [] : chips,
                    leagueLabel: viewingR2 ? r2LeagueHdr : leagueHdr,
                    favoriteTeam: _favoriteTeam,
                    showShare: !viewingR2,
                    onSeasonSelected: (s) => setState(() {
                      _pickedSeason = s;
                      _pickedWhileCalendarSeason =
                          FffSeasonConfig.frenchFootballSeasonLabel();
                      _lastHydrateKey = '';
                    }),
                  ),
                ),
                MatchesDivisionBar(
                  division: _division,
                  onChanged: (next) => setState(() {
                    _division = next;
                    _lastHydrateKey = '';
                  }),
                  r2Subtitle: cfg.r2CompetitionDisplayName,
                ),
                Expanded(child: rankingBody()),
              ],
            );
          },
        );
      },
    );
  }

  String _leagueLabelFromArchive(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> archSnap,
    String displaySeason,
  ) {
    for (final d in archSnap.data?.docs ?? const []) {
      if (d.id != displaySeason) continue;
      final ll = d.data()['leagueLabel'] as String?;
      if (ll != null && ll.trim().isNotEmpty) return ll.trim();
      break;
    }
    return 'Classement archivé · $displaySeason';
  }

  Widget _buildRankingList(
    String seasonKey,
    List<_RankEntry> entries, {
    required String leagueLabel,
    bool hydrateLogosFromMatches = true,
    bool r2Unwired = false,
  }) {
    if (hydrateLogosFromMatches) {
      _scheduleLogoHydration(seasonKey, entries);
    }

    final favoriteEntry = _favoriteTeam == null
        ? null
        : entries.cast<_RankEntry?>().firstWhere(
              (entry) =>
                  teamMatchesPreference(entry!.team, _favoriteTeam),
              orElse: () => null,
            );

    if (entries.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          MainShellInsets.tabScrollTail(context, extra: 8),
        ),
        children: [
          if (r2Unwired)
            const _RankingR2UnwiredCard()
          else
            _RankingEmptyCard(season: seasonKey, leagueLabel: leagueLabel),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        MainShellInsets.tabScrollTail(context, extra: 8),
      ),
      children: [
        if (favoriteEntry != null)
          _FavoriteRankingSpotlight(
            entry: favoriteEntry,
            favoriteTeam: _favoriteTeam!,
            resolvedLogo: _resolvedLogo(favoriteEntry),
          ),
        const _RankingColumnHeader(),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          return _RankingCard(
            entry: entry,
            position: index + 1,
            favoriteTeam: _favoriteTeam,
            resolvedLogo: _resolvedLogo(entry),
          );
        }),
      ],
    );
  }

  List<_RankEntry> _entriesFromLiveRanking(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    String seasonKey,
  ) {
    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
      final allDocs = snapshot.data!.docs;
      var docs = allDocs.where((doc) {
        final data = doc.data();
        final season = data['season'] as String?;
        return season == null || season == seasonKey;
      }).toList();
      // Saison active : si le libellé Firestore diverge, afficher quand même le live.
      if (docs.isEmpty) docs = List.from(allDocs);

      docs.sort((a, b) {
        final aPos = (a.data()['position'] as num?)?.toInt() ?? 999;
        final bPos = (b.data()['position'] as num?)?.toInt() ?? 999;
        return aPos.compareTo(bPos);
      });

      return docs.map((doc) {
        final data = doc.data();
        return _RankEntry(
          '${data['position'] ?? 0}',
          data['team'] as String? ?? '',
          data['logo'] as String?,
          data['mj'] as int? ?? 0,
          data['v'] as int? ?? 0,
          data['n'] as int? ?? 0,
          data['d'] as int? ?? 0,
          data['bf'] as int? ?? 0,
          data['bc'] as int? ?? 0,
          data['pts'] as int? ?? 0,
        );
      }).toList();
    }

    return [];
  }

  List<_RankEntry> _entriesFromArchiveDoc(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
  ) {
    final d = snap.data?.data();
    if (d == null) return [];
    final raw = d['rows'];
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _RankEntry(
        '${m['position'] ?? 0}',
        m['team'] as String? ?? '',
        m['logo'] as String?,
        (m['mj'] as num?)?.toInt() ?? 0,
        (m['v'] as num?)?.toInt() ?? 0,
        (m['n'] as num?)?.toInt() ?? 0,
        (m['d'] as num?)?.toInt() ?? 0,
        (m['bf'] as num?)?.toInt() ?? 0,
        (m['bc'] as num?)?.toInt() ?? 0,
        (m['pts'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}

class _RankingClassementHeader extends StatelessWidget {
  final String season;
  final List<String> seasonChips;
  final String leagueLabel;
  final String? favoriteTeam;
  final ValueChanged<String> onSeasonSelected;
  final bool showShare;

  const _RankingClassementHeader({
    required this.season,
    required this.seasonChips,
    required this.leagueLabel,
    required this.favoriteTeam,
    required this.onSeasonSelected,
    this.showShare = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CalendarTheme.gutter,
            8,
            CalendarTheme.gutter,
            10,
          ),
          child: Row(
            children: [
              Container(width: 16, height: 3, color: CalendarTheme.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASSEMENT',
                      style: CalendarType.kicker.copyWith(
                        color: CalendarTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leagueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CalendarType.title,
                    ),
                  ],
                ),
              ),
              if (showShare)
                CssaFavoriteRankingShareButton(
                  season: season,
                  favoriteTeam: favoriteTeam,
                  leagueLabel: leagueLabel,
                  style: CssaRankingShareStyle.matchesCard,
                ),
            ],
          ),
        ),
        if (seasonChips.length > 1)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CalendarTheme.gutter,
              ),
              itemCount: seasonChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final s = seasonChips[i];
                return CalendarFilterChip(
                  label: s,
                  selected: s == season,
                  onTap: () => onSeasonSelected(s),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RankingColumnHeader extends StatelessWidget {
  const _RankingColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CalendarTheme.tableHeaderPaper(),
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        10,
        CalendarTheme.gutter,
        10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#', style: CalendarType.kicker),
          ),
          const SizedBox(width: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CLUB',
              style: CalendarType.kicker.copyWith(color: CalendarTheme.text),
            ),
          ),
          _colLabel('MJ'),
          _colLabel('V'),
          _colLabel('N'),
          _colLabel('D'),
          _colLabel('DIFF'),
          _colLabel('PTS', isLast: true),
        ],
      ),
    );
  }

  Widget _colLabel(String t, {bool isLast = false}) {
    return SizedBox(
      width: isLast ? 38 : 28,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: CalendarType.kicker.copyWith(
          color: isLast ? CalendarTheme.text : CalendarTheme.textSoft,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _RankingLoadingBody extends StatelessWidget {
  const _RankingLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MainShellInsets.tabScrollTail(context, extra: 8),
      ),
      children: const [CalendarLoadingTape(rows: 8)],
    );
  }
}

class _RankingErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _RankingErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MainShellInsets.tabScrollTail(context, extra: 8),
      ),
      children: [
        CalendarErrorState(
          title: 'Classement indisponible',
          body:
              'Impossible de charger le tableau pour le moment. Vérifie ta connexion et réessaie.',
          action: TextButton(
            onPressed: onRetry,
            child: Text(
              'RÉESSAYER',
              style: CalendarType.kicker.copyWith(color: CalendarTheme.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingEmptyCard extends StatelessWidget {
  final String season;
  final String leagueLabel;

  const _RankingEmptyCard({
    required this.season,
    required this.leagueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CalendarEmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'Classement à venir',
      body: '$leagueLabel · $season\n'
          'Le tableau sera publié dès le début de championnat '
          'ou après la prochaine journée.',
    );
  }
}

class _RankingR2UnwiredCard extends StatelessWidget {
  const _RankingR2UnwiredCard();

  @override
  Widget build(BuildContext context) {
    return const CalendarEmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'Régional 2 à brancher',
      body:
          'Équipe réserve · classement Régional 2.\n'
          'Les identifiants FFF (compétition / poule) ne sont pas encore '
          'renseignés — aucun tableau n’est inventé. Un admin peut les coller '
          'dans Réglages → saison FFF (fffR2CompetitionId), puis lancer une '
          'synchro. Le calendrier réserve est dans À venir / Résultats.',
    );
  }
}

Color? _podiumAccent(int position) {
  switch (position) {
    case 1:
      return CalendarTheme.podiumGold;
    case 2:
      return CalendarTheme.podiumSilver;
    case 3:
      return CalendarTheme.podiumBronze;
    default:
      return null;
  }
}

class _RankingCard extends StatelessWidget {
  final _RankEntry entry;
  final int position;
  final String? favoriteTeam;
  final String? resolvedLogo;

  const _RankingCard({
    required this.entry,
    required this.position,
    required this.resolvedLogo,
    this.favoriteTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorite = teamMatchesPreference(entry.team, favoriteTeam);
    final isSedan = isSedanTeam(entry.team);
    final isHighlighted = isFavorite || (favoriteTeam == null && isSedan);
    final diff = entry.bf - entry.bc;
    final podium = _podiumAccent(position);

    return Container(
      decoration: CalendarTheme.fixtureTape(),
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        12,
        CalendarTheme.gutter,
        12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$position',
              style: CalendarType.rank.copyWith(
                color: podium ??
                    (isHighlighted
                        ? CalendarTheme.accent
                        : CalendarTheme.textSoft),
              ),
            ),
          ),
          _RankingTeamLogo(
            team: entry.team,
            resolvedUrl: resolvedLogo,
            highlighted: isHighlighted,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.team,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CalendarType.fixture.copyWith(
                fontSize: 16,
                color: isHighlighted ? CalendarTheme.text : CalendarTheme.text,
              ),
            ),
          ),
          _statCell('${entry.mj}'),
          _statCell('${entry.v}'),
          _statCell('${entry.n}'),
          _statCell('${entry.d}'),
          _statCell('${diff > 0 ? '+' : ''}$diff', color: _diffColor(diff)),
          SizedBox(
            width: 38,
            child: Text(
              '${entry.pts}',
              textAlign: TextAlign.center,
              style: CalendarType.rank.copyWith(
                color: isHighlighted ? CalendarTheme.accent : CalendarTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, {Color? color}) {
    return SizedBox(
      width: 28,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: CalendarType.meta.copyWith(
          color: color ?? CalendarTheme.textMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

Color _diffColor(int diff) {
  if (diff > 0) return CalendarTheme.accent;
  if (diff < 0) return CalendarTheme.red;
  return CalendarTheme.textMuted;
}

class _FavoriteRankingSpotlight extends StatelessWidget {
  final _RankEntry entry;
  final String favoriteTeam;
  final String? resolvedLogo;

  const _FavoriteRankingSpotlight({
    required this.entry,
    required this.favoriteTeam,
    required this.resolvedLogo,
  });

  @override
  Widget build(BuildContext context) {
    final diff = entry.bf - entry.bc;
    final pos = int.tryParse(entry.pos) ?? 0;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CalendarTheme.surface,
        border: Border(
          left: BorderSide(color: CalendarTheme.gold, width: 3),
          top: BorderSide(color: CalendarTheme.hairline),
          bottom: BorderSide(color: CalendarTheme.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CalendarTheme.gutter,
          16,
          CalendarTheme.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MON ÉQUIPE', style: CalendarType.kicker),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pos > 0 ? '${entry.pos}e' : '—',
                  style: CalendarType.display.copyWith(fontSize: 46),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          favoriteTeam,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CalendarType.title,
                        ),
                        Text(
                          '${entry.pts} pts · ${entry.mj} MJ',
                          style: CalendarType.caption,
                        ),
                      ],
                    ),
                  ),
                ),
                _RankingTeamLogo(
                  team: entry.team,
                  resolvedUrl: resolvedLogo,
                  highlighted: true,
                  size: 36,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _spotStat('${entry.v}', 'V'),
                _spotStat('${entry.n}', 'N'),
                _spotStat('${entry.d}', 'D'),
                _spotStat('${diff > 0 ? '+' : ''}$diff', 'DIFF'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: CalendarType.stat.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: CalendarType.kicker),
        ],
      ),
    );
  }
}

class _RankEntry {
  final String pos;
  final String team;
  final String? logo;
  final int mj;
  final int v;
  final int n;
  final int d;
  final int bf;
  final int bc;
  final int pts;

  const _RankEntry(
    this.pos,
    this.team,
    this.logo,
    this.mj,
    this.v,
    this.n,
    this.d,
    this.bf,
    this.bc,
    this.pts,
  );
}

class _RankingTeamLogo extends StatelessWidget {
  final String team;
  final String? resolvedUrl;
  final bool highlighted;
  final double size;

  const _RankingTeamLogo({
    required this.team,
    required this.resolvedUrl,
    required this.highlighted,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolvedUrl?.trim();
    final child = url != null && url.isNotEmpty
        ? Image.network(
            url,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                _RankingLogoFallback(team: team, highlighted: highlighted),
          )
        : _RankingLogoFallback(team: team, highlighted: highlighted);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CalendarTheme.inkRadius),
        border: Border.all(color: CalendarTheme.hairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _RankingLogoFallback extends StatelessWidget {
  final String team;
  final bool highlighted;

  const _RankingLogoFallback({required this.team, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        teamInitials(team),
        style: CalendarType.kicker.copyWith(
          color: highlighted ? CalendarTheme.accent : CalendarTheme.textMuted,
        ),
      ),
    );
  }
}
