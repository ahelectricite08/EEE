import 'package:flutter/material.dart';

import '../../../../models/first_scorer_bet.dart';
import '../../../../models/lineup_prediction.dart';
import '../../../../services/first_scorer_bet_service.dart';
import '../../domain/prono_xp_scale.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Blocs présentationnels de la page « Ta progression ».
//
//  PAPIER   → bandeau de saison pleine largeur (le fait marquant, en chiffres).
//  RÉGLURE  → palier XP, barème : filets + gouttière de chiffres, zéro carte.
//
//  L’écran est coiffé d’une photo : elle tient le rôle du bloc sombre, donc
//  aucune dalle d’encre ici.
// ═══════════════════════════════════════════════════════════════════════════

/// PAPIER — bandeau de saison : le total de points en très grand sur l’ivoire,
/// arête or, filet, puis la ligne de comptes.
class PronoSeasonBand extends StatelessWidget {
  final int points;
  final int total;
  final int exact;
  final int duels;

  const PronoSeasonBand({
    super.key,
    required this.points,
    required this.total,
    required this.exact,
    required this.duels,
  });

  String get _tally {
    final pronos = '$total prono${total > 1 ? 's' : ''}';
    final exacts = '$exact score${exact > 1 ? 's' : ''} exact${exact > 1 ? 's' : ''}';
    final wins = '$duels duel${duels > 1 ? 's' : ''} gagné${duels > 1 ? 's' : ''}';
    return '$pronos · $exacts · $wins';
  }

  @override
  Widget build(BuildContext context) {
    final started = total > 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: PronoArenaTheme.surface,
        border: Border(
          left: BorderSide(color: PronoArenaTheme.gold, width: 3),
          top: BorderSide(color: PronoArenaTheme.hairline),
          bottom: BorderSide(color: PronoArenaTheme.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        PronoArenaTheme.gutter,
        22,
        PronoArenaTheme.gutter,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILAN DE SAISON', style: PronoType.kicker),
          const SizedBox(height: 10),
          if (started)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: PronoType.display.copyWith(fontSize: 72),
                ),
                const SizedBox(width: 11),
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Text('POINTS', style: PronoType.kickerGoldPaper),
                ),
              ],
            )
          else
            Text(
              'Pose ton premier prono',
              style: PronoType.headline.copyWith(fontSize: 32),
            ),
          const SizedBox(height: 16),
          Container(height: 1, color: PronoArenaTheme.hairline),
          const SizedBox(height: 14),
          Text(
            started
                ? _tally
                : 'Ton bilan de saison s’affiche ici dès qu’un match est joué.',
            style: PronoType.caption,
          ),
        ],
      ),
    );
  }
}

/// RÉGLURE — palier XP : kicker, ligne de niveau, filet de progression carré.
class PronoSeasonTierBlock extends StatelessWidget {
  final int level;
  final String levelLabel;
  final double progress;
  final String nextLabel;

  const PronoSeasonTierBlock({
    super.key,
    required this.level,
    required this.levelLabel,
    required this.progress,
    required this.nextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PALIER', style: PronoType.kickerGoldPaper),
        const SizedBox(height: 10),
        Text(
          'Niveau $level · $levelLabel',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: PronoType.headline,
        ),
        const SizedBox(height: 16),
        _TierRule(progress: progress),
        const SizedBox(height: 10),
        Text(nextLabel, style: PronoType.meta),
      ],
    );
  }
}

class _TierRule extends StatelessWidget {
  final double progress;

  const _TierRule({required this.progress});

