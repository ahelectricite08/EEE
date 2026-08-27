import 'lineup_prediction.dart';
import '../utils/player_name_normalize.dart';

/// Verdict XI probable **Sedan / CSSA uniquement** une fois la compo officielle
/// publiée. Jamais d’adversaire : pas de jeu, pas de score, pas de « t’as bon »
/// sur le XI visiteur.
enum LineupXiVerdictKind {
  /// Aucun XI probable Sedan soumis (ou incomplet).
  empty,

  /// Moins de 9 titulaires Sedan trouvés — 0 pt classement.
  missed,

  /// 9 ou 10 titulaires Sedan — points classement, pas le sans-faute.
  almost,

  /// 11 / 11 titulaires Sedan.
  perfect,
}

class LineupXiVerdict {
  static const String kicker = 'XI PROBABLE · SEDAN';

  static const String titleBon = 'T’as bon';
  static const String titlePresque = 'T’as presque bon';
  static const String titlePasBon = 'T’as pas bon';
  static const String titleEmpty = 'Pas de XI probable';

  /// CTA si aucun XI Sedan n’a été posé. Fenêtre = verrou 60 h, inchangé.
  static String emptyBody({
    String lockWindow = LineupPrediction.lockWindowLabel,
  }) =>
      'Reviens la prochaine fois, $lockWindow, pour poser ton XI probable '
      'Sedan et gagner des points au classement.';

  final LineupXiVerdictKind kind;
  final int matched;
  final int total;
  final int rankingPoints;

  const LineupXiVerdict({
    required this.kind,
    required this.matched,
    this.total = LineupPrediction.requiredPlayers,
    required this.rankingPoints,
  });

  factory LineupXiVerdict.empty() => const LineupXiVerdict(
        kind: LineupXiVerdictKind.empty,
        matched: 0,
        rankingPoints: 0,
      );

  bool get hasPrediction => kind != LineupXiVerdictKind.empty;

  String get title => switch (kind) {
        LineupXiVerdictKind.empty => titleEmpty,
        LineupXiVerdictKind.perfect => titleBon,
        LineupXiVerdictKind.almost => titlePresque,
        LineupXiVerdictKind.missed => titlePasBon,
      };

  String get body {
    if (kind == LineupXiVerdictKind.empty) return emptyBody();
    final countLine = matched == 0
        ? 'Aucun titulaire Sedan trouvé.'
        : matched == 1
            ? '1 titulaire Sedan sur $total.'
            : '$matched titulaires Sedan sur $total.';
    if (rankingPoints > 0) {
      final pts = rankingPoints == 1
          ? '+1 pt au classement Pronos.'
          : '+$rankingPoints pts au classement Pronos.';
      return '$countLine $pts';
    }
    return countLine;
  }

  /// Compare uniquement aux **titulaires Sedan**. [officialSedanStarters]
  /// ne doit jamais être le XI adverse.
  factory LineupXiVerdict.resolve({
    required LineupPrediction? prediction,
    required List<String> officialSedanStarters,
  }) {
    final pred = prediction;
    if (pred == null || !pred.isComplete) {
      return LineupXiVerdict.empty();
    }

    final computed = countPlayerNameMatches(
      pred.playerNames,
      officialSedanStarters,
    );
    final matched = pred.matchedCount ?? computed;
    final points = pred.points ?? LineupPrediction.pointsForMatches(matched);

    final LineupXiVerdictKind kind;
    if (matched >= LineupPrediction.requiredPlayers) {
      kind = LineupXiVerdictKind.perfect;
    } else if (matched >= 9) {
      kind = LineupXiVerdictKind.almost;
    } else {
      kind = LineupXiVerdictKind.missed;
    }

    return LineupXiVerdict(
      kind: kind,
      matched: matched,
      rankingPoints: points,
    );
  }

  /// Libellés du XI **Sedan** trouvés dans le prono — pour un petit tampon
  /// sur la colonne CSSA, jamais sur l’adversaire.
  static Set<String> hitSedanStarterLabels({
    required LineupPrediction? prediction,
    required List<String> officialSedanStarters,
  }) {
    if (prediction == null || !prediction.isComplete) return const {};
    return matchingOfficialPlayerLabels(
      predicted: prediction.playerNames,
      official: officialSedanStarters,
    ).toSet();
  }
}
