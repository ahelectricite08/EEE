import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/match_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../screens/match_detail_screen.dart';
import '../theme/prono_tokens.dart';
import 'recent_prono_row.dart';

/// Page dédiée : **10 derniers** pronos championnat scorés (+3 / +1 / +0 + XP).
class RecentSeasonPronoHistoryPage extends StatelessWidget {
  final String uid;

  const RecentSeasonPronoHistoryPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: PronoTokens.scaffoldDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: PronoTokens.text,
          title: Text(
            'Tes 10 derniers pronos',
            style: GoogleFonts.barlowCondensed(
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        body: FutureBuilder<List<RecentPronoRow>>(
          future: PronoSocialService.recentResolvedSeasonPredictions(uid, limit: 10),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: PronoTokens.accent,
                  strokeWidth: 2,
                ),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible de charger l’historique.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: PronoTokens.textMuted),
                  ),
                ),
              );
            }
            final rows = snap.data ?? const <RecentPronoRow>[];
            if (rows.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun prono terminé pour l’instant.\n'
                    'Dès qu’un match est joué et ton score calculé, '
                    'tu le verras ici.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.4,
                      color: PronoTokens.textMuted,
                    ),
                  ),
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Barème : score exact +3 pts (+20 XP), bon 1N2 +1 (+8 XP), raté +0.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PronoTokens.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                for (final r in rows) ...[
                  RecentPronoHistoryCard(
                    row: r,
                    competitionLabel: 'PRONO SAISON',
                    onTap: r.isWorldCup
                        ? null
                        : () async {
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
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Carte type « match prono » : résultat + points + XP (saison ou CDM).
class RecentPronoHistoryCard extends StatelessWidget {
  final RecentPronoRow row;
  final String competitionLabel;
  final VoidCallback? onTap;

  const RecentPronoHistoryCard({
    super.key,
    required this.row,
    required this.competitionLabel,
    this.onTap,
  });

  Color get _stripeColor {
    switch (row.pronoPoints) {
      case 3:
        return PronoTokens.accentGold;
      case 1:
        return PronoTokens.accent;
      default:
        return PronoTokens.textMuted.withValues(alpha: 0.45);
    }
  }

  Color get _pillBg {
    switch (row.pronoPoints) {
      case 3:
        return PronoTokens.accentGold.withValues(alpha: 0.16);
      case 1:
        return PronoTokens.accent.withValues(alpha: 0.14);
      default:
        return Colors.red.withValues(alpha: 0.08);
    }
  }

  Color get _pillFg {
    switch (row.pronoPoints) {
      case 3:
        return const Color(0xFF6B5500);
      case 1:
        return PronoTokens.accent;
      default:
        return const Color(0xFFB71C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resLine = row.resHome != null && row.resAway != null
        ? 'Score final ${row.resHome} — ${row.resAway}'
        : 'Score final (calcul en cours ou non synchronisé)';

    final ink = Material(
      color: PronoTokens.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_stripeColor, _stripeColor.withValues(alpha: 0.65)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PronoTokens.surfaceMuted.withAlpha(180),
                          borderRadius:
                              BorderRadius.circular(PronoTokens.radiusSm),
                        ),
                        child: Text(
                          competitionLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: PronoTokens.accentGold,
                            letterSpacing: 0.85,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${row.team1} — ${row.team2}',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: PronoTokens.text,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ton prono ${row.predHome} — ${row.predAway}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PronoTokens.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resLine,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: PronoTokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _pillBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _pillFg.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${row.outcomeLabel} ${row.outcomePointsLabel}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _pillFg,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: PronoTokens.surfaceMuted.withAlpha(200),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              row.xpGain > 0
                                  ? '+${row.xpGain} XP'
                                  : '+0 XP',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: PronoTokens.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onTap != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Appuie pour ouvrir la fiche match',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: PronoTokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
        border: Border.all(
          color: PronoTokens.cardBorderHighlight(false),
        ),
        boxShadow: PronoTokens.cardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
        child: ink,
      ),
    );
  }
}
