import 'package:flutter/material.dart';

import '../matches/matches_helpers.dart' show isSedanTeam, teamInitials;
import 'calendar_helpers.dart';
import 'theme/calendar_theme.dart';
import 'theme/calendar_type.dart';
import 'widgets/calendar_ui.dart';

class MonthBar extends StatelessWidget {
  final DateTime focus;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const MonthBar({
    super.key,
    required this.focus,
    required this.onPrev,
    required this.onNext,
  });

  static const _months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        8,
        CalendarTheme.gutter,
        4,
      ),
      child: Row(
        children: [
          CalendarPaperNav(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _months[focus.month - 1],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: CalendarType.display.copyWith(fontSize: 34),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  focus.year.toString(),
                  style: CalendarType.kickerGoldPaper,
                ),
                const SizedBox(height: 8),
                CalendarTheme.goldRule(width: 36, height: 3),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CalendarPaperNav(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class CalendarModeBar extends StatelessWidget {
  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;

  const CalendarModeBar({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CalendarFilterChip(
            label: 'À venir',
            selected: mode == CalendarViewMode.upcoming,
            onTap: () => onChanged(CalendarViewMode.upcoming),
          ),
        ),
        Expanded(
          child: CalendarFilterChip(
            label: 'Résultats',
            selected: mode == CalendarViewMode.results,
            onTap: () => onChanged(CalendarViewMode.results),
          ),
        ),
      ],
    );
  }
}

class CompetitionBar extends StatelessWidget {
  final List<String> competitions;
  final String selected;
  final ValueChanged<String> onSelected;
  final String Function(String key)? chipLabel;

  const CompetitionBar({
    super.key,
    required this.competitions,
    required this.selected,
    required this.onSelected,
    this.chipLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: CalendarTheme.gutter),
        scrollDirection: Axis.horizontal,
        itemCount: competitions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final competition = competitions[index];
          return CalendarFilterChip(
            label: chipLabel?.call(competition) ??
                (competition == 'TOUT' ? 'Tout' : competition),
            selected: competition == selected,
            onTap: () => onSelected(competition),
          );
        },
      ),
    );
  }
}

class FavoriteTeamBar extends StatelessWidget {
  final String favoriteTeam;
  final bool favoriteOnly;
  final ValueChanged<bool> onChanged;

  const FavoriteTeamBar({
    super.key,
    required this.favoriteTeam,
    required this.favoriteOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final club = isSedanTeam(favoriteTeam);
    return CalendarTeamScopeBar(
      favoriteOnly: favoriteOnly,
      onChanged: onChanged,
      showClubMark: true,
      clubMark: club ? 'CS' : teamInitials(favoriteTeam),
    );
  }
}

class DaySelectorBar extends StatelessWidget {
  final List<DateTime> days;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelected;

  const DaySelectorBar({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          CalendarTheme.gutter,
          8,
          CalendarTheme.gutter,
          0,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = selectedDay != null && isSameDay(selectedDay!, day);
          return GestureDetector(
            onTap: () => onSelected(day),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: CalendarTheme.animFast,
              curve: CalendarTheme.animCurve,
              width: 52,
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? CalendarTheme.ink : CalendarTheme.hairline,
                    width: active ? 3 : 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    weekdayShort(day).toUpperCase(),
                    style: CalendarType.kicker.copyWith(
                      color: active
                          ? CalendarTheme.text
                          : CalendarTheme.textSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: CalendarType.numeralGutter.copyWith(
                      fontSize: 26,
                      color: active
                          ? CalendarTheme.accent
                          : CalendarTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
