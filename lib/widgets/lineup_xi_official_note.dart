import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/prono/presentation/widgets/prono_predict_stage.dart';
import '../models/lineup_prediction.dart';
import '../models/lineup_xi_verdict.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/sedan_squad.dart';
import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';
import '../screens/matches/matches_helpers.dart';
import '../services/lineup_prediction_service.dart';

/// Charge le XI probable Sedan (s’il existe) pour le verdict post-compo.
class LineupXiOfficialBridge extends StatelessWidget {
  final MatchModel match;
  final MatchLineups lineups;
  final SedanSquad squad;
  final Widget Function(
    BuildContext context,
    LineupXiVerdict verdict,
    Set<String> sedanHits,
    LineupPrediction? prediction,
  ) builder;

  const LineupXiOfficialBridge({
    super.key,
    required this.match,
    required this.lineups,
    this.squad = SedanSquad.empty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final sedanStarters =
        LineupPredictionService.sedanSide(lineups, match)
            ?.starters
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    Widget fromPred(LineupPrediction? pred) {
      final verdict = LineupXiVerdict.resolve(
        prediction: pred,
        officialSedanStarters: sedanStarters,
        squad: squad,
      );
      final hits = LineupXiVerdict.hitSedanStarterLabels(
        prediction: pred,
        officialSedanStarters: sedanStarters,
        squad: squad,
      );
      return builder(context, verdict, hits, pred);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return fromPred(null);

    return StreamBuilder<LineupPrediction?>(
      stream: LineupPredictionService.watchUserPrediction(
        match.id,
        user.uid,
      ),
      builder: (context, snap) {
        final pred = snap.hasError ? null : snap.data;
        return fromPred(pred);
      },
    );
  }
}

/// Bandeau TON XI pleine largeur — jamais collé sur une seule colonne.
class LineupXiSedanNote extends StatelessWidget {
  final LineupXiVerdict verdict;
  final MatchModel match;

  const LineupXiSedanNote({
    super.key,
    required this.verdict,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    final pts = verdict.rankingPoints;
    final value = verdict.hasPrediction
        ? '${verdict.matched}/11  +$pts pt${pts > 1 ? 's' : ''}'
        : '—';
    return SizedBox(
      width: double.infinity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: MatchDetailTheme.paper(sedan: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PronoXiScoreboard(
              team1: match.team1,
              logo1: match.logo1,
              team2: match.team2,
              logo2: match.logo2,
              kicker: 'TON XI',
              value: value,
            ),
            const SizedBox(height: 10),
            Text(
              verdict.hasPrediction
                  ? '9/11 +1  ·  10/11 +2  ·  11/11 +3'
                  : verdict.body,
              textAlign: TextAlign.center,
              style: MatchDetailType.caption.copyWith(
                color: MatchDetailTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool lineupSedanIsHome(MatchModel match) => isSedanTeam(match.team1);
