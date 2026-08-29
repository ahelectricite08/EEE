/// Fenêtres des sondages supporters.
///
/// Place (« où tu regardes ») : H-30 inclus → KO+20 exclus.
/// K-way : dès la fiche prochain CSSA, fermeture KO+20 exclusive (pas d’H-30).
abstract final class MatchFanPollWindow {
  static const Duration beforeKickoff = Duration(minutes: 30);
  static const Duration afterKickoff = Duration(minutes: 20);

  static DateTime opensAt(DateTime kickoff) =>
      kickoff.subtract(beforeKickoff);

  static DateTime closesAt(DateTime kickoff) => kickoff.add(afterKickoff);

  /// Domicile Dugauguez : [opensAt] inclus → [closesAt] exclus.
  static bool isPlaceOpen({
    required DateTime? kickoff,
    required DateTime now,
  }) {
    if (kickoff == null) return false;
    if (now.isBefore(opensAt(kickoff))) return false;
    return now.isBefore(closesAt(kickoff));
  }

  /// Alias place — ne pas utiliser pour le k-way.
  static bool isOpen({
    required DateTime? kickoff,
    DateTime? now,
  }) =>
      isPlaceOpen(kickoff: kickoff, now: now ?? DateTime.now());

  /// K-way : ouvert tant que [now] < KO+20. Pas de borne H-30.
  static bool isKwayOpen({
    required DateTime kickoff,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return n.isBefore(closesAt(kickoff));
  }
}
