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

  /// Titulaires + remplaçants (sans coach) pour le vote homme du match.
  List<String> get playerNamesForMotm {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in [...starters, ...substitutes]) {
      final name = raw.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      out.add(name);
    }
    return out;
  }

  bool get hasMotmPlayers => playerNamesForMotm.isNotEmpty;

  static List<String> _names(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map) {
            final n = (e['name'] as String? ?? '').trim();
            final no = e['number'];
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
      coach: (m['coach'] as String? ?? '').trim(),
      formation: (m['formation'] as String? ?? '').trim(),
      starters: _names(m['starters']),
      substitutes: _names(m['substitutes']),
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
      home: MatchLineupSide.fromMap(
        d['lineupHome'] as Map<String, dynamic>?,
      ),
      away: MatchLineupSide.fromMap(
        d['lineupAway'] as Map<String, dynamic>?,
      ),
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
}
