import 'package:flutter/material.dart';

import '../../widgets/cssa_favorite_ranking_share_button.dart';
import '../matches/matches_helpers.dart';
import 'calendar_helpers.dart';
import 'theme/calendar_theme.dart';
import 'widgets/calendar_hero_sliver.dart';

/// Masthead photo + action de partage classement — pas d’aplat vert.
class CalendarMasthead {
  static Widget sliver(
    BuildContext context, {
    required DateTime focus,
    required CalendarViewMode mode,
    String? favoriteTeam,
    String rankingSeason = '2025-2026',
  }) {
    final seasonLabel = focus.month >= 7
        ? '${focus.year}/${(focus.year + 1).toString().substring(2)}'
        : '${focus.year - 1}/${focus.year.toString().substring(2)}';
    final isUpcoming = mode == CalendarViewMode.upcoming;

    return CalendarHeroSliver.build(
      context,
      title: isUpcoming ? 'À venir' : 'Résultats',
      subtitle: isUpcoming
          ? 'Saison $seasonLabel · les affiches du mois'
          : 'Saison $seasonLabel · les scores du mois',
      toolbarAction: CssaFavoriteRankingShareButton(
        season: rankingSeason,
        favoriteTeam: favoriteTeam,
        leagueLabel: rankingLeagueLabel(rankingSeason),
        style: CssaRankingShareStyle.calendarGreen,
      ),
    );
  }
}

/// Filet bas du bandeau papier (onglets / mois) — ivoire, pas d’encre.
class CalendarPaperStrip extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final double height;

  const CalendarPaperStrip({
    super.key,
    required this.child,
    required this.height,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarTheme.scaffold,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CalendarTheme.hairline),
          ),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
