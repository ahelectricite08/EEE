import 'package:flutter/foundation.dart';

/// Prono déjà scoré (championnat ou Coupe du monde) pour l’historique « 10 derniers ».
@immutable
class RecentPronoRow {
  final String matchId;
  final String team1;
  final String team2;
  final DateTime orderDate;
  final int predHome;
  final int predAway;
  final int? resHome;
  final int? resAway;
  /// Points classement prono : 3 = score exact, 1 = bon résultat, 0 = raté.
  final int pronoPoints;
  final bool isWorldCup;

  const RecentPronoRow({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.orderDate,
    required this.predHome,
    required this.predAway,
    required this.resHome,
    required this.resAway,
    required this.pronoPoints,
    required this.isWorldCup,
  });

  /// XP affichée : alignée sur les récaps push (exact 20, bon résultat 8, raté 0).
  static int xpForPronoPoints(int p) {
    switch (p) {
      case 3:
        return 20;
      case 1:
        return 8;
      default:
        return 0;
    }
  }

  String get outcomeLabel {
    switch (pronoPoints) {
      case 3:
        return 'EXACT';
      case 1:
        return 'GAGNÉE';
      default:
        return 'PERDU';
    }
  }

  String get outcomePointsLabel => switch (pronoPoints) {
        3 => '+3',
        1 => '+1',
        _ => '+0',
      };

  int get xpGain => xpForPronoPoints(pronoPoints);
}
