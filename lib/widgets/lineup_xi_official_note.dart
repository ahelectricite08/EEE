import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lineup_prediction.dart';
import '../models/lineup_xi_verdict.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';
import '../screens/matches/matches_helpers.dart';
import '../services/lineup_prediction_service.dart';

/// Charge le XI probable Sedan (s’il existe) pour le verdict post-compo.
class LineupXiOfficialBridge extends StatelessWidget {
  final MatchModel match;
  final MatchLineups lineups;
  final Widget Function(
    BuildContext context,
    LineupXiVerdict verdict,
    Set<String> sedanHits,
  ) builder;

  const LineupXiOfficialBridge({
    super.key,
    required this.match,
    required this.lineups,
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
      );
      final hits = LineupXiVerdict.hitSedanStarterLabels(
        prediction: pred,
        officialSedanStarters: sedanStarters,
      );
      return builder(context, verdict, hits);
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

/// Note compacte **côté Sedan / CSSA seulement** — pas de jugement sur l’adversaire.
class LineupXiSedanNote extends StatelessWidget {
  final LineupXiVerdict verdict;
  final bool sedanIsHome;

  const LineupXiSedanNote({
    super.key,
    required this.verdict,
    required this.sedanIsHome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sedanIsHome ? _card() : const SizedBox.shrink()),
        const SizedBox(width: 8),
        Expanded(child: sedanIsHome ? const SizedBox.shrink() : _card()),
      ],
    );
  }

  Widget _card() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: MatchDetailTheme.paper(sedan: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LineupXiVerdict.kicker,
            style: MatchDetailType.kicker.copyWith(
              color: MatchDetailTheme.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verdict.title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: MatchDetailTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            verdict.body,
            style: MatchDetailType.caption.copyWith(
              color: MatchDetailTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

bool lineupSedanIsHome(MatchModel match) => isSedanTeam(match.team1);
