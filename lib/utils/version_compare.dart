/// Compare deux numéros de version sémantiques (`1.0.1` vs `1.0.2`).
/// Retourne un entier négatif si [current] est plus ancien que [minimum].
int compareSemanticVersions(String current, String minimum) {
  final a = _parts(current);
  final b = _parts(minimum);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

List<int> _parts(String v) {
  return v
      .split('.')
      .map((e) => int.tryParse(e.trim()) ?? 0)
      .toList(growable: false);
}
