import 'package:flutter/material.dart';

import '../../../../services/match_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../screens/match_detail_screen.dart';
import '../../domain/prono_xp_scale.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_ui.dart';
import 'recent_prono_row.dart';

/// Relevé de saison : les **10 derniers** pronos championnat scorés
/// (+3 / +1 / +0 et l’XP associée), en réglure — une ligne par match.
class RecentSeasonPronoHistoryPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.progression;

  final String uid;

  const RecentSeasonPronoHistoryPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return PronoThemeScope(
      pageAccent: _pageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: PronoArenaTheme.scaffoldTop,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: PronoArenaTheme.text,
            title: Text('Tes 10 derniers pronos', style: PronoType.title),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: PronoArenaTheme.hairline),
            ),
          ),
          body: FutureBuilder<List<RecentPronoRow>>(
            future: PronoSocialService.recentResolvedSeasonPredictions(
              uid,
              limit: 10,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: PronoLoadingTape(rows: 6),
                );
              }
              if (snap.hasError) {
                return const PronoErrorState(
                  title: 'Relevé indisponible',
                  body:
                      'Impossible de charger ton historique pour le moment. Réessaie dans un instant.',
                  pageAccent: _pageAccent,
                );
              }
              final rows = snap.data ?? const <RecentPronoRow>[];
              if (rows.isEmpty) {
                return const PronoEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Aucun prono terminé',
                  body:
                      'Dès qu’un match est joué et ton score calculé, tu le verras ici.',
                  pageAccent: _pageAccent,
                );
              }
              return PronoXpScaleBuilder(
                builder: (context, xp) => ListView(
                  padding: EdgeInsets.fromLTRB(
                    PronoArenaTheme.gutter,
                    10,
                    PronoArenaTheme.gutter,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    PronoSectionHeader(
                      title: 'Relevé de saison',
                      pageAccent: _pageAccent,
                      countLabel:
                          '${rows.length} match${rows.length > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 2),
                    for (final r in rows)
                      RecentPronoHistoryCard(
                        row: r,
                        xpScale: xp,
                        competitionLabel: 'PRONO SAISON',
                        onTap: () async {
                          final m = await MatchService.byId(r.matchId);
                          if (!context.mounted || m == null) return;
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MatchDetailScreen(match: m),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 22),
                    PronoFootnote(
                      heading: 'Barème',
                      text: 'Score exact +3 pts (+${xp.exactScore} XP), '
                          'bon 1N2 +1 pt (+${xp.goodResult} XP), raté +0.',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ligne de relevé : chiffre de points en gouttière, affiche au centre,
/// prono et score final en blocs tabulaires à droite. Pas une carte.
class RecentPronoHistoryCard extends StatelessWidget {
  final RecentPronoRow row;
  final PronoXpScale xpScale;
  final String competitionLabel;
  final VoidCallback? onTap;

  const RecentPronoHistoryCard({
    super.key,
    required this.row,
    required this.xpScale,
    required this.competitionLabel,
    this.onTap,
  });

  /// Gouttière : réussi / correct / manqué.
  Color get _gutterTone => switch (row.pronoPoints) {
        3 => PronoArenaTheme.greenBright,
        1 => PronoArenaTheme.text,
        _ => PronoArenaTheme.textSoft,
      };

  Color get _outcomeTone => switch (row.pronoPoints) {
        3 => PronoArenaTheme.greenBright,
        1 => PronoArenaTheme.textMuted,
        _ => PronoArenaTheme.red,
      };

  String get _gutterLabel =>
      row.pronoPoints > 0 ? row.outcomePointsLabel : '0';

  @override
  Widget build(BuildContext context) {
    final resolved = row.resHome != null && row.resAway != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: PronoArenaTheme.gold.withValues(alpha: 0.06),
        highlightColor: PronoArenaTheme.gold.withValues(alpha: 0.04),
        child: Ink(
          decoration: PronoArenaTheme.fixtureTape(),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 46,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: _gutterTone),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _gutterLabel,
                            style: PronoType.numeralGutter.copyWith(
                              fontSize: 30,
                              color: _gutterTone,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${row.team1} — ${row.team2}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PronoType.fixture,
                        ),
                        const SizedBox(height: 5),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: row.outcomeLabel,
                                style: PronoType.meta.copyWith(
                                  color: _outcomeTone,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              TextSpan(
                                text: ' · ',
                                style: PronoType.meta.copyWith(
                                  color: PronoArenaTheme.textSoft,
                                ),
                              ),
                              TextSpan(
                                text: '+${row.xpGain(xpScale)} XP',
                                style: PronoType.meta.copyWith(
                                  color: PronoArenaTheme.goldDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!resolved) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Score final : calcul en cours ou non synchronisé.',
                            style: PronoType.meta.copyWith(
                              color: PronoArenaTheme.textSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScoreStamp(
                        label: 'TON PRONO',
                        value: '${row.predHome}–${row.predAway}',
                      ),
                      if (resolved) ...[
                        const SizedBox(width: 14),
                        _ScoreStamp(
                          label: 'FINAL',
                          value: '${row.resHome}–${row.resAway}',
                          tone: _gutterTone,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreStamp extends StatelessWidget {
  final String label;
  final String value;
  final Color? tone;

  const _ScoreStamp({required this.label, required this.value, this.tone});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: PronoType.kicker.copyWith(
            fontSize: 9,
            letterSpacing: 1.1,
            color: PronoArenaTheme.textSoft,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: PronoType.scoreCompact.copyWith(
            fontSize: 18,
            color: tone ?? PronoArenaTheme.text,
          ),
        ),
      ],
    );
  }
}
