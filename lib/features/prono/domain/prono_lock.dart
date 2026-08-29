/// Fermeture des pronos (score 1N2 **et** 1er buteur) : `matches.date`.
///
/// Avant le coup d’envoi → ouvert. À l’heure pile et après → verrouillé.
/// Ne tient pas compte du statut live / finished (un direct lancé trop tôt
/// ne doit pas fermer le pari avant l’heure du match).
bool isMatchPronoLocked(DateTime matchDate, {DateTime? now}) {
  return !(now ?? DateTime.now()).isBefore(matchDate);
}
