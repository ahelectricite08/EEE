import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/match_lineup.dart';
import '../../../../models/match_model.dart';
import '../../../../widgets/lineup_prediction_game.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_page_header.dart';
import '../widgets/prono_ui.dart';

/// Même jeu XI que l’onglet Compo de la fiche match, ouvert depuis Pronos.
class PronoXiPlayPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final MatchModel match;

  const PronoXiPlayPage({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return PronoThemeScope(
      pageAccent: _pageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PronoPageHeader.asAppBar(
            context: context,
            title: 'XI probable',
            subtitle: '${match.team1} · ${match.team2}',
            kicker: 'Arène',
            pageAccent: _pageAccent,
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('matches').doc(match.id).snapshots(),
            builder: (context, matchSnap) {
              if (matchSnap.hasError) {
                return const PronoErrorState(
                  title: 'Compo indisponible',
                  body:
                      'Impossible de charger le match. Reviens à l’accueil Pronos.',
                  pageAccent: _pageAccent,
                );
              }
              if (matchSnap.connectionState == ConnectionState.waiting &&
                  !matchSnap.hasData) {
                return const Center(
                  child: PronoLoadingTape(rows: 8),
                );
              }
              final matchDoc = matchSnap.data?.data() ?? {};
              MatchModel liveMatch;
              try {
                liveMatch = matchSnap.data != null && matchSnap.data!.exists
                    ? MatchModel.fromFirestore(matchSnap.data!)
                    : match;
              } catch (_) {
                liveMatch = match;
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: db.collection('match_stats').doc(match.id).snapshots(),
                builder: (context, statsSnap) {
                  final statsData =
                      statsSnap.hasError ? null : statsSnap.data?.data();
                  final lineups =
                      MatchLineups.mergeDocs(matchDoc, statsData);
                  return LineupPredictionGame(
                    match: liveMatch,
                    lineups: lineups,
                    matchDoc: matchDoc,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
