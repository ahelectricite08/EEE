/// Classement poule à partir des scores officiels (pas inventés).
class PouleTableRow {
  final String team;
  int mj;
  int v;
  int n;
  int d;
  int bf;
  int bc;
  int pts;
  String? logo;

  PouleTableRow({
    required this.team,
    this.mj = 0,
    this.v = 0,
    this.n = 0,
    this.d = 0,
    this.bf = 0,
    this.bc = 0,
    this.pts = 0,
    this.logo,
  });

  int get diff => bf - bc;
}

class PouleTable {
  final List<PouleTableRow> rows;
  final int maxJournee;

  const PouleTable({required this.rows, this.maxJournee = 0});

  int get gamesPlayed =>
      rows.fold<int>(0, (s, r) => s + r.mj) ~/ 2;
}

PouleTable pouleTableFromMatches(
  Iterable<Map<String, dynamic>> matches, {
  String? seasonLabel,
}) {
  final byTeam = <String, PouleTableRow>{};
  var maxJournee = 0;

  void touch(String raw, String? logo) {
    final team = raw.trim();
    if (team.isEmpty) return;
    final cur = byTeam.putIfAbsent(team, () => PouleTableRow(team: team));
    final l = (logo ?? '').trim();
    if (l.isNotEmpty) cur.logo = l;
  }

  void play(String home, String away, int s1, int s2) {
    touch(home, null);
    touch(away, null);
    final h = byTeam[home.trim()]!;
    final a = byTeam[away.trim()]!;
    h.mj += 1;
    a.mj += 1;
    h.bf += s1;
    h.bc += s2;
    a.bf += s2;
    a.bc += s1;
    if (s1 > s2) {
      h.v += 1;
      h.pts += 3;
      a.d += 1;
    } else if (s2 > s1) {
      a.v += 1;
      a.pts += 3;
      h.d += 1;
    } else {
      h.n += 1;
      a.n += 1;
      h.pts += 1;
      a.pts += 1;
    }
  }

  for (final m in matches) {
    if (seasonLabel != null && seasonLabel.trim().isNotEmpty) {
      final fs = (m['fffSeason'] as String?)?.trim() ?? '';
      if (fs.isNotEmpty && fs != seasonLabel) continue;
    }
    final s1 = _score(m['score1'] ?? m['homeScore']);
    final s2 = _score(m['score2'] ?? m['awayScore']);
    if (s1 == null || s2 == null) continue;
    final t1 = (m['team1'] as String? ?? '').trim();
    final t2 = (m['team2'] as String? ?? '').trim();
    if (t1.isEmpty || t2.isEmpty) continue;
    touch(t1, m['logo1']?.toString());
    touch(t2, m['logo2']?.toString());
    play(t1, t2, s1, s2);
    final j = _score(m['journee']) ?? 0;
    if (j > maxJournee) maxJournee = j;
  }

  final rows = byTeam.values.toList()
    ..sort((a, b) {
      final p = b.pts.compareTo(a.pts);
      if (p != 0) return p;
      final gd = b.diff.compareTo(a.diff);
      if (gd != 0) return gd;
      final gf = b.bf.compareTo(a.bf);
      if (gf != 0) return gf;
      return a.team.toLowerCase().compareTo(b.team.toLowerCase());
    });
  return PouleTable(rows: rows, maxJournee: maxJournee);
}

/// Ordre / points / MJ différents → le tableau stocké n’est pas celui des scores.
bool pouleStandingsDiffer(
  List<PouleTableRow> computed,
  List<PouleTableRow> stored,
) {
  if (computed.length != stored.length) return true;
  for (var i = 0; i < computed.length; i++) {
    final a = computed[i];
    final b = stored[i];
    if (a.team.trim().toUpperCase() != b.team.trim().toUpperCase()) {
      return true;
    }
    if (a.pts != b.pts || a.mj != b.mj || a.diff != b.diff || a.bf != b.bf) {
      return true;
    }
  }
  return false;
}

/// Recalculer le classement live si les scores officiels sont au moins aussi
/// complets que la table FFF — y compris quand le MJ est égal mais l’ordre
/// (Sedan / Reims) a changé. Ne jamais écraser une poule complète par un
/// extrait (ex. seulement les matchs Sedan).
bool pouleTableShouldReplaceRanking(
  PouleTable table,
  List<PouleTableRow> stored, {
  int minTeams = 8,
}) {
  if (table.rows.length < minTeams) return false;
  if (stored.length >= minTeams && table.rows.length < stored.length) {
    return false;
  }
  if (stored.isEmpty) return true;

  final storedGames = stored.fold<int>(0, (s, r) => s + r.mj) ~/ 2;
  var storedMaxMj = 0;
  var tableMaxMj = 0;
  for (final r in stored) {
    if (r.mj > storedMaxMj) storedMaxMj = r.mj;
  }
  for (final r in table.rows) {
    if (r.mj > tableMaxMj) tableMaxMj = r.mj;
  }

  if (table.gamesPlayed < storedGames && tableMaxMj <= storedMaxMj) {
    return false;
  }
  // Jamais plus d’une journée d’avance : un tableau « 19 MJ / 53 pts »
  // mélange d’anciennes saisons, pas le classement FFF.
  if (stored.length >= minTeams && storedMaxMj > 0 && storedMaxMj <= 26) {
    if (tableMaxMj > storedMaxMj + 1) return false;
    if (table.gamesPlayed > storedGames + ((stored.length + 1) ~/ 2)) {
      return false;
    }
  }
  if (table.gamesPlayed > storedGames || tableMaxMj > storedMaxMj) {
    return true;
  }
  return pouleStandingsDiffer(table.rows, stored);
}

int? _score(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString().trim());
}
