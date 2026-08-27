/// Composition d'équipe (live + fiche `matches`).
class MatchLineupSide {
  final String coach;
  final String formation; // ex. "4-4-2", "3-5-2"
  final List<String> starters;
  final List<String> substitutes;

  const MatchLineupSide({
    this.coach = '',
    this.formation = '',
    this.starters = const [],
    this.substitutes = const [],
  });

  bool get hasContent =>
      coach.trim().isNotEmpty ||
      starters.any((e) => e.trim().isNotEmpty) ||
      substitutes.any((e) => e.trim().isNotEmpty);

  /// Titulaires + remplaçants (sans coach / staff) pour le vote homme du match.
  List<String> get playerNamesForMotm {
    final seen = <String>{};
    final out = <String>[];
    final coachName = coach.trim();
    for (final raw in [...starters, ...substitutes]) {
      final name = raw.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      if (isStaffOrCoachLabel(name, coachName: coachName)) continue;
      seen.add(name);
      out.add(name);
    }
    return out;
  }

  bool get hasMotmPlayers => playerNamesForMotm.isNotEmpty;

  static bool isStaffOrCoachLabel(String name, {String coachName = ''}) {
    final n = name.trim();
    if (n.isEmpty) return true;
    final coach = coachName.trim();
    if (coach.isNotEmpty && n.toLowerCase() == coach.toLowerCase()) {
      return true;
    }
    final label = n
        .toLowerCase()
        .replaceFirst(RegExp(r'^\d+\s+'), '')
        .trim();
    const exactRoles = {
      'entraîneur',
      'entraineur',
      'entraîneure',
      'entraineure',
      'entraîneurs',
      'entraineurs',
      'coach',
      'coachs',
      'staff',
      'préparateur',
      'preparateur',
      'kiné',
      'kine',
    };
    if (exactRoles.contains(label)) return true;
    return RegExp(
      r'\b(entra[iî]neur(e)?s?|coachs?|staff|pr[eé]parateur(s)?|'
      r'directeur(s)?\s+sportif)\b',
      caseSensitive: false,
    ).hasMatch(label);
  }

  static Map<String, dynamic>? mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static List<String> _names(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map) {
            final m = Map<dynamic, dynamic>.from(e);
            final n = (m['name'] ?? m['player'] ?? m['nom'] ?? m['label'] ?? '')
                .toString()
                .trim();
            final no = m['number'];
            if (n.isEmpty) return '';
            if (no is num && no > 0) return '${no.toInt()} $n';
            return n;
          }
          return e.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory MatchLineupSide.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const MatchLineupSide();
    return MatchLineupSide(
      coach: (m['coach'] ?? m['entraineur'] ?? m['entraîneur'] ?? '')
          .toString()
          .trim(),
      formation: (m['formation'] ?? '').toString().trim(),
      starters: _names(m['starters'] ?? m['xi'] ?? m['titulaires']),
      substitutes: _names(
        m['substitutes'] ?? m['bench'] ?? m['remplacants'] ?? m['remplaçants'],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'coach': coach.trim(),
        'formation': formation.trim(),
        'starters': starters.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'substitutes':
            substitutes.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      };
}

class MatchLineups {
  final MatchLineupSide home;
  final MatchLineupSide away;
  final bool showOnCard;

  const MatchLineups({
    this.home = const MatchLineupSide(),
    this.away = const MatchLineupSide(),
    this.showOnCard = false,
  });

  bool get hasAnyContent => home.hasContent || away.hasContent;

  /// Les deux équipes ont au moins un joueur (titulaire ou remplaçant).
  bool get readyForMotmVote =>
      home.hasMotmPlayers && away.hasMotmPlayers;

  /// Interrupteur admin : compositions sur la carte **accueil** uniquement.
  bool get visibleOnHomeCard => showOnCard && hasAnyContent;

  /// Cartes match (calendrier, fiche, etc.) : toujours si données présentes.
  bool visibleOnMatchCard({required bool isHomeCard}) =>
      hasAnyContent && (!isHomeCard || showOnCard);

  factory MatchLineups.fromDoc(Map<String, dynamic>? d) {
    if (d == null) {
      return const MatchLineups();
    }
    return MatchLineups(
      home: MatchLineupSide.fromMap(MatchLineupSide.mapFrom(d['lineupHome'])),
      away: MatchLineupSide.fromMap(MatchLineupSide.mapFrom(d['lineupAway'])),
      showOnCard: d['showLineupOnCard'] == true,
    );
  }

  /// Fusionne fiche `matches` + archive `match_stats`.
  static MatchLineups mergeDocs(
    Map<String, dynamic>? primary,
    Map<String, dynamic>? secondary,
  ) {
    final a = MatchLineups.fromDoc(primary);
    if (a.hasAnyContent) return a;
    return MatchLineups.fromDoc(secondary);
  }

  /// Préfère le côté qui a des joueurs (XI / banc), pas seulement un coach.
  static MatchLineups mergeForMotm(
    Map<String, dynamic>? live, [
    Map<String, dynamic>? match,
    Map<String, dynamic>? stats,
  ]) {
    MatchLineupSide pick(MatchLineupSide a, MatchLineupSide b, MatchLineupSide c) {
      if (a.hasMotmPlayers) return a;
      if (b.hasMotmPlayers) return b;
      if (c.hasMotmPlayers) return c;
      return a;
    }

    final a = MatchLineups.fromDoc(live);
    final b = MatchLineups.fromDoc(match);
    final c = MatchLineups.fromDoc(stats);
    return MatchLineups(
      home: pick(a.home, b.home, c.home),
      away: pick(a.away, b.away, c.away),
      showOnCard: a.showOnCard || b.showOnCard || c.showOnCard,
    );
  }
}
