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

  /// Filtres stats admin (catégorie + niveau championnat optionnel).
  static const statsCategoryFilters = <({String id, String label})>[
    (id: 'all', label: 'Tous'),
    (id: 'championship', label: 'Championnat'),
    (id: 'cups', label: 'Coupes'),
    (id: 'friendly', label: 'Amical'),
  ];

  static String _norm(String? competition) =>
      (competition ?? '').trim().toLowerCase();

  static bool isLegacyChampionnatLabel(String? competition) {
    final c = _norm(competition);
    return c.isEmpty || c == 'championnat';
  }

  /// Libellé affiché (anciennes fiches « Championnat » → Régional 1 par défaut).
  static String displayLabel(String? competition) {
    final raw = (competition ?? '').trim();
    if (raw.isEmpty || _norm(raw) == 'championnat') return 'Régional 1';
    return raw;
  }

  static String? canonicalLevel(String? competition) {
    final c = _norm(competition);
    if (c.isEmpty || c == 'championnat') return 'Régional 1';
    for (final r in regularSeason) {
      if (r.toLowerCase() == c) return r;
    }
    return null;
  }

  /// Classement / forme affichés uniquement pour le championnat (saison régulière).
  static bool isRegularSeason(String? competition) {
    if (isLegacyChampionnatLabel(competition)) return true;
    final c = _norm(competition);
    return regularSeason.any((r) => r.toLowerCase() == c);
  }

  static bool isFriendly(String? competition) =>
      _norm(competition).contains('amical');

  static bool isCup(String? competition) {
    if (isFriendly(competition)) return false;
    if (isLegacyChampionnatLabel(competition)) return false;
    if (isRegularSeason(competition)) return false;
    final c = _norm(competition);
    return other.any((o) => o.toLowerCase() == c) ||
        c.contains('coupe') ||
        c == 'barrage';
  }

  /// Filtre liste stats + moyennes saison ([categoryId], [championshipLevel] optionnel).
  static bool matchesStatsFilter(
    String? competition, {
    required String categoryId,
    String? championshipLevel,
  }) {
    switch (categoryId) {
      case 'all':
        return true;
      case 'championship':
        if (!isRegularSeason(competition)) return false;
        if (championshipLevel == null || championshipLevel.isEmpty) {
          return true;
        }
        final level = championshipLevel.trim();
        if (isLegacyChampionnatLabel(competition)) {
          return level == 'Régional 1';
        }
        return canonicalLevel(competition) == level;
      case 'cups':
        return isCup(competition);
      case 'friendly':
        return isFriendly(competition);
      default:
        return displayLabel(competition).toLowerCase() ==
            categoryId.toLowerCase();
    }
  }

  static String statsFilterSummaryLabel({
    required String categoryId,
    String? championshipLevel,
  }) {
    if (categoryId == 'all') return 'toutes compétitions';
    if (categoryId == 'championship') {
      if (championshipLevel != null && championshipLevel.isNotEmpty) {
        return championshipLevel;
      }
      return 'championnat';
    }
    if (categoryId == 'cups') return 'coupes';
    if (categoryId == 'friendly') return 'matchs amicaux';
    return categoryId;
  }
}
