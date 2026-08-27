/// Normalisation de noms joueurs pour matching composition / prono XI.
///
/// Trim, minuscules, sans accents, sans numéro de maillot en tête.
String normalizePlayerName(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  // Accents → ASCII approximatif (NFD + strip combining marks).
  s = _stripDiacritics(s);
  // « 9 Dupont » / « 09-Dupont » → « dupont »
  s = s.replaceFirst(RegExp(r'^\d+\s*[-.]?\s*'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

String _stripDiacritics(String input) {
  const map = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'å': 'a',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'é': 'e',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'õ': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
    'ý': 'y',
    'ç': 'c',
    'ñ': 'n',
  };
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

/// Nombre de noms prédits présents dans la compo officielle (chaque officiel 1×).
int countPlayerNameMatches(Iterable<String> predicted, Iterable<String> official) {
  return matchingOfficialPlayerLabels(
    predicted: predicted,
    official: official,
  ).length;
}

/// Libellés officiels (tels qu’affichés) trouvés dans la prédiction.
/// Chaque officiel ne compte qu’une fois — même règle que le scoring Cloud Function.
List<String> matchingOfficialPlayerLabels({
  required Iterable<String> predicted,
  required Iterable<String> official,
}) {
  final pool = <({String label, String key})>[];
  for (final raw in official) {
    final key = normalizePlayerName(raw);
    if (key.isEmpty) continue;
    pool.add((label: raw, key: key));
  }
  final hits = <String>[];
  for (final p in predicted) {
    final n = normalizePlayerName(p);
    if (n.isEmpty) continue;
    final idx = pool.indexWhere((e) => e.key == n);
    if (idx >= 0) {
      hits.add(pool[idx].label);
      pool.removeAt(idx);
    }
  }
  return hits;
}
