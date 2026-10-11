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
import '../../models/season_lifecycle_config.dart';
import '../../services/season_lifecycle_service.dart';
import '../../utils/youtube_parser.dart';
import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';
import '../calendar/widgets/calendar_date_header.dart';
import '../calendar/widgets/calendar_fixture_tile.dart';
import '../calendar/widgets/calendar_prono_line.dart';
import '../calendar/widgets/calendar_ui.dart';
import '../match_detail_screen.dart';
import '../video_web_screen.dart';
import 'matches_division_bar.dart';
import 'matches_helpers.dart';

class MatchesFeedTab extends StatefulWidget {
  final MatchesViewMode mode;
  final DateTime focusMonth;
  final MatchesFffDivision division;
  final ValueChanged<MatchesFffDivision> onDivisionChanged;

  const MatchesFeedTab({
    super.key,
    required this.mode,
    required this.focusMonth,
    this.division = MatchesFffDivision.r1,
    required this.onDivisionChanged,
  });

  @override
  State<MatchesFeedTab> createState() => _MatchesFeedTabState();
}

class _MatchesFeedTabState extends State<MatchesFeedTab> {
  String? _selectedCompetition;
  String? _selectedTeam;
  String? _favoriteTeam;
  bool _isAdmin = false;
  Stream<List<MatchModel>>? _monthStream;
  int? _streamYear;
  int? _streamMonth;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((value) {
      if (mounted) setState(() => _isAdmin = value);
    });
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    UserPreferencesService.instance.addListener(_handleFavoriteTeamChanged);
    unawaited(UserPreferencesService.instance.init());
    _syncMonthStream();
  }

  @override
  void didUpdateWidget(covariant MatchesFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusMonth.year != widget.focusMonth.year ||
        oldWidget.focusMonth.month != widget.focusMonth.month ||
        oldWidget.division != widget.division) {
      _syncMonthStream(force: oldWidget.division != widget.division);
    }
  }

  bool get _isR2 => widget.division == MatchesFffDivision.r2;

  void _syncMonthStream({bool force = false}) {
    final year = widget.focusMonth.year;
    final month = widget.focusMonth.month;
    if (!force &&
        _monthStream != null &&
        _streamYear == year &&
        _streamMonth == month) {
      return;
    }
    _streamYear = year;
    _streamMonth = month;
    _monthStream = _isR2
        ? MatchService.forMonthR2(year, month)
        : MatchService.forMonth(year, month);
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
    final year = widget.focusMonth.year;
    final month = widget.focusMonth.month;
    final displaySeason =
        FffSeasonConfig.frenchFootballSeasonLabel(widget.focusMonth);
    final cached = _isR2
        ? MatchService.lastKnownForMonthR2(year, month)
        : MatchService.lastKnownForMonth(year, month);

    return Column(
      children: [
        StreamBuilder<FffSeasonConfig>(
          stream: SeasonConfigService.stream(),
          builder: (context, fffSnap) {
            final cfg = fffSnap.data ?? FffSeasonConfig.defaults;
            return MatchesDivisionBar(
              division: widget.division,
              onChanged: widget.onDivisionChanged,
              r2Subtitle: cfg.r2CompetitionDisplayName,
            );
          },
        ),
        Expanded(
          child: StreamBuilder<FffSeasonConfig>(
            stream: SeasonConfigService.stream(),
            builder: (context, fffSnap) {
              final cfg = fffSnap.data ?? FffSeasonConfig.defaults;
              return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life = lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        final between = life.betweenSeasons;

        return StreamBuilder<List<MatchModel>>(
          stream: _monthStream,
          initialData: cached,
          builder: (context, snapshot) {
            final hasList = snapshot.hasData || cached != null;
            if (!hasList &&
                snapshot.connectionState == ConnectionState.waiting) {
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
            if (snapshot.hasError && !hasList) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  8,
                  0,
                  MainShellInsets.tabScrollTail(context, extra: 8),
                ),
                children: const [
                  CalendarErrorState(
                    title: 'Calendrier indisponible',
                    body:
                        'Impossible de charger les matchs. Réessaie dans un instant.',
                  ),
                ],
              );
            }
            final noMockBetween =
                between && widget.mode == MatchesViewMode.upcoming;
            final raw = snapshot.data ?? cached ?? <MatchModel>[];
            var source = raw.where((m) {
              if (!MatchCalendarFilter.belongsToSeason(
                m,
                displaySeason: displaySeason,
                activeSeasonLabel: displaySeason,
              )) {
                return false;
              }
              if (!_isR2 &&
                  !m.manual &&
                  !MatchCalendarFilter.isListedCompetition(
                    m.competition,
                  )) {
                return false;
              }
              return true;
            }).toList();
            if (widget.mode == MatchesViewMode.results) {
              source = source
                  .where(MatchCalendarFilter.belongsInResults)
                  .toList();
            } else {
              source = source
                  .where(MatchCalendarFilter.belongsInUpcoming)
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
                    if (_isR2 && !cfg.hasR2FffSource)
                      const _R2UnwiredMatchesCard()
                    else if (scoped.isEmpty)
                      _EmptyMatchesState(
                        mode: widget.mode,
                        focusMonth: widget.focusMonth,
                        hadAnyBeforeMonth: filtered.isNotEmpty,
                        titleOverride: _isR2
                            ? (widget.mode == MatchesViewMode.upcoming
                                ? 'Aucun rendez-vous réserve'
                                : 'Aucun résultat réserve')
                            : (noMockBetween ? life.upcomingWaitTitle : null),
                        subtitleOverride: _isR2
                            ? 'Régional 2 · équipe réserve. L’ID FFF est déjà branché (449972). Une liste vide vient en général d’une synchro FFF / WAF, pas d’un identifiant à recoller.'
                            : (noMockBetween
                                ? life.upcomingWaitSubtitle
                                : null),
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
                                    isR2: _isR2,
                                  )
                                : CalendarFixtureTile(
                                    match: match,
                                    compact: true,
                                    showShare: false,
                                    showFavorite: false,
                                    footer: _isR2
                                        ? null
                                        : CalendarPronoLine(match: match),
                                    onTap: CalendarFixtureTile.openDetail(
                                      context,
                                      match,
                                    ),
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
          ),
        ),
      ],
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
  final bool isR2;

  const _MatchesEventCard({
    required this.match,
    required this.mode,
    required this.isAdmin,
    this.isR2 = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = mode == MatchesViewMode.upcoming;
    final isSedanMatch =
        isSedanTeam(match.team1) || isSedanTeam(match.team2);

    final pronoLine = isR2 ? null : CalendarPronoLine(match: match);
    Widget? footer = pronoLine;
    if (!isUpcoming) {
      Widget? replay;
      if (!isR2 && isSedanMatch) {
        if (match.replayVideoId != null) {
          replay = _FixtureLink(
            label: 'Replay',
            onTap: () => _openReplay(context, match),
          );
        } else if (isAdmin) {
          replay = _FixtureLink(
            label: '+ Ajouter replay',
            muted: true,
            onTap: () => _editReplay(context, match),
          );
        } else {
          replay = _FixtureLink(
            label: 'Stats & détail',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchDetailScreen(match: match),
              ),
            ),
          );
        }
      }
      final kids = <Widget>[
        if (pronoLine != null) pronoLine,
        if (replay != null) replay,
      ];
      footer = kids.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: kids,
            );
    }

    return CalendarFixtureTile(
      match: match,
      featured: true,
      footer: footer,
      onTap: CalendarFixtureTile.openDetail(context, match),
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

class _R2UnwiredMatchesCard extends StatelessWidget {
  const _R2UnwiredMatchesCard();

  @override
  Widget build(BuildContext context) {
    return const CalendarEmptyState(
      icon: Icons.event_busy_rounded,
      title: 'Calendrier réserve en attente',
      body:
          'Régional 2 · équipe réserve.\n'
          'L’ID FFF 449972 est déjà le défaut. Une liste vide, c’est en général '
          'le WAF FFF (serveurs Google) ou une journée incomplète — pas un ID '
          'oublié. Ouvre l’accueil ou lance une synchro depuis un téléphone staff.',
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
