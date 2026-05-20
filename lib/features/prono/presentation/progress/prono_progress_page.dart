import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/prono_social_service.dart';
import '../../data/firestore_prono_repository.dart';
import '../history/recent_prono_history_page.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';

/// Progression unique : stats classement + XP/niveau (duels inclus via `pronoProfile`).
class PronoProgressPage extends StatelessWidget {
  final String uid;
  final FirestorePronoRepository repo;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenSocial;
  final VoidCallback onOpenGlobalRanking;

  const PronoProgressPage({
    super.key,
    required this.uid,
    required this.repo,
    required this.onOpenMatches,
    required this.onOpenSocial,
    required this.onOpenGlobalRanking,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.pronoConfigStream(),
      builder: (context, cfgSnap) {
        final config = cfgSnap.data?.data();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.userDocStream(uid),
          builder: (context, userSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: repo.watchLeaderboardEntry(uid),
              builder: (context, lbSnap) {
                final merged =
                    PronoSocialService.mergeLeaderboardAndPronoProfileForXp(
                  lbSnap.data?.data(),
                  userSnap.data?.data(),
                );
                final d = merged;
                final points = (d['points'] as num?)?.toInt() ?? 0;
                final exact = (d['exactScores'] as num?)?.toInt() ?? 0;
                final total = (d['totalPredictions'] as num?)?.toInt() ?? 0;
                final duels = (d['duelWins'] as num?)?.toInt() ?? 0;
                final streak = (d['pronoStreak'] as num?)?.toInt() ?? 0;

                final heroSubtitle = total == 0
                    ? 'Pose ton premier prono pour apparaître au classement.'
                    : '$points pts classement · $exact scores exacts · $duels duel${duels > 1 ? 's' : ''} gagné${duels > 1 ? 's' : ''} — même XP / niveau que sur l’accueil.';

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  slivers: [
                    PronoTabHeroSliver.build(
                      context,
                      title: 'Ta progression',
                      subtitle: heroSubtitle,
                    ),
                    PronoTabHeroSliver.sheetLeadInSliver(),
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: onOpenMatches,
                icon: const Icon(Icons.sports_soccer_rounded, size: 22),
                label: Text(
                  'Voir les matchs à pronostiquer',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      PronoTokens.iconAccentColors(PronoIconAccent.matches).$3,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenGlobalRanking,
                icon: const Icon(Icons.leaderboard_rounded, size: 20),
                label: Text(
                  'Classement global (top 50)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PronoTokens.iconAccentColors(
                    PronoIconAccent.ranking,
                  ).$3,
                  side: BorderSide(
                    color: PronoTokens.iconAccentColors(PronoIconAccent.ranking)
                        .$3
                        .withAlpha(140),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecentSeasonPronoHistoryPage(uid: uid),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 20),
                label: Text(
                  'Mes 10 derniers pronos',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PronoTokens.iconAccentColors(
                    PronoIconAccent.schedule,
                  ).$3,
                  side: BorderSide(
                    color: PronoTokens.iconAccentColors(PronoIconAccent.schedule)
                        .$3
                        .withAlpha(140),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _StatGrid(
                cells: [
                  _StatCell(
                    label: 'POINTS',
                    value: '$points',
                    icon: Icons.star_rounded,
                    accent: PronoIconAccent.ranking,
                  ),
                  _StatCell(
                    label: 'PRONOS',
                    value: '$total',
                    icon: Icons.edit_note_rounded,
                    accent: PronoIconAccent.progress,
                  ),
                  _StatCell(
                    label: 'EXACTS',
                    value: '$exact',
                    icon: Icons.bolt_rounded,
                    accent: PronoIconAccent.energy,
                  ),
                  _StatCell(
                    label: 'SÉRIE',
                    value: '$streak',
                    icon: Icons.local_fire_department_rounded,
                    accent: PronoIconAccent.competitive,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Builder(
                builder: (context) {
                  final xp = PronoSocialService.resolvedPronoDisplayXp(
                    mergedLeaderboardStats: d,
                    userDocData: userSnap.data?.data(),
                    config: config,
                  );
                  final level =
                      PronoSocialService.levelFromXp(xp, config: config);
                  final label = PronoSocialService.levelLabelFromXp(xp,
                      config: config);
                  final prog = PronoSocialService.progressInLevel(xp,
                      config: config);
                  final toNext = PronoSocialService.xpToNextLevel(xp,
                      config: config);
                  final nextLabel = toNext == null
                      ? 'Palier max atteint'
                      : '${toNext.round()} XP avant le prochain palier';
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(PronoTokens.radiusLg + 2),
                      color: PronoTokens.surface,
                      border: Border.all(
                        color: PronoTokens.accent.withAlpha(44),
                      ),
                      boxShadow: PronoTokens.cardShadow(context),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niveau $level · $label',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: PronoTokens.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'L’XP cumule pronos, bons résultats, scores exacts et duels — un seul niveau DVCR.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PronoTokens.textMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: prog,
                            minHeight: 9,
                            backgroundColor: PronoTokens.surfaceMuted,
                            color: PronoTokens.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          nextLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: PronoTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              const _PronoProgressSectionTitle(
                icon: Icons.emoji_objects_rounded,
                label: 'Comment ça marche ?',
                accent: PronoIconAccent.energy,
              ),
              const SizedBox(height: 10),
              const _SeasonPointsExplainer(),
              const SizedBox(height: 22),
              const _PronoProgressSectionTitle(
                icon: Icons.explore_rounded,
                label: 'Aller plus loin',
                accent: PronoIconAccent.social,
              ),
              const SizedBox(height: 10),
              _SeasonMoreGrid(onOpenSocial: onOpenSocial),
              const SizedBox(height: 16),
              PronoGamifiedTipCard.xpRules(),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PronoProgressSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final PronoIconAccent accent;

  const _PronoProgressSectionTitle({
    required this.icon,
    required this.label,
    this.accent = PronoIconAccent.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PronoTokens.surfaceMuted.withAlpha(220),
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        border: Border.all(color: PronoTokens.border.withAlpha(130)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: PronoTokens.barStripeColors(active: true),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                PronoTokens.iconBadgeDecoration(radius: 12, accent: accent),
            child: Icon(
              icon,
              size: 18,
              color: PronoTokens.iconAccentColors(accent).$3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: PronoTokens.text,
                height: 1,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonPointsExplainer extends StatelessWidget {
  const _SeasonPointsExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: PronoTokens.panelDecoration(
        context,
        radius: PronoTokens.radiusMd,
      ),
      child: Row(
        children: [
          const Expanded(
            child: _PointMini(
              icon: Icons.star_rounded,
              iconColor: PronoTokens.accentGold,
              title: '3 pts',
              subtitle: 'Score exact',
            ),
          ),
          const SizedBox(
            height: 40,
            child: VerticalDivider(width: 1, color: PronoTokens.border),
          ),
          Expanded(
            child: _PointMini(
              icon: Icons.check_circle_rounded,
              iconColor: PronoTokens.iconAccentColors(PronoIconAccent.matches)
                  .$3,
              title: '1 pt',
              subtitle: 'Bon résultat',
            ),
          ),
          const SizedBox(
            height: 40,
            child: VerticalDivider(width: 1, color: PronoTokens.border),
          ),
          const Expanded(
            child: _PointMini(
              icon: Icons.cancel_rounded,
              iconColor: PronoTokens.danger,
              title: '0 pt',
              subtitle: 'Raté',
            ),
          ),
        ],
      ),
    );
  }
}

class _PointMini extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _PointMini({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: PronoTokens.text,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: PronoTokens.textMuted,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SeasonMoreGrid extends StatelessWidget {
  final VoidCallback onOpenSocial;

  const _SeasonMoreGrid({required this.onOpenSocial});

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      required PronoIconAccent accent,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PronoTokens.surface,
                  PronoTokens.surfaceMuted.withAlpha(200),
                ],
              ),
              border: Border.all(
                color: PronoTokens.accentGold.withAlpha(85),
              ),
              boxShadow: PronoTokens.cardShadow(context),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: PronoTokens.iconAccentColors(accent).$3,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PronoTokens.text,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: PronoTokens.textMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: PronoTokens.iconAccentColors(accent).$3.withAlpha(160),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return tile(
      icon: Icons.groups_rounded,
      title: 'Communauté',
      subtitle: 'Duels, ligues, amis, fil d’activité',
      onTap: onOpenSocial,
      accent: PronoIconAccent.social,
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<_StatCell> cells;

  const _StatGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cells
              .map(
                (e) => SizedBox(
                  width: w,
                  child: e,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final PronoIconAccent accent;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = PronoIconAccent.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PronoTokens.surface,
            PronoTokens.surfaceMuted.withAlpha(195),
          ],
        ),
        border: Border.all(
          color: PronoTokens.accentGold.withAlpha(78),
          width: 1.05,
        ),
        boxShadow: [
          BoxShadow(
            color: PronoTokens.accent.withAlpha(26),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                PronoTokens.iconBadgeDecoration(radius: 12, accent: accent),
            child: Icon(
              icon,
              color: PronoTokens.iconAccentColors(accent).$3,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: PronoTokens.textSoft,
                    letterSpacing: 0.65,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
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
