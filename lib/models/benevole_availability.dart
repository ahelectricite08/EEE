class BenevoleAvailabilityBoard {
  final String email;
  final List<String> posts;
  final List<BenevoleMatchDispo> matches;

  const BenevoleAvailabilityBoard({
    required this.email,
    required this.posts,
    required this.matches,
  });

  factory BenevoleAvailabilityBoard.fromMap(Map<String, dynamic> raw) {
    final posts = (raw['posts'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final matches = (raw['matches'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => BenevoleMatchDispo.fromMap(Map<String, dynamic>.from(e)))
        .where((m) => m.putId.isNotEmpty)
        .toList();
    return BenevoleAvailabilityBoard(
      email: (raw['email'] ?? '').toString(),
      posts: posts,
      matches: matches,
    );
  }
}

class BenevoleMatchDispo {
  final String id;
  final String putId;
  final String homeTeam;
  final String awayTeam;
  final DateTime? kickoffAt;
  final String? venue;
  final String? city;
  final String? competition;
  final String? round;
  final String? status;
  final List<String> wishes;

  const BenevoleMatchDispo({
    required this.id,
    required this.putId,
    required this.homeTeam,
    required this.awayTeam,
    this.kickoffAt,
    this.venue,
    this.city,
    this.competition,
    this.round,
    this.status,
    this.wishes = const [],
  });

  factory BenevoleMatchDispo.fromMap(Map<String, dynamic> raw) {
    DateTime? kick;
    final kickRaw = raw['kickoffAt'];
    if (kickRaw is String && kickRaw.trim().isNotEmpty) {
      kick = DateTime.tryParse(kickRaw.trim());
    }
    return BenevoleMatchDispo(
      id: (raw['id'] ?? '').toString(),
      putId: (raw['putId'] ?? raw['externalId'] ?? raw['id'] ?? '').toString(),
      homeTeam: (raw['homeTeam'] ?? '').toString(),
      awayTeam: (raw['awayTeam'] ?? '').toString(),
      kickoffAt: kick,
      venue: _nz(raw['venue']),
      city: _nz(raw['city']),
      competition: _nz(raw['competition']),
      round: _nz(raw['round']),
      status: _nz(raw['status'])?.toUpperCase(),
      wishes: (raw['wishes'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  static String? _nz(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class BenevolePresenceStatus {
  static const present = 'PRESENT';
  static const absent = 'ABSENT';

  static const labels = {
    present: 'Présent',
    absent: 'Absent',
  };
}
