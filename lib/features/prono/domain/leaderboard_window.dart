/// Fenêtre d’affichage classement Prono : top N + voisins autour de l’utilisateur.
///
/// Pure (testable) — pas de Firestore.
library;

/// Une entrée déjà classée (rang 1-based).
class RankedEntry<T> {
  final int rank;
  final T data;

  const RankedEntry({required this.rank, required this.data});
}

/// Plan d’affichage : top + éventuelle fenêtre locale.
class LeaderboardWindowPlan {
  /// Rangs 1‥topCount à afficher en tête (toujours).
  final int topCount;

  /// `true` si l’utilisateur est hors du top et qu’une 2ᵉ zone doit s’afficher.
  final bool showNeighborZone;

  /// Premier rang de la zone voisins (inclus), ou `null` si pas de zone.
  final int? neighborFrom;

  /// Dernier rang de la zone voisins (inclus), ou `null` si pas de zone.
  final int? neighborTo;

  /// Rang utilisateur (1-based), ou `null` s’il n’est pas classé.
  final int? myRank;

  const LeaderboardWindowPlan({
    required this.topCount,
    required this.showNeighborZone,
    required this.neighborFrom,
    required this.neighborTo,
    required this.myRank,
  });
}

/// Calcule quoi afficher pour un classement.
///
/// - Toujours le **top [topN]** (ou moins s’il y a moins de joueurs).
/// - Si [myRank] > topN : séparateur puis voisins
///   `max(topN+1, myRank-radius) … min(total, myRank+radius)`
///   (évite de re-lister des rangs déjà dans le top).
/// - Bords : 1er / 2e restent dans le top ; dernier → pas de rang+1.
LeaderboardWindowPlan planLeaderboardWindow({
  required int totalCount,
  required int? myRank,
  int topN = 20,
  int neighborRadius = 1,
}) {
  assert(topN >= 1);
  assert(neighborRadius >= 0);
  final topCount = totalCount <= 0 ? 0 : (totalCount < topN ? totalCount : topN);

  if (myRank == null || myRank < 1 || totalCount <= 0) {
    return LeaderboardWindowPlan(
      topCount: topCount,
      showNeighborZone: false,
      neighborFrom: null,
      neighborTo: null,
      myRank: null,
    );
  }

  final clampedRank = myRank > totalCount ? totalCount : myRank;

  if (clampedRank <= topCount) {
    return LeaderboardWindowPlan(
      topCount: topCount,
      showNeighborZone: false,
      neighborFrom: null,
      neighborTo: null,
      myRank: clampedRank,
    );
  }

  // Hors top : voisins, sans chevaucher le top déjà listé.
  final rawFrom = clampedRank - neighborRadius;
  final rawTo = clampedRank + neighborRadius;
  final from = rawFrom < (topCount + 1) ? (topCount + 1) : rawFrom;
  final to = rawTo > totalCount ? totalCount : rawTo;

  if (from > to) {
    return LeaderboardWindowPlan(
      topCount: topCount,
      showNeighborZone: false,
      neighborFrom: null,
      neighborTo: null,
      myRank: clampedRank,
    );
  }

  return LeaderboardWindowPlan(
    topCount: topCount,
    showNeighborZone: true,
    neighborFrom: from,
    neighborTo: to,
    myRank: clampedRank,
  );
}

/// Slice client d’une liste déjà triée (ligues privées, petits datasets).
({
  List<RankedEntry<T>> top,
  List<RankedEntry<T>> neighbors,
  LeaderboardWindowPlan plan,
}) sliceLeaderboardWindow<T>({
  required List<T> sortedEntries,
  required String Function(T entry) uidOf,
  required String? currentUid,
  int topN = 20,
  int neighborRadius = 1,
}) {
  final total = sortedEntries.length;
  int? myRank;
  if (currentUid != null && currentUid.isNotEmpty) {
    final idx = sortedEntries.indexWhere((e) => uidOf(e) == currentUid);
    if (idx >= 0) myRank = idx + 1;
  }

  final plan = planLeaderboardWindow(
    totalCount: total,
    myRank: myRank,
    topN: topN,
    neighborRadius: neighborRadius,
  );

  List<RankedEntry<T>> range(int fromRank, int toRank) {
    final out = <RankedEntry<T>>[];
    for (var r = fromRank; r <= toRank; r++) {
      out.add(RankedEntry(rank: r, data: sortedEntries[r - 1]));
    }
    return out;
  }

  final top = plan.topCount > 0 ? range(1, plan.topCount) : <RankedEntry<T>>[];
  final neighbors = plan.showNeighborZone &&
          plan.neighborFrom != null &&
          plan.neighborTo != null
      ? range(plan.neighborFrom!, plan.neighborTo!)
      : <RankedEntry<T>>[];

  return (top: top, neighbors: neighbors, plan: plan);
}
