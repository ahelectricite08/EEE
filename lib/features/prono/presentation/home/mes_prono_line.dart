import 'package:flutter/material.dart';

import '../../domain/my_prono.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';

/// Ligne compacte : domicile **or**, extérieur **gris** — le score posé
/// est collé à chaque équipe (comme sur la feuille de prono).
class MesPronoLine extends StatelessWidget {
  final MyPronoItem item;

  const MesPronoLine({super.key, required this.item});

  Color get _ptsColor {
    final p = item.points;
    if (p == null) return PronoArenaTheme.goldDeep;
    if (p == 3) return PronoArenaTheme.greenBright;
    if (p == 1) return PronoArenaTheme.text;
    return PronoArenaTheme.textSoft;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: item.isPending ? 52 : 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.pointsLabel,
                style: item.isPending
                    ? PronoType.kicker.copyWith(
                        color: PronoArenaTheme.goldDeep,
                        letterSpacing: 0.6,
                      )
                    : PronoType.rank.copyWith(fontSize: 17, color: _ptsColor),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SideRow(
                  name: item.team1,
                  pred: item.predHome,
                  gold: true,
                ),
                const SizedBox(height: 3),
                _SideRow(
                  name: item.team2,
                  pred: item.predAway,
                  gold: false,
                ),
              ],
            ),
          ),
          if (item.hasResult)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '${item.resHome}–${item.resAway}',
                style: PronoType.scoreCompact.copyWith(
                  fontSize: 14,
                  color: PronoArenaTheme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideRow extends StatelessWidget {
  final String name;
  final int pred;
  final bool gold;

  const _SideRow({
    required this.name,
    required this.pred,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final color = gold ? PronoArenaTheme.goldDeep : PronoArenaTheme.textSoft;
    return Row(
      children: [
        Container(
          width: 8,
          height: 2,
          color: gold ? PronoArenaTheme.gold : PronoArenaTheme.hairline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.fixture.copyWith(fontSize: 16, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pred',
          style: PronoType.scoreCompact.copyWith(fontSize: 18, color: color),
        ),
      ],
    );
  }
}
