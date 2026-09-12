import 'match_lineup.dart';
import 'match_stats_schema.dart';

/// Source des noms pour la saisie live (but / carton / remplacement).
///
/// Si une compo existe pour le côté choisi, on n’utilise **pas** l’effectif
/// complet Sedan — même pour un but de l’adversaire.
class LiveEventPlayerSource {
  final List<String> starters;
  final List<String> substitutes;

  /// Compo officielle / probable déjà saisie pour ce côté.
  final bool fromLineup;

  /// Sedan sans XI : repli sur l’effectif club.
  final bool useSedanSquadFallback;

  /// Adversaire sans XI : saisie libre, pas l’effectif DVCR.
  final bool opponentWithoutLineup;

  const LiveEventPlayerSource({
    this.starters = const [],
    this.substitutes = const [],
    this.fromLineup = false,
    this.useSedanSquadFallback = false,
    this.opponentWithoutLineup = false,
  });

  /// Adversaire sans XI : champ texte, pas un produit « But adverse ».
  static const quietOpponentHint = 'Pas de compo — saisie libre';

  List<String> get names {
    final seen = <String>{};
    final out = <String>[];
    for (final n in [...starters, ...substitutes]) {
      final t = n.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
    }
    return out;
  }

  bool get hasLineupPlayers => fromLineup && names.isNotEmpty;

  static LiveEventPlayerSource fromLive({
    required Map<String, dynamic> live,
    required String selectedTeam,
  }) {
    final team1 = (live['team1'] ?? 'DOM').toString();
    final lineups = MatchLineups.fromDoc(live);
    final isHome = selectedTeam == team1;
    final side = isHome ? lineups.home : lineups.away;
    final starters = _playersOnPitch(side.starters, side.coach);
    final subs = _playersOnPitch(side.substitutes, side.coach);
    if (starters.isNotEmpty || subs.isNotEmpty) {
      return LiveEventPlayerSource(
        starters: starters,
        substitutes: subs,
        fromLineup: true,
      );
    }
    if (MatchStatsSchema.isSedanTeamLabel(selectedTeam)) {
      return const LiveEventPlayerSource(useSedanSquadFallback: true);
    }
    return const LiveEventPlayerSource(opponentWithoutLineup: true);
  }

  static List<String> _playersOnPitch(List<String> raw, String coach) {
    final seen = <String>{};
    final out = <String>[];
    for (final r in raw) {
      final n = r.trim();
      if (n.isEmpty || !seen.add(n)) continue;
      if (MatchLineupSide.isStaffOrCoachLabel(n, coachName: coach)) continue;
      out.add(n);
    }
    return out;
  }
}
