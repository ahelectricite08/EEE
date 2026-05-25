import '../models/match_model.dart';
import 'match_controller.dart';

/// Match proposé au démarrage d’un direct (admin / pilotage rapide).
class LiveStartSuggestion {
  final MatchModel? match;
  final String? message;

  const LiveStartSuggestion({this.match, this.message});
}

/// Suggestion du prochain match Sedan/CSSA pour lancer un live.
abstract final class LiveStartService {
  static const Duration _matchDurationFallback = Duration(hours: 2);
  static const Duration _nextMatchDelayAfterEnd = Duration(hours: 3);

  static bool isSedanMatch(MatchModel match) {
    final team1 = match.team1.toUpperCase();
    final team2 = match.team2.toUpperCase();
    return team1.contains('SEDAN') ||
        team1.contains('CSSA') ||
        team2.contains('SEDAN') ||
        team2.contains('CSSA');
  }

  static LiveStartSuggestion pickSuggestedMatch() {
    final ctrl = MatchController.instance;
    final upcoming = ctrl.upcoming.where(isSedanMatch).toList();
    final results = ctrl.results.where(isSedanMatch).toList();
    final now = DateTime.now();
    final recent = results.isNotEmpty ? results.first : null;

    if (recent != null) {
      final switchAt = recent.date
          .add(_matchDurationFallback)
          .add(_nextMatchDelayAfterEnd);
      if (now.isBefore(switchAt)) {
        final remaining = switchAt.difference(now);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final timerLabel = hours > 0
            ? '${hours}h${minutes.toString().padLeft(2, '0')}'
            : '$minutes min';
        return LiveStartSuggestion(
          match: recent,
          message:
              'Tu restes sur le dernier match pour les stats live. '
              'Le prochain match sera proposé automatiquement dans $timerLabel.',
        );
      }
    }

    final next = upcoming.isNotEmpty ? upcoming.first : null;
    return LiveStartSuggestion(
      match: next,
      message: next != null
          ? 'Délai post-match passé — prochain match du calendrier proposé.'
          : null,
    );
  }
}
