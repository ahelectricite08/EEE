import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/xp_service.dart';
import '../../data/firestore_prono_repository.dart';
import '../history/recent_prono_history_page.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';
import 'prono_season_ledger.dart';

/// « Ta progression » — rapport de saison : masthead photo, bandeau de papier,
/// relevé chiffré, palier XP, barème et annuaire. Aucune carte empilée.
class PronoProgressPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.progression;

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

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecentSeasonPronoHistoryPage(uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: XpService.levelsDocStream(),
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
                    : '$points pts · $exact exacts · $duels duel${duels > 1 ? 's' : ''} gagné${duels > 1 ? 's' : ''}.';

                final hasError = lbSnap.hasError || userSnap.hasError;
                final loading = !hasError &&
                    lbSnap.connectionState == ConnectionState.waiting &&
                    !lbSnap.hasData;

                final xp = XpService.displayXp(userSnap.data?.data());
                final level =
                    PronoSocialService.levelFromXp(xp, config: config);
                final levelLabel =
                    PronoSocialService.levelLabelFromXp(xp, config: config);
                final prog =
                    PronoSocialService.progressInLevel(xp, config: config);
                final toNext =
                    PronoSocialService.xpToNextLevel(xp, config: config);
                final nextLabel = toNext == null
                    ? 'Palier max atteint'
                    : '${toNext.round()} XP avant le prochain palier';

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  slivers: [
                    PronoTabHeroSliver.build(
                      context,
                      title: 'Ta progression',
                      subtitle: heroSubtitle,
                      pageAccent: _pageAccent,
                      bannerSlot: PronoBannerSlot.progress,
                    ),
                    PronoTabHeroSliver.sheetLeadInSliver(),
                    if (hasError)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
                        sliver: const SliverToBoxAdapter(
                          child: PronoErrorState(
                            title: 'Saison indisponible',
                            body:
                                'Impossible de charger ta progression pour le moment. Réessaie dans un instant.',
                            pageAccent: _pageAccent,
                          ),
                        ),
                      )
                    else if (loading)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 22, 20, bottomInset),
                        sliver: const SliverToBoxAdapter(
                          child: PronoLoadingBlock(),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: PronoSeasonBand(
                          points: points,
                          total: total,
                          exact: exact,
                          duels: duels,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 22, 20, bottomInset),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const PronoSectionHeader(
                              title: 'Le relevé',
                              pageAccent: _pageAccent,
                            ),
                            const SizedBox(height: 8),
                            PronoStatLedger(
                              cells: [
                                (label: 'POINTS', value: '$points'),
                                (label: 'PRONOS', value: '$total'),
                                (label: 'EXACTS', value: '$exact'),
                                (label: 'SÉRIE', value: '$streak'),
                              ],
                            ),
                            const SizedBox(height: 30),
                            PronoSeasonTierBlock(
                              level: level,
                              levelLabel: levelLabel,
                              progress: prog,
                              nextLabel: nextLabel,
                            ),
                            const SizedBox(height: 32),
                            const PronoSectionHeader(
                              title: 'Comment ça marche ?',
                              pageAccent: _pageAccent,
                            ),
                            const SizedBox(height: 4),
                            const PronoScoringLedger(),
                            const SizedBox(height: 32),
                            const PronoSectionHeader(
                              title: 'Aller plus loin',
                              pageAccent: _pageAccent,
                            ),
                            const SizedBox(height: 4),
                            PronoNavTile(
                              indexLabel: '01',
                              icon: Icons.sports_soccer_rounded,
                              title: 'Voir les matchs à pronostiquer',
                              subtitle:
                                  'Le calendrier ouvert, match par match.',
                              pageAccent: _pageAccent,
                              onTap: onOpenMatches,
                            ),
                            PronoNavTile(
                              indexLabel: '02',
                              icon: Icons.leaderboard_rounded,
                              title: 'Classement global',
                              subtitle:
                                  'Ta place dans le classement de la saison.',
                              pageAccent: _pageAccent,
                              onTap: onOpenGlobalRanking,
                            ),
                            PronoNavTile(
                              indexLabel: '03',
                              icon: Icons.history_rounded,
                              title: 'Mes 10 derniers pronos',
                              subtitle: 'Le relevé de tes résultats scorés.',
                              pageAccent: _pageAccent,
                              onTap: () => _openHistory(context),
                            ),
                            PronoNavTile(
                              indexLabel: '04',
                              icon: Icons.groups_rounded,
                              title: 'Communauté',
                              subtitle: 'Duels, ligues, amis — sur Accueil.',
                              pageAccent: _pageAccent,
                              onTap: onOpenSocial,
                            ),
                            const SizedBox(height: 26),
                            const PronoFootnote(
                              heading: 'Même barème partout',
                              text:
                                  'Les pronos s’ouvrent en général 7 jours avant le coup d’envoi. '
                                  'Le XI se verrouille 2 j 12 h avant le match '
                                  '(compos souvent la veille). '
                                  'Régularité, bons résultats, scores exacts et duels alimentent le même XP.',
                            ),
                          ]),
                        ),
                      ),
                    ],
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
