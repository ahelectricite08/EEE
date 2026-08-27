import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/fff_season_config.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../services/user_preferences_service.dart';
import '../../utils/match_calendar_filter.dart';
import '../matches/matches_helpers.dart' hide isSameDay;
import 'calendar_controls.dart';
import 'calendar_header.dart';
import 'calendar_helpers.dart';
import 'calendar_match_list.dart';
import 'theme/calendar_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focus = DateTime.now();
  DateTime? _selectedDay;
  CalendarViewMode _mode = CalendarViewMode.upcoming;
  String _competition = 'TOUT';
  String? _favoriteTeam;
  bool _favoriteOnly = false;
  Stream<List<MatchModel>>? _monthStream;
  int? _streamYear;
  int? _streamMonth;

  @override
  void initState() {
    super.initState();
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    _favoriteOnly = _favoriteTeam != null && _favoriteTeam!.isNotEmpty;
    UserPreferencesService.instance.addListener(_handleFavoriteTeamChanged);
    unawaited(UserPreferencesService.instance.init());
    _syncMonthStream();
  }

  void _syncMonthStream() {
    final year = _focus.year;
    final month = _focus.month;
    if (_monthStream != null && _streamYear == year && _streamMonth == month) {
      return;
    }
    _streamYear = year;
    _streamMonth = month;
    _monthStream = MatchService.forMonth(year, month);
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
      final shouldEnableFavorite = !_favoriteOnly &&
          (_favoriteTeam == null || _favoriteTeam!.isEmpty) &&
          next != null &&
          next.isNotEmpty;
      _favoriteTeam = next;
      if (shouldEnableFavorite) {
        _favoriteOnly = true;
      }
      _selectedDay = null;
    });
  }

  void _syncModeToFocusMonth() {
    if (isCalendarMonthFullyPast(_focus)) {
      _mode = CalendarViewMode.results;
    } else if (isCalendarMonthFullyFuture(_focus)) {
      _mode = CalendarViewMode.upcoming;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalendarTheme.scaffold,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          CalendarMasthead.sliver(
            context,
            focus: _focus,
            mode: _mode,
            favoriteTeam: _favoriteTeam,
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CalendarPinnedDelegate(
              height: 148,
              child: Material(
                color: CalendarTheme.scaffold,
                child: Column(
                  children: [
                    CalendarModeBar(
                      mode: _mode,
                      onChanged: (mode) => setState(() {
                        _mode = mode;
                        if (isCalendarMonthFullyPast(_focus) &&
                            _mode == CalendarViewMode.upcoming) {
                          _mode = CalendarViewMode.results;
                        } else if (isCalendarMonthFullyFuture(_focus) &&
                            _mode == CalendarViewMode.results) {
                          _mode = CalendarViewMode.upcoming;
                        }
                        _selectedDay = null;
                      }),
                    ),
                    MonthBar(
                      focus: _focus,
                      onPrev: () => setState(() {
                        _focus = DateTime(_focus.year, _focus.month - 1);
                        _selectedDay = null;
                        _syncModeToFocusMonth();
                        _syncMonthStream();
                      }),
                      onNext: () => setState(() {
                        _focus = DateTime(_focus.year, _focus.month + 1);
                        _selectedDay = null;
                        _syncModeToFocusMonth();
                        _syncMonthStream();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Builder(
          builder: (context) {
            final displaySeason =
                FffSeasonConfig.frenchFootballSeasonLabel(_focus);
            final cached =
                MatchService.lastKnownForMonth(_focus.year, _focus.month);
            return StreamBuilder<List<MatchModel>>(
              stream: _monthStream,
              initialData: cached,
              builder: (context, snap) {
                final loading = snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData &&
                    cached == null;
                final raw = snap.data ?? cached ?? <MatchModel>[];
                final source = MatchCalendarFilter.apply(
                  raw,
                  displaySeason: displaySeason,
                  activeSeasonLabel: displaySeason,
                );
                final monthMatches = [...source]
                  ..sort((a, b) => a.date.compareTo(b.date));

                final personalizedPool = monthMatches.where((match) {
                  if (_favoriteOnly &&
                      !matchIncludesPreferredTeam(match, _favoriteTeam)) {
                    return false;
                  }
                  return true;
                }).toList()
                  ..sort((a, b) {
                    final aFav =
                        matchIncludesPreferredTeam(a, _favoriteTeam);
                    final bFav =
                        matchIncludesPreferredTeam(b, _favoriteTeam);
                    if (aFav != bFav) {
                      return aFav ? -1 : 1;
                    }
                    return a.date.compareTo(b.date);
                  });

                final visibleMatches = personalizedPool
                    .where((match) => matchesCalendarMode(match, _mode))
                    .where(
                      (match) =>
                          _competition == 'TOUT' ||
                          calendarCompetitionKey(match) == _competition,
                    )
                    .toList();

                final availableCompetitions = calendarCompetitionChips(
                  personalizedPool
                      .where((match) => matchesCalendarMode(match, _mode))
                      .map(calendarCompetitionKey),
                );

                if (!availableCompetitions.contains(_competition)) {
                  _competition = 'TOUT';
                }

                final dayOptions = personalizedPool
                    .where((match) => matchesCalendarMode(match, _mode))
                    .map(
                      (match) => DateTime(
                        match.date.year,
                        match.date.month,
                        match.date.day,
                      ),
                    )
                    .toSet()
                    .toList()
                  ..sort();

                final filteredByDay = _selectedDay == null
                    ? visibleMatches
                    : visibleMatches
                        .where((match) => isSameDay(match.date, _selectedDay!))
                        .toList();

                return ColoredBox(
                  color: CalendarTheme.scaffold,
                  child: Column(
                    children: [
                      CompetitionBar(
                        competitions: availableCompetitions,
                        selected: _competition,
                        chipLabel: calendarCompetitionChipLabel,
                        onSelected: (value) => setState(() {
                          _competition = value;
                          _selectedDay = null;
                        }),
                      ),
                      if (_favoriteTeam != null && _favoriteTeam!.isNotEmpty)
                        FavoriteTeamBar(
                          favoriteTeam: _favoriteTeam!,
                          favoriteOnly: _favoriteOnly,
                          onChanged: (favoriteOnly) => setState(() {
                            _favoriteOnly = favoriteOnly;
                            _selectedDay = null;
                          }),
                        ),
                      if (dayOptions.isNotEmpty)
                        DaySelectorBar(
                          days: dayOptions,
                          selectedDay: _selectedDay,
                          onSelected: (day) => setState(() {
                            _selectedDay = _selectedDay != null &&
                                    isSameDay(_selectedDay!, day)
                                ? null
                                : day;
                          }),
                        ),
                      Expanded(
                        child: MatchSectionsList(
                          matches: filteredByDay,
                          mode: _mode,
                          selectedDay: _selectedDay,
                          loading: loading,
                          hasError: snap.hasError &&
                              cached == null &&
                              !snap.hasData,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CalendarPinnedDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _CalendarPinnedDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _CalendarPinnedDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
