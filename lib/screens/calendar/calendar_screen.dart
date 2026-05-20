import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../services/user_preferences_service.dart';
import 'calendar_controls.dart';
import 'calendar_header.dart';
import 'calendar_helpers.dart';
import 'calendar_match_list.dart';
import 'calendar_palette.dart';
import '../matches/matches_helpers.dart' hide isSameDay;

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

  @override
  void initState() {
    super.initState();
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    _favoriteOnly = _favoriteTeam != null && _favoriteTeam!.isNotEmpty;
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
      final shouldEnableFavorite =
          !_favoriteOnly &&
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

  /// Mois entièrement passé → résultats ; entièrement futur → à venir (sinon on garde le choix).
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
      backgroundColor: kSedanOuterFrame,
      body: SafeArea(
        child: Column(
          children: [
            SedanResultsHeader(
              focus: _focus,
              mode: _mode,
              favoriteTeam: _favoriteTeam,
              rankingSeason: '2025-2026',
              onModeChanged: (mode) => setState(() {
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
            Expanded(
              child: StreamBuilder<List<MatchModel>>(
                stream: MatchService.forMonth(_focus.year, _focus.month),
                builder: (context, snap) {
                  final source = snap.hasData && snap.data!.isNotEmpty
                      ? snap.data!
                      : _mockForMonth(_focus);
                  final monthMatches = [...source]
                    ..sort((a, b) => a.date.compareTo(b.date));

                  final personalizedPool =
                      monthMatches.where((match) {
                        if (_favoriteOnly &&
                            !matchIncludesPreferredTeam(match, _favoriteTeam)) {
                          return false;
                        }
                        return true;
                      }).toList()..sort((a, b) {
                        final aFav = matchIncludesPreferredTeam(a, _favoriteTeam);
                        final bFav = matchIncludesPreferredTeam(b, _favoriteTeam);
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
                            match.competition.toUpperCase() == _competition,
                      )
                      .toList();

                  final availableCompetitions = <String>{
                    'TOUT',
                    ...personalizedPool
                        .where((match) => matchesCalendarMode(match, _mode))
                        .map((match) => match.competition.toUpperCase()),
                  }.toList();

                  if (!availableCompetitions.contains(_competition)) {
                    _competition = 'TOUT';
                  }

                  final dayOptions =
                      personalizedPool
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
                            .where(
                              (match) => isSameDay(match.date, _selectedDay!),
                            )
                            .toList();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kSedanSheetBright,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: kSedanGold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(55),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    kSedanGold.withAlpha(35),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'AGENDA DU MOIS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: kSedanGreenDeep,
                                  ),
                                ),
                              ),
                            ),
                            MonthBar(
                              focus: _focus,
                              onPrev: () => setState(() {
                                _focus = DateTime(
                                  _focus.year,
                                  _focus.month - 1,
                                );
                                _selectedDay = null;
                                _syncModeToFocusMonth();
                              }),
                              onNext: () => setState(() {
                                _focus = DateTime(
                                  _focus.year,
                                  _focus.month + 1,
                                );
                                _selectedDay = null;
                                _syncModeToFocusMonth();
                              }),
                            ),
                          CompetitionBar(
                            competitions: availableCompetitions,
                            selected: _competition,
                            onSelected: (value) => setState(() {
                              _competition = value;
                              _selectedDay = null;
                            }),
                          ),
                          if (_favoriteTeam != null &&
                              _favoriteTeam!.isNotEmpty)
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
                                _selectedDay =
                                    _selectedDay != null &&
                                        isSameDay(_selectedDay!, day)
                                    ? null
                                    : day;
                              }),
                            ),
                            Expanded(
                              child: Container(
                                color: kSedanSheetBright,
                                child: MatchSectionsList(
                                  matches: filteredByDay,
                                  mode: _mode,
                                  selectedDay: _selectedDay,
                                ),
                              ),
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
  }

  List<MatchModel> _mockForMonth(DateTime focus) {
    final all = [...MatchModel.mockUpcoming, ...MatchModel.mockResults];
    return all
        .where(
          (match) =>
              match.date.month == focus.month && match.date.year == focus.year,
        )
        .toList();
  }
}