  @override
  Widget build(BuildContext context) {
    final target = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          duration: PronoArenaTheme.animNormal,
          curve: PronoArenaTheme.animCurve,
          tween: Tween<double>(begin: 0, end: target),
          builder: (context, value, _) {
            return Stack(
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  color: PronoArenaTheme.surfaceMuted,
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * value,
                  color: PronoArenaTheme.gold,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// RÉGLURE — le barème complet, en trois sources de points.
///
/// Les valeurs affichées ici sont celles qui font foi côté serveur :
///  · score       → `functions/prono_scoring.js`, `calculatePronoPoints`
///  · XI probable → `_lineupPredPoints` (points) + `_lineupPredXpEvent` (XP)
///  · buteur saison → `resolveBestScorerChallenge`, constante `BONUS`
///  · 1er buteur match → `functions/lib/first_scorer_core.js`
///    (buteur CSSA : +3 pts et +10 XP / adversaire : +1 pt)
///
/// Deux natures de gain, deux colonnes : les points de classement en gouttière,
/// l’XP à droite. Le prono de score, le XI probable et le 1er buteur CSSA
/// alimentent les deux ; le buteur de saison et l’adversaire (1er buteur)
/// ne créditent que le classement.
///
/// La colonne XP est lue sur `app_settings/xp_config` : c’est la seule façon de
/// rester juste si l’administrateur change les valeurs.
class PronoScoringLedger extends StatelessWidget {
  const PronoScoringLedger({super.key});

  @override
  Widget build(BuildContext context) {
    return PronoXpScaleBuilder(builder: _build);
  }

  Widget _build(BuildContext context, PronoXpScale xp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ScoringColumnHeads(),
        const _ScoringChapter(
          index: '01',
          title: 'Ton prono de match',
          note: 'À chaque rencontre.',
        ),
        _ScoringLine(
          points: 3,
          label: 'Score exact',
          trailing: '+${xp.exactScore} XP',
          tone: PronoArenaTheme.greenBright,
        ),
        _ScoringLine(
          points: 1,
          label: 'Bon résultat',
          trailing: '+${xp.goodResult} XP',
          tone: PronoArenaTheme.text,
        ),
        _ScoringLine(
          points: 0,
          label: 'Raté',
          trailing: '+${xp.forPronoPoints(0)} XP',
          tone: PronoArenaTheme.textSoft,
        ),
        const SizedBox(height: 26),
        const _ScoringChapter(
          index: '02',
          title: 'XI probable Sedan',
          note:
              'XI verrouillé 2 j 12 h avant le match — compos souvent la veille.',
        ),
        _ScoringLine(
          points: LineupPrediction.pointsForMatches(11),
          label: '11 bons joueurs',
          trailing: '+${xp.xiPerfect} XP',
          tone: PronoArenaTheme.greenBright,
        ),
        _ScoringLine(
          points: LineupPrediction.pointsForMatches(10),
          label: '10 bons joueurs',
          trailing: '+${xp.xiTen} XP',
          tone: PronoArenaTheme.text,
        ),
        _ScoringLine(
          points: LineupPrediction.pointsForMatches(9),
          label: '9 bons joueurs',
          trailing: '+${xp.xiNine} XP',
          tone: PronoArenaTheme.text,
        ),
        _ScoringLine(
          points: LineupPrediction.pointsForMatches(0),
          label: 'Moins de 9',
          trailing: '+${xp.xiPlayed} XP',
          tone: PronoArenaTheme.textSoft,
        ),
        const SizedBox(height: 26),
        const _ScoringChapter(
          index: '03',
          title: 'Meilleur buteur de la saison',
          note: 'Un seul pronostic, verrouillé dès que tu valides.',
        ),
        const _ScoringLine(
          points: 10,
          label: 'Tu as désigné le bon buteur',
          trailing: 'Pas d’XP',
          tone: PronoArenaTheme.greenBright,
        ),
        const SizedBox(height: 26),
        _FirstScorerLedgerChapter(xp: xp),
        const SizedBox(height: 18),
        const PronoFootnote(
          heading: 'Le départage',
          text:
              'À égalité de points en fin de saison, c’est le nombre de XI '
              'trouvés au complet (11/11) qui départage.',
        ),
      ],
    );
  }
}

/// Chapitre 04 — masqué si le switch admin est OFF.
class _FirstScorerLedgerChapter extends StatelessWidget {
  final PronoXpScale xp;

  const _FirstScorerLedgerChapter({required this.xp});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FirstScorerBetConfig>(
      stream: FirstScorerBetService.instance.watchConfig(),
      initialData: FirstScorerBetService.instance.lastKnown,
      builder: (context, snap) {
        final cfg = snap.data ?? FirstScorerBetConfig.defaults;
        if (!cfg.showInApp) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ScoringChapter(
              index: '04',
              title: '1er buteur du match',
              note:
                  'Matchs Sedan / CSSA seulement. Avant le coup d’envoi. '
                  'Un joueur CSSA ou Adversaire.',
            ),
            _ScoringLine(
              points: FirstScorerBetConfig.sedanHitPoints,
              label: 'Buteur CSSA',
              trailing: '+${xp.firstScorerCssa} XP',
              tone: PronoArenaTheme.greenBright,
            ),
            const _ScoringLine(
              points: FirstScorerBetConfig.opponentHitPoints,
              label: 'Adversaire ouvre le score',
              trailing: 'Pas d’XP',
              tone: PronoArenaTheme.text,
            ),
          ],
        );
      },
    );
  }
}

/// Têtes de colonnes — posées une seule fois, elles rendent les deux natures de
/// gain lisibles d’un coup d’œil sans répéter « points » et « XP » sur chaque
/// ligne.
class _ScoringColumnHeads extends StatelessWidget {
  const _ScoringColumnHeads();

  @override
  Widget build(BuildContext context) {
    final style = PronoType.kicker.copyWith(
      color: PronoArenaTheme.textMuted,
      letterSpacing: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 46, child: Text('PTS', style: style)),
          const Spacer(),
          Text('XP', style: style),
        ],
      ),
    );
  }
}

/// Intertitre de chapitre — numéro en gouttière, comme les lignes qu’il coiffe,
/// pour que l’œil descende sur un seul axe.
class _ScoringChapter extends StatelessWidget {
  final String index;
  final String title;
  final String note;

  const _ScoringChapter({
    required this.index,
    required this.title,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              index,
              style: PronoType.kicker.copyWith(
                color: PronoArenaTheme.goldDeep,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: PronoType.kicker.copyWith(
                    color: PronoArenaTheme.text,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: PronoType.meta.copyWith(
                    color: PronoArenaTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoringLine extends StatelessWidget {
  final int points;
  final String label;
  final String trailing;
  final Color tone;

  const _ScoringLine({
    required this.points,
    required this.label,
    required this.trailing,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '+$points',
              style: PronoType.numeralGutter.copyWith(
                fontSize: 30,
                color: tone,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PronoType.title.copyWith(fontSize: 19),
            ),
          ),
          Text(
            trailing,
            style: PronoType.meta.copyWith(color: PronoArenaTheme.textSoft),
          ),
        ],
      ),
    );
  }
}
