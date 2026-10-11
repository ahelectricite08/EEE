/// XI agrégé du vestiaire — `matches/{id}.crowdXi` (Cloud Function).
class CrowdXiPlayer {
  final String name;
  final int votes;
  final bool inOfficial;

  const CrowdXiPlayer({
    required this.name,
    required this.votes,
    this.inOfficial = false,
  });

  factory CrowdXiPlayer.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    return CrowdXiPlayer(
      name: (m['name'] ?? '').toString().trim(),
      votes: m['votes'] is num ? (m['votes'] as num).toInt() : 0,
      inOfficial: m['inOfficial'] == true,
    );
  }
}

class CrowdXi {
  final List<CrowdXiPlayer> players;
  final int ballots;
  final int officialHits;
  final bool officialComputed;

  const CrowdXi({
    required this.players,
    required this.ballots,
    required this.officialHits,
    required this.officialComputed,
  });

  static const int requiredPlayers = 11;

  bool get isReady =>
      players.length >= requiredPlayers && ballots > 0;

  factory CrowdXi.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final players = <CrowdXiPlayer>[];
    final list = m['players'];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final p = CrowdXiPlayer.fromMap(e);
          if (p.name.isNotEmpty) players.add(p);
        } else if (e is Map) {
          final p = CrowdXiPlayer.fromMap(
            e.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (p.name.isNotEmpty) players.add(p);
        }
      }
    }
    return CrowdXi(
      players: players.take(requiredPlayers).toList(),
      ballots: m['ballots'] is num ? (m['ballots'] as num).toInt() : 0,
      officialHits:
          m['officialHits'] is num ? (m['officialHits'] as num).toInt() : 0,
      officialComputed: m['officialComputed'] == true,
    );
  }

  static CrowdXi? fromMatchDoc(Map<String, dynamic>? matchDoc) {
    final raw = matchDoc?['crowdXi'];
    if (raw is! Map) return null;
    final parsed = CrowdXi.fromMap(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    return parsed.isReady ? parsed : null;
  }
}
