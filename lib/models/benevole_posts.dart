/// Postes bénévoles — orthographe exacte (Make / Airtable Julien).
class BenevolePosts {
  BenevolePosts._();

  static const String typePremiere = 'Équipe première';
  static const String typeReserve = 'Équipe réserve';

  /// Catégories extensibles (Flammes, Formation…).
  static const List<String> eventTypes = [
    typePremiere,
    typeReserve,
    'Flammes Carolo',
    'Formation',
    'Autre',
  ];

  static const List<String> premiere = [
    'Cadreur plan large',
    'Cadreur plan serré',
    'Cadreur 16m stabi',
    'Cadreur 16m',
    'Réalisateur',
    'Responsable Post Prod',
    "Chef d'édition – Ralenti",
    'Commentateur match 1',
    'Commentateur match 2',
    'Commentateur bord terrain',
    'Consultant bord terrain et tribune',
    'Présentateur avant match/mi-temps/après match',
    'Statisticien 1',
    'Statisticien 2',
    'Chef régisseur',
    'Régisseur 1 (tribune)',
    'Régisseur 2 (camion/édition)',
    'Régisseur 3 (pelouse)',
    'Community Manager',
    'Buvette local',
  ];

  static const List<String> reserve = [
    'Vidéo',
    'Commentateur',
  ];

  static List<String> allUnique() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in [...premiere, ...reserve]) {
      if (seen.add(p)) out.add(p);
    }
    return out;
  }

  static List<String> forEventType(String type) {
    final t = type.trim();
    if (t == typeReserve) return List<String>.from(reserve);
    if (t == typePremiere) return List<String>.from(premiere);
    // Autres catégories : union (admin filtrera via benevolePostes user)
    return allUnique();
  }
}

/// Statuts présence — texte exact avec accents.
class BenevolePresenceStatus {
  static const present = 'Présent';
  static const availableIfNeeded = 'Disponible si besoin';
  static const absent = 'Absent';

  static const List<String> all = [
    present,
    availableIfNeeded,
    absent,
  ];
}
