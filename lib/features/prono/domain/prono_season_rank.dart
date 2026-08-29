/// Ordre unique du classement saison prono (même règle pour tout le peloton).
///
/// 1. [points] décroissant (total classement)
/// 2. [exactScores] décroissant (scores exacts)
/// 3. [lineupPoints] décroissant (points XI probable, pas le compteur 11/11)
/// 4. [firstScorerPoints] décroissant (points 1er buteur)
/// 5. [uid] A→Z — départage stable si les 4 clés sont égales
///
/// Les rangs 1…N sont l’indice après ce tri (pas « 1 + joueurs avec plus
/// de points », qui écrase les égalités).
int comparePronoSeasonRank({
  required int pointsA,
  required int exactA,
  required int lineupPointsA,
  required int firstScorerPointsA,
  required String uidA,
  required int pointsB,
  required int exactB,
  required int lineupPointsB,
  required int firstScorerPointsB,
  required String uidB,
}) {
  final byPoints = pointsB.compareTo(pointsA);
  if (byPoints != 0) return byPoints;
  final byExact = exactB.compareTo(exactA);
  if (byExact != 0) return byExact;
  final byXiPts = lineupPointsB.compareTo(lineupPointsA);
  if (byXiPts != 0) return byXiPts;
  final byFs = firstScorerPointsB.compareTo(firstScorerPointsA);
  if (byFs != 0) return byFs;
  return uidA.toLowerCase().compareTo(uidB.toLowerCase());
}

/// Range [entries] et pose un rang 1-based selon [comparePronoSeasonRank].
List<({int rank, T entry})> rankPronoSeasonEntries<T>({
  required List<T> entries,
  required int Function(T e) pointsOf,
  required int Function(T e) exactOf,
  required int Function(T e) lineupPointsOf,
  required int Function(T e) firstScorerPointsOf,
  required String Function(T e) uidOf,
}) {
  final sorted = [...entries]..sort(
      (a, b) => comparePronoSeasonRank(
        pointsA: pointsOf(a),
        exactA: exactOf(a),
        lineupPointsA: lineupPointsOf(a),
        firstScorerPointsA: firstScorerPointsOf(a),
        uidA: uidOf(a),
        pointsB: pointsOf(b),
        exactB: exactOf(b),
        lineupPointsB: lineupPointsOf(b),
        firstScorerPointsB: firstScorerPointsOf(b),
        uidB: uidOf(b),
      ),
    );
  return [
    for (var i = 0; i < sorted.length; i++) (rank: i + 1, entry: sorted[i]),
  ];
}
