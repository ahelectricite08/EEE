import 'package:flutter/material.dart';

import '../../../../models/lineup_xi_verdict.dart';
import '../../../../models/sedan_squad.dart';
import '../../../../services/sedan_squad_service.dart';
import '../../../../utils/open_prono_for_match.dart';
import '../../../../widgets/xi_player_verdict_list.dart';
import '../../domain/my_compo.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_predict_stage.dart';

/// Ligne compacte (accueil) ou avec terrains (Voir tout).
class MesCompoLine extends StatelessWidget {
  final MyCompoItem item;
  final bool showPitches;

  const MesCompoLine({
    super.key,
    required this.item,
    this.showPitches = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.data ?? SedanSquad.empty;
        final scored = item.isScored;
        final marks = scored && showPitches
            ? item.marks(squad: squad)
            : const <LineupXiPlayerMark>[];
        final verdict = scored ? item.verdict(squad: squad) : null;
        final pts = verdict?.rankingPoints ?? 0;
        final filled = verdict?.matched ?? item.prediction.playerNames.length;

        Color verdictColor;
        if (!scored) {
          verdictColor = PronoArenaTheme.goldDeep;
        } else if (pts >= 3) {
          verdictColor = PronoArenaTheme.greenBright;
        } else if (pts > 0) {
          verdictColor = PronoArenaTheme.text;
        } else {
          verdictColor = PronoArenaTheme.textSoft;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => openPronoForMatch(
              context,
              matchId: item.matchId,
              competition: item.competition,
            ),
            splashColor: PronoPageAccent.accueil.color.withValues(alpha: 0.06),
            highlightColor: PronoPageAccent.accueil.color.withValues(alpha: 0.04),
            child: Ink(
              decoration: PronoArenaTheme.fixtureTape(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                child: Column(
                  children: [
                    PronoXiScoreboard(
                      team1: item.team1,
                      logo1: item.logo1,
                      team2: item.team2,
                      logo2: item.logo2,
                      kicker: scored ? 'TON XI' : 'EN ATT.',
                      value: scored
                          ? '$filled/11  +$pts pt${pts > 1 ? 's' : ''}'
                          : '$filled/11',
                    ),
                    if (showPitches && scored) ...[
                      const SizedBox(height: 12),
                      XiComparePitches(
                        userMarks: marks,
                        crowd: item.crowdXi,
                        officialSedanStarters: item.officialSedanStarters,
                        squad: squad,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (scored
                                    ? (verdict?.scoreCaption ??
                                        '$filled/11 joueurs · +$pts pt')
                                    : 'En attente')
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PronoType.kicker.copyWith(color: verdictColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          scored
                              ? '+$pts pt${pts > 1 ? 's' : ''}'
                              : 'EN ATT.',
                          style: scored
                              ? PronoType.rank.copyWith(
                                  fontSize: 16,
                                  color: verdictColor,
                                )
                              : PronoType.kicker.copyWith(
                                  color: PronoArenaTheme.goldDeep,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
