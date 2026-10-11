/// Normalisation + ressemblance de noms pour le XI probable Sedan.
///
/// Même règles que `functions/lib/lineup_name_match.js` — verdict client =
/// points serveur.

class PlayerNameHit {
  final int predictedIndex;
  final String predictedRaw;
  final int officialIndex;
  final String officialRaw;

  const PlayerNameHit({
    required this.predictedIndex,
    required this.predictedRaw,
    required this.officialIndex,
    required this.officialRaw,
  });
}

/// Trim, minuscules, sans accents, sans apostrophe/tiret, sans n° de maillot.
String normalizePlayerName(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  s = _stripDiacritics(s);
  s = s.replaceAll(RegExp(r"[''`´’-]"), '');
  s = s.replaceFirst(RegExp(r'^\d+\s*[-.]?\s*'), '');
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]+'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

String lastNameToken(String normalizedFull) {
  final parts = normalizedFull
      .split(' ')
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  return parts.last;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final m = a.length;
  final n = b.length;
  final dp = List<int>.generate(n + 1, (j) => j);
  for (var i = 1; i <= m; i++) {
    var prevDiag = dp[0];
    dp[0] = i;
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final tmp = dp[j];
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = dp[j] + 1;
      final ins = dp[j - 1] + 1;
      final sub = prevDiag + cost;
      dp[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      prevDiag = tmp;
    }
  }
  return dp[n];
}

bool _isLetterLastName(String token) =>
    token.length >= 3 && RegExp(r'^[a-z]+$').hasMatch(token);

/// Ressemblance nom de famille uniquement. Jetons < 3 lettres : jamais flou.
/// Pas de flou si le jeton contient un chiffre (évite S10 ≈ X10).
bool lastNamesResemble(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  if (!_isLetterLastName(a) || !_isLetterLastName(b)) return false;
  final d = levenshtein(a, b);
  if (d <= 1) return true;
  if (d == 2 &&
      a.length >= 6 &&
      b.length >= 6 &&
      a.codeUnitAt(0) == b.codeUnitAt(0)) {
    return true;
  }
  return false;
}

List<String> resolvePredictedLabels({
  required List<String> names,
  List<String> ids = const [],
  Map<String, String> squadIdToName = const {},
}) {
  if (ids.isEmpty || squadIdToName.isEmpty) {
    return names.where((e) => e.trim().isNotEmpty).toList();
  }
  final n = names.length > ids.length ? names.length : ids.length;
  final out = <String>[];
  for (var i = 0; i < n; i++) {
    final id = i < ids.length ? ids[i].trim() : '';
    final fromSquad = id.isNotEmpty ? squadIdToName[id] : null;
    if (fromSquad != null && fromSquad.trim().isNotEmpty) {
      out.add(fromSquad.trim());
      continue;
    }
    if (i < names.length && names[i].trim().isNotEmpty) {
      out.add(names[i].trim());
    }
  }
  return out;
}

/// Appariement prédit → officiel. Chaque officiel au plus une fois.
///
/// 1) nom complet normalisé exact
/// 2) nom de famille exact si unique dans les deux listes (≥ 3 lettres)
/// 3) Levenshtein sur le nom de famille, unique, d≤1 (d=2 si longueur ≥ 6)
List<PlayerNameHit> matchPlayerNames({
  required List<String> predicted,
  required List<String> official,
}) {
  final pool = <_Off>[];
  for (var i = 0; i < official.length; i++) {
    final raw = official[i];
    final norm = normalizePlayerName(raw);
    if (norm.isEmpty) continue;
    pool.add(_Off(i, raw, norm));
  }

  final predItems = <_Pred>[];
  for (var i = 0; i < predicted.length; i++) {
    final raw = predicted[i];
    final norm = normalizePlayerName(raw);
    if (norm.isEmpty) continue;
    predItems.add(_Pred(i, raw, norm));
  }

  final officialLastCounts = <String, int>{};
  for (final e in pool) {
    final last = lastNameToken(e.norm);
    if (last.isEmpty) continue;
    officialLastCounts[last] = (officialLastCounts[last] ?? 0) + 1;
  }
  final predLastCounts = <String, int>{};
  for (final e in predItems) {
    final last = lastNameToken(e.norm);
    if (last.isEmpty) continue;
    predLastCounts[last] = (predLastCounts[last] ?? 0) + 1;
  }

  final used = <int>{};
  final takenPred = <int>{};
  final hits = <PlayerNameHit>[];

  void take(_Pred p, _Off o) {
    used.add(o.i);
    takenPred.add(p.i);
    hits.add(PlayerNameHit(
      predictedIndex: p.i,
      predictedRaw: p.raw,
      officialIndex: o.i,
      officialRaw: o.raw,
    ));
  }

  for (final p in predItems) {
    for (final o in pool) {
      if (used.contains(o.i)) continue;
      if (o.norm == p.norm) {
        take(p, o);
        break;
      }
    }
  }

  for (final p in predItems) {
    if (takenPred.contains(p.i)) continue;
    final last = lastNameToken(p.norm);
    if (!_isLetterLastName(last)) continue;
    if (officialLastCounts[last] != 1) continue;
    if (predLastCounts[last] != 1) continue;
    for (final o in pool) {
      if (used.contains(o.i)) continue;
      if (lastNameToken(o.norm) == last) {
        take(p, o);
        break;
      }
    }
  }

  for (final p in predItems) {
    if (takenPred.contains(p.i)) continue;
    final last = lastNameToken(p.norm);
    if (!_isLetterLastName(last)) continue;
    if (predLastCounts[last] != 1) continue;
    final candidates = <_Off>[];
    for (final o in pool) {
      if (used.contains(o.i)) continue;
      final oLast = lastNameToken(o.norm);
      if (!_isLetterLastName(oLast)) continue;
      if (officialLastCounts[oLast] != 1) continue;
      if (lastNamesResemble(last, oLast)) candidates.add(o);
    }
    if (candidates.length == 1) take(p, candidates.first);
  }

  return hits;
}

int countPlayerNameMatches(
  Iterable<String> predicted,
  Iterable<String> official,
) {
  return matchPlayerNames(
    predicted: predicted.toList(),
    official: official.toList(),
  ).length;
}

List<String> matchingOfficialPlayerLabels({
  required Iterable<String> predicted,
  required Iterable<String> official,
}) {
  return [
    for (final h in matchPlayerNames(
      predicted: predicted.toList(),
      official: official.toList(),
    ))
      h.officialRaw,
  ];
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

class _Off {
  final int i;
  final String raw;
  final String norm;
  _Off(this.i, this.raw, this.norm);
}

class _Pred {
  final int i;
  final String raw;
  final String norm;
  _Pred(this.i, this.raw, this.norm);
}
