import 'package:flutter/material.dart';

import '../../models/match_model.dart';
import '../../navigation/main_shell_insets.dart';
import '../matches/matches_helpers.dart'
    show groupMatchesByDay, isSedanMatch;
import 'calendar_helpers.dart';
import 'widgets/calendar_date_header.dart';
import 'widgets/calendar_fixture_tile.dart';
import 'widgets/calendar_ui.dart';

class MatchSectionsList extends StatelessWidget {
  final List<MatchModel> matches;
  final CalendarViewMode mode;
  final DateTime? selectedDay;
  final bool loading;
  final bool hasError;

  const MatchSectionsList({
    super.key,
    required this.matches,
    required this.mode,
    required this.selectedDay,
    this.loading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MainShellInsets.tabScrollTail(context, extra: 20);

    if (loading) {
      return ListView(
        padding: EdgeInsets.only(top: 8, bottom: bottom),
        children: const [CalendarLoadingTape(rows: 6)],
      );
    }

    if (hasError) {
      return ListView(
        padding: EdgeInsets.only(bottom: bottom),
        children: const [
          CalendarErrorState(
            title: 'Calendrier indisponible',
            body:
                'Impossible de charger les matchs. Réessaie dans un instant.',
          ),
        ],
      );
    }

    if (matches.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: bottom),
        children: [
          CalendarEmptyState(
            icon: mode == CalendarViewMode.upcoming
                ? Icons.event_busy_rounded
                : Icons.sports_score_rounded,
            title: selectedDay != null
                ? 'Aucun match ce jour'
                : mode == CalendarViewMode.upcoming
                    ? 'Aucune rencontre à venir'
                    : 'Aucun résultat sur cette période',
            body:
                'Change de mois, filtre par compétition ou touche un jour pour affiner la liste.',
          ),
        ],
      );
    }

    final grouped = groupMatchesByDay(matches, descending: false);
    final days = grouped.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottom),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final sectionMatches = grouped[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarDateHeader(date: day),
            ...sectionMatches.map((match) {
              final sedan = isSedanMatch(match);
              return CalendarFixtureTile(
                match: match,
                featured: sedan,
                compact: !sedan,
                onTap: CalendarFixtureTile.openDetail(context, match),
              );
            }),
          ],
        );
      },
    );
  }
}
