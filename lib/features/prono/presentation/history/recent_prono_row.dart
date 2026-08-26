import 'package:flutter/foundation.dart';

import '../../domain/prono_xp_scale.dart';

/// Prono déjà scoré (championnat) pour l’historique « 10 derniers ».
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
  });

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

  /// L’XP dépend du barème administrable, pas de la ligne : voir [PronoXpScale].
  int xpGain(PronoXpScale scale) => scale.forPronoPoints(pronoPoints);
}
