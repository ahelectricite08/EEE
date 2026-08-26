import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../navigation/main_shell_insets.dart';
import '../../models/fff_season_config.dart';
import '../../models/match_model.dart';
import '../../models/video_model.dart';
import '../../services/match_service.dart';
import '../../services/season_config_service.dart';
import '../../utils/match_calendar_filter.dart';
import '../../services/user_preferences_service.dart';
import '../../services/user_service.dart';
import '../../utils/open_prono_for_match.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../models/season_lifecycle_config.dart';
import '../../services/season_lifecycle_service.dart';
import '../../utils/youtube_parser.dart';
import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';
import '../calendar/widgets/calendar_date_header.dart';
import '../calendar/widgets/calendar_fixture_tile.dart';
import '../calendar/widgets/calendar_ui.dart';
import '../match_detail_screen.dart';
import '../video_web_screen.dart';
import 'matches_helpers.dart';

DateTime _pronoOpenAt(DateTime matchDate) => DateTime(
      matchDate.year,
      matchDate.month,
      matchDate.day,
    ).subtract(const Duration(days: 7));

bool _isPronoOpen(DateTime matchDate) {
  final now = DateTime.now();
  return now.isAfter(_pronoOpenAt(matchDate)) && now.isBefore(matchDate);
}

String _pronoStatusLabel(DateTime matchDate) {
  if (_isPronoOpen(matchDate)) return 'Pronostiquer';
  final now = DateTime.now();
  final openAt = _pronoOpenAt(matchDate);
  if (!now.isBefore(openAt)) return 'Bientôt fermé';
  final diff = openAt.difference(now);
  final days = diff.inDays;
  if (days <= 0) return 'À pronostiquer bientôt';
  if (days == 1) return 'À pronostiquer dans 1 jour';
  return 'À pronostiquer dans $days jours';
}

class MatchesFeedTab extends StatefulWidget {
  final MatchesViewMode mode;
  final DateTime focusMonth;

  const MatchesFeedTab({
    super.key,
    required this.mode,
    required this.focusMonth,
  });

  @override
  State<MatchesFeedTab> createState() => _MatchesFeedTabState();
}

class _MatchesFeedTabState extends State<MatchesFeedTab> {
  String? _selectedCompetition;
  String? _selectedTeam;
  String? _favoriteTeam;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((value) {
      if (mounted) setState(() => _isAdmin = value);
    });
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

