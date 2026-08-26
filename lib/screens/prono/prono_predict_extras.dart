import 'package:flutter/material.dart';

import '../../features/prono/presentation/theme/prono_theme.dart';
import '../../features/prono/presentation/theme/prono_type.dart';
import '../../services/match_prono_stats_service.dart';

/// Pourcentages entiers qui somment à 100 (méthode des plus grands restes).
List<int> _pctsSum100(List<int> counts, int total) {
  if (total <= 0 || counts.isEmpty) {
    return List<int>.filled(counts.length, 0);
  }
  final raw = counts.map((c) => (c * 100) / total).toList(growable: false);
  final floors = raw.map((x) => x.floor()).toList();
  var rem = 100 - floors.fold<int>(0, (a, b) => a + b);
  if (rem <= 0) return floors;
  final order = List<int>.generate(counts.length, (i) => i)
    ..sort((a, b) {
      final fa = raw[a] - floors[a];
      final fb = raw[b] - floors[b];
      return fb.compareTo(fa);
    });
  for (var i = 0; i < rem && i < order.length; i++) {
    floors[order[i]]++;
  }
  return floors;
}

const Color _drawTone = Color(0xFFC4BDAE);

/// Barre 1 / N / 2 — `homeWin` → équipe 1, `awayWin` → équipe 2.
///
/// Lecture éditoriale : un filet en trois segments, les pourcentages en
/// chiffres condensés sous chaque segment. Tant qu’aucun prono n’est posé,
/// aucun pourcentage n’est affiché (pas de 100/0 fantôme).
class PronoOutcomeCommunityBar extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;

  const PronoOutcomeCommunityBar({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
  });

  String _short(String name) {
    final t = name.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 12) return t;
    return '${t.substring(0, 11)}…';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: MatchPronoStatsService.outcomeStream(matchId),
      builder: (context, snap) {
        final m = snap.data ??
            const {'homeWin': 0, 'draw': 0, 'awayWin': 0, 'total': 0};
        final h = m['homeWin'] ?? 0;
        final d = m['draw'] ?? 0;
        final a = m['awayWin'] ?? 0;
        final t = m['total'] ?? 0;
        final empty = t <= 0 || (h + d + a) <= 0;
        final pcts = empty ? const [0, 0, 0] : _pctsSum100([h, d, a], t);
        final p1 = pcts[0];
        final pn = pcts[1];
        final p2 = pcts[2];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 16, height: 3, color: PronoArenaTheme.gold),
                const SizedBox(width: 10),
                Text(
                  'TENDANCE DU VESTIAIRE',
                  style: PronoType.kicker.copyWith(color: PronoArenaTheme.text),
                ),
                const Spacer(),
                if (!empty)
                  Text(
                    t > 1 ? '$t pronos' : '$t prono',
                    style: PronoType.meta,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 10,
              child: empty
                  ? const ColoredBox(color: PronoArenaTheme.surfaceMuted)
                  : LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        Widget seg(int pct, Color color) {
                          if (pct <= 0) return const SizedBox.shrink();
                          return SizedBox(
                            width: (w * pct / 100).clamp(0, w),
                            child: ColoredBox(color: color),
                          );
                        }

                        return Row(
                          children: [
                            seg(p1, PronoArenaTheme.greenBright),
                            seg(pn, _drawTone),
                            seg(p2, PronoArenaTheme.red),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            if (empty)
              Text(
                'Personne n’a encore parlé. Sois le premier à poser ton score.',
                style: PronoType.caption,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TendencyReading(
                      pct: p1,
                      label: _short(team1),
                      color: PronoArenaTheme.greenBright,
                      align: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    child: _TendencyReading(
                      pct: pn,
                      label: 'Nul',
                      color: PronoArenaTheme.textMuted,
                      align: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: _TendencyReading(
                      pct: p2,
                      label: _short(team2),
                      color: PronoArenaTheme.red,
                      align: TextAlign.right,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TendencyReading extends StatelessWidget {
  final int pct;
  final String label;
  final Color color;
  final TextAlign align;

  const _TendencyReading({
    required this.pct,
    required this.label,
    required this.color,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final cross = switch (align) {
      TextAlign.right => CrossAxisAlignment.end,
      TextAlign.center => CrossAxisAlignment.center,
      _ => CrossAxisAlignment.start,
    };
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          '$pct%',
          textAlign: align,
          style: PronoType.scoreCompact.copyWith(fontSize: 21, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: PronoType.meta,
        ),
      ],
    );
  }
}

/// Raccourcis 1 / N / 2 — clés de bulletin, encre quand la clé est retenue.
class Prono1x2QuickPicks extends StatelessWidget {
  final void Function(int s1, int s2) onPick;
  final int score1;
  final int score2;

  const Prono1x2QuickPicks({
    super.key,
    required this.onPick,
    this.score1 = -1,
    this.score2 = -1,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String code, String score, int s1, int s2) {
      final selected = score1 == s1 && score2 == s2;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onPick(s1, s2),
            child: AnimatedContainer(
              duration: PronoArenaTheme.animFast,
              curve: PronoArenaTheme.animCurve,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? PronoArenaTheme.ink
                    : PronoArenaTheme.surface,
                border: Border.all(
                  color: selected
                      ? PronoArenaTheme.ink
                      : PronoArenaTheme.border,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    style: PronoType.title.copyWith(
                      fontSize: 24,
                      color: selected ? Colors.white : PronoArenaTheme.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    score,
                    style: PronoType.meta.copyWith(
                      fontSize: 10,
                      color: selected
                          ? PronoArenaTheme.gold
                          : PronoArenaTheme.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        key('1', '1-0', 1, 0),
        const SizedBox(width: 8),
        key('N', '1-1', 1, 1),
        const SizedBox(width: 8),
        key('2', '0-1', 0, 1),
      ],
    );
  }
}
