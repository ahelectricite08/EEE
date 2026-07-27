import '../models/fff_season_config.dart';
import '../models/match_model.dart';
import 'match_competition.dart';

/// Filtre calendrier app : matchs Sedan, compétitions connues, saison active.
abstract final class MatchCalendarFilter {
  static bool involvesSedan(MatchModel match) {
    return _isSedan(match.team1) || _isSedan(match.team2);
  }

  static bool _isSedan(String team) {
    final upper = team.toUpperCase();
    return upper.contains('SEDAN') || upper.contains('CSSA');
  }

  static bool isListedCompetition(String? competition) {
    final label = MatchCompetition.displayLabel(competition);
    return MatchCompetition.all.any(
      (c) => c.toLowerCase() == label.toLowerCase(),
    );
  }

  static bool belongsToSeason(
    MatchModel match, {
    required String displaySeason,
    String? activeSeasonLabel,
  }) {
    return FffSeasonConfig.matchDocBelongsToSeason(
      {'fffSeason': match.fffSeason},
      displaySeason,
      activeSeasonLabel: activeSeasonLabel,
    );
  }

  /// Exclut les fiches restées `upcoming` alors que la date est passée (sync / manuel).
  static bool isStaleUpcoming(MatchModel match) {
    if (match.manual) return false;
    if (match.status != MatchStatus.upcoming) return false;
    final now = DateTime.now();
    final kickoff = match.date;
    if (kickoff.isBefore(now.subtract(const Duration(hours: 6)))) {
      return true;
    }
    return false;
  }

  static bool _manualCompetitionOk(MatchModel match) {
    final raw = (match.competition).trim();
    if (raw.isEmpty) return true;
    return isListedCompetition(match.competition) ||
        MatchCompetition.isFriendly(match.competition) ||
        MatchCompetition.isCup(match.competition) ||
        MatchCompetition.isRegularSeason(match.competition);
  }

  static bool visibleInAppCalendar(
    MatchModel match, {
    required String displaySeason,
    String? activeSeasonLabel,
    bool requireSeasonBelonging = true,
  }) {
    if (!involvesSedan(match)) return false;
    if (match.manual) {
      if (!_manualCompetitionOk(match)) return false;
    } else if (!isListedCompetition(match.competition)) {
      return false;
    }
    if (requireSeasonBelonging &&
        !belongsToSeason(
          match,
          displaySeason: displaySeason,
          activeSeasonLabel: activeSeasonLabel,
        )) {
      return false;
    }
    if (isStaleUpcoming(match)) return false;
    return true;
  }

  static List<MatchModel> apply(
    Iterable<MatchModel> matches, {
    required String displaySeason,
    String? activeSeasonLabel,
    bool requireSeasonBelonging = true,
  }) {
    return matches
        .where(
          (m) => visibleInAppCalendar(
            m,
            displaySeason: displaySeason,
            activeSeasonLabel: activeSeasonLabel,
            requireSeasonBelonging: requireSeasonBelonging,
          ),
        )
        .toList();
  }

  /// Derniers résultats Sedan joués (toutes saisons), pour l’accueil / cache résultats.
  /// Ne restreint pas à la saison active — sinon section vide + mocks en début de saison.
  static List<MatchModel> applyFinishedAcrossSeasons(
    Iterable<MatchModel> matches,
  ) {
    return matches
        .where(
          (m) =>
              m.status == MatchStatus.finished &&
              visibleInAppCalendar(
                m,
                displaySeason: '',
                requireSeasonBelonging: false,
              ),
        )
        .toList();
  }
}
