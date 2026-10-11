import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/lineup_prediction.dart';
import '../../../../models/lineup_xi_verdict.dart';
import '../../../../utils/match_competition.dart';
import '../../../../models/match_lineup.dart';
import '../../../../models/match_model.dart';
import '../../../../models/sedan_squad.dart';
import '../../../../services/lineup_prediction_service.dart';
import '../../../../services/sedan_squad_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_predict_stage.dart';
import '../widgets/prono_ui.dart';
import 'prono_xi_play_page.dart';
import '../../../../widgets/lineup_lock_countdown.dart';

/// XI probable jouable depuis l’Accueil Pronos — sans passer par la fiche match.
class PronoHomeXiPanel extends StatelessWidget {
  final String uid;

  const PronoHomeXiPanel({
    super.key,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        if (!snap.hasData) {
          return const PronoLoadingTape(rows: 2, horizontalPadding: 0);
        }
        final picked = _pickSedanTarget(snap.data!.docs);
        if (picked == null) return const SizedBox.shrink();
        return _XiPlayCard(
          key: ValueKey(picked.match.id),
          uid: uid,
          match: picked.match,
          matchDoc: picked.data,
        );
      },
    );
  }
}

({MatchModel match, Map<String, dynamic> data})? _pickSedanTarget(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  QueryDocumentSnapshot<Map<String, dynamic>>? open;
  QueryDocumentSnapshot<Map<String, dynamic>>? nearest;
  for (final doc in docs) {
    MatchModel match;
    try {
      match = MatchModel.fromFirestore(doc);
    } catch (_) {
      continue;
    }
    if (!LineupPredictionService.isSedanMatch(match)) continue;
    if (!MatchCompetition.isPronoEligible(
      match.competition,
      matchId: match.id,
    )) {
      continue;
    }
    nearest ??= doc;
    final data = doc.data();
    final lineups = MatchLineups.fromDoc(data);
    final locked = LineupPredictionService.isPredictionLockedFromMatchDoc(
      data,
      match: match,
      lineups: lineups,
    );
    if (LineupPredictionService.showsXiProbableGame(lineups, match) &&
        !locked) {
      open = doc;
      break;
    }
  }
  final chosen = open ?? nearest;
  if (chosen == null) return null;
  try {
    return (match: MatchModel.fromFirestore(chosen), data: chosen.data());
  } catch (_) {
    return null;
  }
}

class _XiPlayCard extends StatelessWidget {
  final String uid;
  final MatchModel match;
  final Map<String, dynamic> matchDoc;

  const _XiPlayCard({
    super.key,
    required this.uid,
    required this.match,
    required this.matchDoc,
  });

  MatchLineups get _lineups => MatchLineups.fromDoc(matchDoc);

  bool get _locked => LineupPredictionService.isPredictionLockedFromMatchDoc(
        matchDoc,
        match: match,
        lineups: _lineups,
      );

  void _openGame(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PronoXiPlayPage(match: match),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.data ?? SedanSquad.empty;
        return StreamBuilder<LineupPrediction?>(
          stream: LineupPredictionService.watchUserPrediction(
            match.id,
            uid,
          ),
          builder: (context, predSnap) {
            final pred = predSnap.hasError ? null : predSnap.data;
            final official = LineupPredictionService.hasOfficialSedanLineup(
              _lineups,
              match,
            );
            final locked = _locked || pred?.awarded == true || official;
            final names = pred?.playerNames ?? const <String>[];
            final picked = LineupPredictionService.playersFromPrediction(
              squad,
              pred,
            );
            final sedanStarters = official
                ? (LineupPredictionService.sedanSide(_lineups, match)
                        ?.starters
                        .where((e) => e.trim().isNotEmpty)
                        .toList() ??
                    const <String>[])
                : const <String>[];
            final verdict = official
                ? LineupXiVerdict.resolve(
                    prediction: pred,
                    officialSedanStarters: sedanStarters,
                    squad: squad,
                  )
                : null;
            final scored = official &&
                verdict != null &&
                verdict.hasPrediction;
            final max = LineupPrediction.requiredPlayers;
            final matched = verdict?.matched ?? 0;
            final pts = scored ? verdict.rankingPoints : 0;
            final filled = scored
                ? matched
                : (picked.isNotEmpty ? picked.length : names.length);

            final when =
                '${PronoDateHeader.labelFor(match.date)} · '
                '${DateFormat('HH:mm', 'fr_FR').format(match.date)}';

            final String statusLine;
            final String centerKicker;
            final String centerValue;
            final String? centerSub;
            if (scored) {
              centerKicker = 'TON XI';
              centerValue = '$filled/$max';
              centerSub = '+$pts pt${pts > 1 ? 's' : ''}';
              statusLine = filled == 1
                  ? '$filled/$max joueur · +$pts pt'
                  : '$filled/$max joueurs · +$pts pt${pts > 1 ? 's' : ''}';
            } else if (official) {
              centerKicker = 'OFFICIEL';
              centerValue = '—';
              centerSub = null;
              statusLine = 'Composition officielle publiée.';
            } else if (locked) {
              centerKicker = 'TON XI';
              centerValue = filled > 0 ? '$filled/$max' : '—';
              centerSub = null;
              statusLine = filled >= max
                  ? 'XI verrouillé — ton onze est enregistré.'
                  : 'La composition est verrouillée.';
            } else if (filled >= max) {
              centerKicker = 'TON XI';
              centerValue = '$filled/$max';
              centerSub = null;
              statusLine = 'Tes 11 sont posés — tu peux encore modifier.';
            } else {
              centerKicker = 'TON XI';
              centerValue = filled == 0 ? '—' : '$filled/$max';
              centerSub = null;
              statusLine = filled == 0
                  ? 'Compose les 11 titulaires de Sedan.'
                  : '$filled/$max titulaires posés.';
            }

            return PronoRoomPanel(
              eyebrow: 'XI titulaire Sedan',
              accent: PronoPageAccent.accueil,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(when, style: PronoType.meta),
                  const SizedBox(height: 14),
                  PronoXiScoreboard(
                    team1: match.team1,
                    logo1: match.logo1,
                    team2: match.team2,
                    logo2: match.logo2,
                    kicker: centerKicker,
                    value: centerSub == null
                        ? centerValue
                        : '$centerValue  $centerSub',
                  ),
                  const SizedBox(height: 12),
                  Text(statusLine, style: PronoType.caption),
                  if (!locked) ...[
                    const SizedBox(height: 6),
                    LineupLockCountdown(
                      kickoff: match.date,
                      style: PronoType.caption,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '9/11 +1  ·  10/11 +2  ·  11/11 +3',
                    style: PronoType.kickerGoldPaper,
                  ),
                  if (!locked && !squad.isEmpty) ...[
                    const SizedBox(height: 16),
                    PronoInkCta(
                      label: filled >= max
                          ? 'Modifier mes 11'
                          : 'Composer mes 11',
                      icon: Icons.groups_rounded,
                      onTap: () => _openGame(context),
                    ),
                  ] else if (locked && names.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PronoInkCta(
                      label: 'Voir mon XI',
                      icon: Icons.groups_rounded,
                      onTap: () => _openGame(context),
                    ),
                  ] else if (!locked && squad.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'L’effectif Sedan n’est pas encore en ligne.',
                      style: PronoType.caption,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

