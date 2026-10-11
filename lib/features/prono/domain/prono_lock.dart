/// Fermeture des pronos (score 1N2 **et** 1er buteur) : `matches.date`.
///
/// Avant le coup d’envoi → ouvert. À l’heure pile et après → verrouillé.
/// Ne tient pas compte du statut live / finished (un direct lancé trop tôt
/// ne doit pas fermer le pari avant l’heure du match).
bool isMatchPronoLocked(DateTime matchDate, {DateTime? now}) {
  return !(now ?? DateTime.now()).isBefore(matchDate);
}

/// Fenêtre prono ouverte : du 7e jour avant le match jusqu’au coup d’envoi.
bool isMatchPronoWindowOpen(DateTime matchDate, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final openAt = matchDate.subtract(const Duration(days: 7));
  return t.isAfter(openAt) && !isMatchPronoLocked(matchDate, now: t);
}

/// Feuille visible (poser ou relire un prono) : dès J-7, y compris match en cours.
bool isMatchPronoViewable(DateTime matchDate, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return !t.isBefore(matchDate.subtract(const Duration(days: 7)));
}

bool isMatchPronoSettled({
  required String status,
  int? score1,
  int? score2,
}) {
  if (score1 == null || score2 == null) return false;
  return status.trim().toLowerCase() == 'finished';
}

/// Coup d’envoi passé, score officiel pas encore posé.
bool isMatchPronoInPlay(
  DateTime matchDate, {
  required String status,
  int? score1,
  int? score2,
  DateTime? now,
}) {
  return isMatchPronoLocked(matchDate, now: now) &&
      !isMatchPronoSettled(
        status: status,
        score1: score1,
        score2: score2,
      );
}

/// Libellé CTA / tampon. [compact] pour la gouttière du calendrier Pronos.
String pronoCtaLabel({
  required DateTime matchDate,
  required bool hasPred,
  String status = 'upcoming',
  int? score1,
  int? score2,
  DateTime? now,
  bool compact = false,
}) {
  final t = now ?? DateTime.now();
  if (!isMatchPronoLocked(matchDate, now: t)) {
    if (!isMatchPronoWindowOpen(matchDate, now: t)) {
      return 'Bientôt';
    }
    if (hasPred) {
      return compact ? 'Modifier' : 'Modifier mon prono';
    }
    return compact ? 'Jouer' : 'Pronostiquer';
  }
  if (isMatchPronoInPlay(
    matchDate,
    status: status,
    score1: score1,
    score2: score2,
    now: t,
  )) {
    return compact ? 'Verrouillé' : 'Prono verrouillé · match en cours';
  }
  return compact ? 'Résultat' : 'Prono verrouillé';
}

/// Au-delà, le match sort du tableau Pronos — il reste dans « Mes pronos ».
const Duration pronoBoardLookback = Duration(days: 2);

String pronoScorePair(int home, int away) => '$home–$away';

/// Ligne calendrier : uniquement le score posé (le résultat est déjà en gros).
String pronoPostedLine({
  required int predHome,
  required int predAway,
  int? points,
}) {
  final pred = 'Ton prono ${pronoScorePair(predHome, predAway)}';
  if (points == null) return pred;
  if (points > 0) return '$pred  ·  +$points';
  return '$pred  ·  0 pt';
}

/// Ligne « ton prono vs score ». [live] = score encore en cours.
String pronoVersusResultLine({
  required int predHome,
  required int predAway,
  int? resHome,
  int? resAway,
  bool live = false,
  int? points,
}) {
  final pred = pronoScorePair(predHome, predAway);
  if (resHome == null || resAway == null) {
    return pronoPostedLine(
      predHome: predHome,
      predAway: predAway,
      points: points,
    );
  }
  final res = pronoScorePair(resHome, resAway);
  final vs = live ? 'Ton prono $pred  ·  live $res' : 'Ton prono $pred  ·  $res';
  if (points == null) return vs;
  if (points > 0) return '$vs  ·  +$points';
  return '$vs  ·  0 pt';
}
