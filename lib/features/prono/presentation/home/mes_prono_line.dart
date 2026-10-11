import 'package:flutter/material.dart';

import '../../../../utils/open_prono_for_match.dart';
import '../../domain/my_prono.dart';
import '../../domain/prono_lock.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_predict_stage.dart';

/// Tableau de score : écussons, prono au centre, verdict à droite.
class MesPronoLine extends StatelessWidget {
  final MyPronoItem item;

  const MesPronoLine({super.key, required this.item});

  Color get _verdictColor {
    final p = item.points;
    if (p == null) return PronoArenaTheme.goldDeep;
    if (p >= 3) return PronoArenaTheme.greenBright;
    if (p == 1) return PronoArenaTheme.text;
    return PronoArenaTheme.textSoft;
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PronoClubSide(
                        name: item.team1,
                        logoUrl: item.logo1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _ScoreBlock(item: item),
                    ),
                    Expanded(
                      child: PronoClubSide(
                        name: item.team2,
                        logoUrl: item.logo2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      item.verdictLabel.toUpperCase(),
                      style: PronoType.kicker.copyWith(color: _verdictColor),
                    ),
                    const Spacer(),
                    Text(
                      item.pointsLabel.toUpperCase(),
                      style: item.isPending
                          ? PronoType.kicker.copyWith(
                              color: PronoArenaTheme.goldDeep,
                            )
                          : PronoType.rank.copyWith(
                              fontSize: 16,
                              color: _verdictColor,
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
  }
}

class _ScoreBlock extends StatelessWidget {
  final MyPronoItem item;

  const _ScoreBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TON PRONO', style: PronoType.kickerGoldPaper),
        const SizedBox(height: 2),
        Text(
          pronoScorePair(item.predHome, item.predAway),
          style: PronoType.scoreCompact.copyWith(fontSize: 26),
        ),
        if (item.hasResult) ...[
          const SizedBox(height: 2),
          Text(
            'RÉEL ${pronoScorePair(item.resHome!, item.resAway!)}',
            style: PronoType.kicker,
          ),
        ],
      ],
    );
  }
}
