import 'package:flutter/foundation.dart';

import '../../../models/crowd_xi.dart';
import '../../../models/lineup_prediction.dart';
import '../../../models/lineup_xi_verdict.dart';
import '../../../models/sedan_squad.dart';

/// XI probable déjà posé (accueil « Mes compos »).
@immutable
class MyCompoItem {
  final String matchId;
  final String team1;
  final String team2;
  final DateTime matchDate;
  final String? logo1;
  final String? logo2;
  final String? competition;
  final LineupPrediction prediction;
  final List<String> officialSedanStarters;
  final bool officialPublished;
  final CrowdXi? crowdXi;

  const MyCompoItem({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.matchDate,
    this.logo1,
    this.logo2,
    this.competition,
    required this.prediction,
    this.officialSedanStarters = const [],
    this.officialPublished = false,
    this.crowdXi,
  });

  bool get isScored => officialPublished || prediction.awarded;

  LineupXiVerdict verdict({SedanSquad? squad}) => LineupXiVerdict.resolve(
        prediction: prediction,
        officialSedanStarters: officialSedanStarters,
        squad: squad,
      );

  List<LineupXiPlayerMark> marks({SedanSquad squad = SedanSquad.empty}) =>
      LineupXiVerdict.marksFor(
        prediction: prediction,
        officialSedanStarters: officialSedanStarters,
        squad: squad,
      );
}
