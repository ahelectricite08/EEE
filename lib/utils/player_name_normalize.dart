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
  final pool = official.map(normalizePlayerName).where((e) => e.isNotEmpty).toList();
  var matched = 0;
  for (final p in predicted) {
    final n = normalizePlayerName(p);
    if (n.isEmpty) continue;
    final idx = pool.indexOf(n);
    if (idx >= 0) {
      matched++;
      pool.removeAt(idx);
    }
  }
  return matched;
}
