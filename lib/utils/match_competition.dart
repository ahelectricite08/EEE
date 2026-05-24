/// Types de compétition — aligné sur l’admin (`match_editor.dart`).
abstract final class MatchCompetition {
  static const regularSeason = [
    'National 3',
    'Régional 1',
    'Régional 2',
    'Régional 3',
  ];

  static const other = [
    'Coupe de France',
    'Coupe Grand Est',
    'Coupe des Ardennes',
    'Coupe de la Ligue',
    'Barrage',
    'Match Amical',
  ];

  static const all = [...regularSeason, ...other];

  /// Classement / forme affichés uniquement pour le championnat (saison régulière).
  static bool isRegularSeason(String? competition) {
    final c = (competition ?? '').trim().toLowerCase();
    if (c.isEmpty) return true;
    return regularSeason.any((r) => r.toLowerCase() == c);
  }
}
