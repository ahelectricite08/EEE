/// Postes bénévoles — orthographe exacte (listes Axel, 2026).
///
/// Fenêtre formulaire / liste : du calendrier **J-20 00:00** (inclus)
/// jusqu’à **J-3 12:00** (midi local, exclus à midi pile).
/// Après J-3 12:00 l’événement disparaît de la liste bénévoles.
class BenevolePosts {
  BenevolePosts._();

  static const String typeR1 = 'R1';
  static const String typeCoupe = 'Coupe';
  static const String typeReserve = 'Réserve';
  static const String typeFlammes = 'Flammes';
  static const String typePerso = 'Perso / intervention extérieure';

  /// Anciens libellés Firestore / Make — normalisés via [normalizeType].
  static const String typePremiere = typeR1;

  static const List<String> eventTypes = [
    typeR1,
    typeCoupe,
    typeReserve,
    typeFlammes,
    typePerso,
  ];

  /// Droits profil (`users.benevoleEventRights`). Coupe partage `r1`.
  static const String rightR1 = 'r1';
  static const String rightCoupe = 'coupe';
  static const String rightReserve = 'reserve';
  static const String rightFlammes = 'flammes';
  static const String rightExterieur = 'exterieur';

  static const List<String> allRights = [
    rightR1,
    rightReserve,
    rightFlammes,
    rightExterieur,
  ];

  static const Map<String, String> rightLabels = {
    rightR1: 'R1 / Coupe',
    rightReserve: 'Réserve',
    rightFlammes: 'Flammes',
    rightExterieur: 'Perso / extérieur',
  };

  /// Équipe 1ère — R1 et Coupe (même liste, mot pour mot).
  static const List<String> premiere = [
    'Cadreur plan large',
    'Cadreur plan serré',
    'Cadreur 16m stabi',
    'Cadreur 16m',
    'Cadreur bord terrain stabi',
    'Cadreur bord terrain',
    'Réalisateur',
    'Responsable Post Prod',
    "Chef d'édition – Ralenti",
    'Commentateur match 1',
    'Commentateur match 2',
    'Commentateur bord terrain',
    'Consultant bord terrain et tribune',
    'Présentateur avant/mi-temps/après match',
    'Statisticien 1',
    'Statisticien 2',
    'Chef régisseur',
    'Régisseur 1 (tribune)',
    'Régisseur 2 (camion/édition)',
    'Régisseur 3 (pelouse 1)',
    'Régisseur 4 (pelouse 2)',
    'Community Manager',
    'Responsable buvette 1',
    'Responsable buvette 2',
    'Responsable buvette 3',
    'Responsable buvette 4',
  ];

  static const List<String> reserve = [
    'Vidéo (Réserve)',
    'Commentateur (Réserve)',
  ];

  static const List<String> flammes = [
    'Cadreur plan large',
    'Cadreur plan serré',
    'Cadreur 16m stabi',
    'Cadreur 16m',
    'Réalisateur',
    "Chef d'édition – Ralenti",
    'Régisseur 1 (tribune)',
  ];

  /// Interventions extérieures : même postes que l’équipe 1ère (caméra / régie).
  static const List<String> perso = premiere;

  static const int formOpenDaysBefore = 20;
  static const int formCloseDaysBefore = 3;
  static const int formCloseHour = 12;

  static List<String> allUnique() {
    final seen = <String>{};
    final out = <String>[];
    for (final p in [...premiere, ...reserve, ...flammes]) {
      if (seen.add(p)) out.add(p);
    }
    return out;
  }

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

  static List<String> forEventType(String type) {
    switch (normalizeType(type)) {
      case typeReserve:
        return List<String>.from(reserve);
      case typeFlammes:
        return List<String>.from(flammes);
      case typePerso:
        return List<String>.from(perso);
      case typeCoupe:
      case typeR1:
      default:
        return List<String>.from(premiere);
    }
  }

  /// Droit requis pour voir / répondre à ce type.
  /// Coupe → `r1` (partage R1). Un flag `coupe` seul ouvre aussi la Coupe.
  static String primaryRightForType(String type) {
    switch (normalizeType(type)) {
      case typeReserve:
        return rightReserve;
      case typeFlammes:
        return rightFlammes;
      case typePerso:
        return rightExterieur;
      case typeCoupe:
      case typeR1:
      default:
        return rightR1;
    }
  }

  /// [rights] `null` = champ absent (legacy : tous les types).
  /// Liste vide = aucun type. Admin : tout voir.
  static bool canSeeEventType({
    required String type,
    required List<String>? rights,
    bool isAdmin = false,
  }) {
    if (isAdmin) return true;
    if (rights == null) return true;
    if (rights.isEmpty) return false;
    final set = rights.map((e) => e.trim().toLowerCase()).toSet();
    final normalized = normalizeType(type);
    if (normalized == typeCoupe) {
      return set.contains(rightR1) || set.contains(rightCoupe);
    }
    return set.contains(primaryRightForType(normalized));
  }

  /// Ouvert du jour J-20 00:00 jusqu’à J-3 12:00 (midi local, exclus).
  static bool isFormOpenFor(DateTime eventDate, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final kickDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final openFrom = kickDay.subtract(
      const Duration(days: formOpenDaysBefore),
    );
    final closeDay = kickDay.subtract(
      const Duration(days: formCloseDaysBefore),
    );
    final closeAt = DateTime(
      closeDay.year,
      closeDay.month,
      closeDay.day,
      formCloseHour,
    );
    return !n.isBefore(openFrom) && n.isBefore(closeAt);
  }

  /// Liste bénévoles = fenêtre de réponse (pas d’événements fermés).
  static bool isVisibleFor(DateTime eventDate, {DateTime? now}) =>
      isFormOpenFor(eventDate, now: now);
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