    setState(() {
      _favoriteTeam = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.mode == MatchesViewMode.upcoming
        ? MatchService.upcoming()
        : MatchService.forMonth(
            widget.focusMonth.year,
            widget.focusMonth.month,
          );

    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, seasonSnap) {
        final season = seasonSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<SeasonLifecycleConfig>(
          stream: SeasonLifecycleService.stream(),
          builder: (context, lifeSnap) {
            final life = lifeSnap.data ?? SeasonLifecycleConfig.defaults;
            final between = life.betweenSeasons;

            return StreamBuilder<List<MatchModel>>(
              key: ValueKey<Object>(
                '${widget.mode.name}_${widget.focusMonth.year}_${widget.focusMonth.month}_${between}_${season.seasonLabel}',
              ),
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      8,
                      0,
                      MainShellInsets.tabScrollTail(context, extra: 8),
                    ),
                    children: const [
                      CalendarLoadingTape(rows: 6),
                    ],
                  );
                }
                final noMockBetween =
                    between && widget.mode == MatchesViewMode.upcoming;
                var source = snapshot.hasData
                    ? snapshot.data!.where((m) {
                        if (!MatchCalendarFilter.belongsToSeason(
                          m,
                          displaySeason: season.seasonLabel,
                          activeSeasonLabel: season.seasonLabel,
                        )) {
                          return false;
                        }
                        if (!m.manual &&
                            !MatchCalendarFilter.isListedCompetition(
                              m.competition,
                            )) {
                          return false;
                        }
                        if (MatchCalendarFilter.isStaleUpcoming(m)) {
                          return false;
                        }
                        return true;
                      }).toList()
                    : <MatchModel>[];
                if (widget.mode == MatchesViewMode.results) {
                  source = source
                      .where((m) => m.status == MatchStatus.finished)
                      .toList();
                } else {
                  final now = DateTime.now();
                  source = source
                      .where(
                        (m) =>
                            m.status == MatchStatus.live ||
                            (m.status == MatchStatus.upcoming &&
                                !m.date.isBefore(now)),
                      )
                      .toList();
                }
                final competitions = source
                    .map((match) => match.competition)
                    .toSet()
                    .toList()
                  ..sort();
                final teams = source
                    .expand((match) => [match.team1, match.team2])
                    .toSet()
                    .toList()
                  ..sort();
                final filtered = source.where((match) {
                  if (_selectedCompetition != null &&
                      match.competition != _selectedCompetition) {
                    return false;
                  }
                  if (_selectedTeam != null &&
                      !matchIncludesPreferredTeam(match, _selectedTeam)) {
                    return false;
                  }
                  return true;
                }).toList();

                final scoped = filtered
                    .where(
                      (match) =>
                          match.date.year == widget.focusMonth.year &&
                          match.date.month == widget.focusMonth.month,
                    )
                    .toList();

                final grouped = groupMatchesByDay(
                  scoped,
                  descending: widget.mode == MatchesViewMode.results,
                );

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    MainShellInsets.tabScrollTail(context, extra: 8),
                  ),
                  children: [
                    _MatchesFilterBar(
                      competitions: competitions,
                      teams: teams,
                      selectedCompetition: _selectedCompetition,
                      selectedTeam: _selectedTeam,
                      favoriteTeam: _favoriteTeam,
                      onSelectCompetition: (value) =>
                          setState(() => _selectedCompetition = value),
                      onSelectTeam: (value) =>
                          setState(() => _selectedTeam = value),
                    ),
                    if (scoped.isEmpty)
                      _EmptyMatchesState(
                        mode: widget.mode,
                        focusMonth: widget.focusMonth,
                        hadAnyBeforeMonth: filtered.isNotEmpty,
                        titleOverride:
                            noMockBetween ? life.upcomingWaitTitle : null,
                        subtitleOverride:
                            noMockBetween ? life.upcomingWaitSubtitle : null,
                      )
                    else
                      ...grouped.entries.expand((entry) {
                        return [
                          CalendarDateHeader(date: entry.key),
                          ...entry.value.map((match) {
                            final isFeatured = isSedanTeam(match.team1) ||
                                isSedanTeam(match.team2) ||
                                (_favoriteTeam != null &&
                                    matchIncludesPreferredTeam(
                                      match,
                                      _favoriteTeam,
                                    ));
                            return isFeatured
                                ? _MatchesEventCard(
                                    match: match,
                                    mode: widget.mode,
                                    isAdmin: _isAdmin,
                                  )
                                : CalendarFixtureTile(
                                    match: match,
                                    compact: true,
                                    showShare: false,
                                    showFavorite: false,
                                  );
                          }),
                        ];
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MatchesFilterBar extends StatelessWidget {
  final List<String> competitions;
  final List<String> teams;
  final String? selectedCompetition;
  final String? selectedTeam;
  final String? favoriteTeam;
  final ValueChanged<String?> onSelectCompetition;
  final ValueChanged<String?> onSelectTeam;

  const _MatchesFilterBar({
    required this.competitions,
    required this.teams,
    required this.selectedCompetition,
    required this.selectedTeam,
    required this.onSelectCompetition,
    required this.onSelectTeam,
    this.favoriteTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isFavActive = favoriteTeam != null &&
        teamMatchesPreference(selectedTeam ?? '', favoriteTeam);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (favoriteTeam != null)
          CalendarTeamScopeBar(
            favoriteOnly: isFavActive,
            showClubMark: true,
            clubMark: isSedanTeam(favoriteTeam!) ? 'CS' : teamInitials(favoriteTeam!),
            onChanged: (mine) =>
                onSelectTeam(mine ? favoriteTeam : null),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: CalendarTheme.gutter,
            ),
            children: [
              CalendarFilterChip(
                label: selectedCompetition ?? 'Tout',
                selected: selectedCompetition != null,
                onTap: () => _showPicker(
                  context: context,
                  title: 'Compétition',
                  options: competitions,
                  selected: selectedCompetition,
                  onSelected: onSelectCompetition,
                ),
              ),
              if (!isFavActive) ...[
                const SizedBox(width: 4),
                CalendarFilterChip(
                  label: selectedTeam ?? 'Équipe',
                  selected: selectedTeam != null,
                  onTap: () => _showPicker(
                    context: context,
                    title: 'Équipe',
                    options: teams,
                    selected: selectedTeam,
                    onSelected: onSelectTeam,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: CalendarTheme.scaffold,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CalendarTheme.gutter,
                    0,
                    8,
                    10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 3,
                        color: CalendarTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: CalendarType.kicker.copyWith(
                            color: CalendarTheme.text,
                          ),
                        ),
                      ),
                      if (selected != null)
                        TextButton(
                          onPressed: () {
                            onSelected(null);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Réinitialiser',
                            style: CalendarType.meta.copyWith(
                              color: CalendarTheme.accent,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: CalendarTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const CalendarRule(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final option = options[i];
                      final isSelected = selected == option;
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(context);
                        },
                        child: Ink(
                          decoration: CalendarTheme.fixtureTape(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CalendarTheme.gutter,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CalendarType.fixture.copyWith(
                                      color: isSelected
                                          ? CalendarTheme.accent
                                          : CalendarTheme.text,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: CalendarTheme.accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchesEventCard extends StatelessWidget {
  final MatchModel match;
  final MatchesViewMode mode;
  final bool isAdmin;

  const _MatchesEventCard({
    required this.match,
    required this.mode,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = mode == MatchesViewMode.upcoming;
    final isSedanMatch =
        isSedanTeam(match.team1) || isSedanTeam(match.team2);
    final isFinished = !isUpcoming;

    Widget? footer;
    if (isUpcoming && PronoChampionshipRollout.isHubVisible) {
      footer = _UpcomingMatchPronoCta(
        label: _pronoStatusLabel(match.date),
        match: match,
      );
    } else if (isFinished && isSedanMatch) {
      if (match.replayVideoId != null) {
        footer = _FixtureLink(
          label: 'Replay',
          onTap: () => _openReplay(context, match),
        );
      } else if (isAdmin) {
        footer = _FixtureLink(
          label: '+ Ajouter replay',
          muted: true,
          onTap: () => _editReplay(context, match),
        );
      } else {
        footer = _FixtureLink(
          label: 'Stats & détail',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
          ),
        );
      }
    }

    return CalendarFixtureTile(
      match: match,
      featured: true,
      footer: footer,
      onTap: isUpcoming || isSedanMatch
          ? CalendarFixtureTile.openDetail(context, match)
          : null,
    );
  }

  void _openReplay(BuildContext context, MatchModel match) {
    final youtubeId = match.replayVideoId;
    if (youtubeId == null || youtubeId.isEmpty) return;
    final video = VideoModel(
      id: match.id,
      title: '${match.team1} - ${match.team2}',
      youtubeId: youtubeId,
      duration: '',
      date: match.date,
      category: 'resume',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoWebScreen(video: video)),
    );
  }

  void _editReplay(BuildContext context, MatchModel match) {
    final controller = TextEditingController(text: match.replayVideoId ?? '');
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CalendarTheme.surface,
          title: Text('Lien replay', style: CalendarType.title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'URL ou ID YouTube'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: CalendarType.meta),
            ),
            TextButton(
              onPressed: () async {
                final raw = controller.text.trim();
                final id = YoutubeParser.extractId(raw);
                if (id == null) {
                  Navigator.pop(context);
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(match.id)
                    .update({'replayVideoId': id});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Replay enregistré')),
                  );
                }
              },
              child: Text(
                'Enregistrer',
                style: CalendarType.label.copyWith(color: CalendarTheme.accent),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FixtureLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;

  const _FixtureLink({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          label.toUpperCase(),
          style: CalendarType.kicker.copyWith(
            color: muted ? CalendarTheme.textSoft : CalendarTheme.accent,
          ),
        ),
      ),
    );
  }
}

class _UpcomingMatchPronoCta extends StatelessWidget {
  final String label;
  final MatchModel match;

  const _UpcomingMatchPronoCta({required this.label, required this.match});

  @override
  Widget build(BuildContext context) {
    final canTap = _isPronoOpen(match.date);
    return GestureDetector(
      onTap: () {
        if (canTap) {
          openPronoForMatch(context, matchId: match.id, openSheet: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Les pronos s’ouvrent 7 jours avant le coup d’envoi.',
              ),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          (canTap ? label : 'Ouverture 7 j avant le match').toUpperCase(),
          style: CalendarType.kicker.copyWith(
            color: canTap ? CalendarTheme.goldDeep : CalendarTheme.textSoft,
          ),
        ),
      ),
    );
  }
}

class _EmptyMatchesState extends StatelessWidget {
  final MatchesViewMode mode;
  final DateTime focusMonth;
  final bool hadAnyBeforeMonth;
  final String? titleOverride;
  final String? subtitleOverride;

  const _EmptyMatchesState({
    required this.mode,
    required this.focusMonth,
    required this.hadAnyBeforeMonth,
    this.titleOverride,
    this.subtitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('MMMM yyyy', 'fr_FR').format(focusMonth);

    final title = titleOverride ??
        (hadAnyBeforeMonth
            ? 'Aucun match en $monthTitle'
            : (mode == MatchesViewMode.upcoming
                ? 'Aucun rendez-vous ici'
                : 'Aucun résultat pour ce filtre'));

    final subtitle = subtitleOverride ??
        (hadAnyBeforeMonth
            ? 'Change de mois avec les flèches sous les onglets, ou assouplis compétition / équipe.'
            : 'Essaie une autre compétition ou une autre équipe pour relancer la liste.');

    return CalendarEmptyState(
      icon: mode == MatchesViewMode.upcoming
          ? Icons.event_busy_rounded
          : Icons.sports_score_rounded,
      title: title,
      body: subtitle,
    );
  }
}
