/// Types d’événement bénévoles — fiche match / feuille de match (1ère vs R2).
class BenevolePosts {
  BenevolePosts._();

  static const String typeR1 = 'R1';
  static const String typeCoupe = 'Coupe';
  static const String typeReserve = 'Réserve';
  static const String typeFlammes = 'Flammes';
  static const String typePerso = 'Perso / intervention extérieure';

  /// Anciens libellés Firestore — normalisés via [normalizeType].
  static const String typePremiere = typeR1;

  static const List<String> eventTypes = [
    typeR1,
    typeCoupe,
    typeReserve,
    typeFlammes,
    typePerso,
  ];

  static String normalizeType(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return typeR1;
    if (eventTypes.contains(t)) return t;
    final lower = t.toLowerCase();
    if (lower.contains('réserve') || lower.contains('reserve')) {
      return typeReserve;
    }
    if (lower.contains('flammes') || lower.contains('carolo')) {
      return typeFlammes;
    }
    if (lower.contains('coupe')) return typeCoupe;
    if (lower.contains('perso') ||
        lower.contains('extérieur') ||
        lower.contains('exterieur') ||
        lower.contains('intervention') ||
        t == 'Autre' ||
        t == 'Formation') {
      return typePerso;
    }
    if (lower.contains('première') ||
        lower.contains('premiere') ||
        lower == 'r1' ||
        lower.contains('équipe 1') ||
        lower.contains('equipe 1')) {
      return typeR1;
    }
    return typeR1;
  }

  static String inferTypeFromCompetition(String? competition) {
    final c = (competition ?? '').toLowerCase();
    if (c.contains('réserve') || c.contains('reserve')) return typeReserve;
    if (c.contains('flammes') || c.contains('carolo')) return typeFlammes;
    if (c.contains('coupe')) return typeCoupe;
    return typeR1;
  }
}
