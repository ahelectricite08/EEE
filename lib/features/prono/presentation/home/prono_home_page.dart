import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/lineup_prediction.dart';
import '../../../../navigation/prono_championship_rollout.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/feature_flags_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../widgets/donation_banner.dart';
import '../../domain/my_prono.dart';
import '../social/prono_social_hub_page.dart';
import 'mes_prono_line.dart';
import 'mes_pronos_full_page.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';
import 'best_scorer_challenge_welcome.dart';

/// Arène Pronos — masthead photo, bandeau de saison, classement, mes pronos.
class PronoHomePage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final String uid;
  final String displayName;
  final VoidCallback onOpenGlobalRanking;

  const PronoHomePage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.onOpenGlobalRanking,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    return StreamBuilder<GlobalLeaderboardView>(
      stream: PronoSocialService.watchGlobalLeaderboardWindow(uid),
      builder: (context, boardSnap) {
        final board = boardSnap.data;
        return CustomScrollView(
          clipBehavior: Clip.hardEdge,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            PronoTabHeroSliver.build(
              context,
              title: 'Arène Pronos',
              subtitle: 'Salut $displayName — matchs, points, duels et potes.',
              pageAccent: _pageAccent,
              bannerSlot: PronoBannerSlot.home,
            ),
            PronoTabHeroSliver.sheetLeadInSliver(),
            SliverToBoxAdapter(
              child: _SeasonBand(uid: uid, board: board),
            ),
            const SliverToBoxAdapter(
              child: DonationBanner(slot: SoutenezDvcrBannerSlot.prono),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PronoArenaTheme.gutter,
                18,
                PronoArenaTheme.gutter,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  BestScorerChallengeHomeChip(uid: uid),
                  ListenableBuilder(
                    listenable: FeatureFlagsService.notifier,
                    builder: (context, _) {
                      if (!PronoChampionshipRollout.isHubVisible) {
                        return const SizedBox.shrink();
                      }
                      return const Column(
                        children: [
                          SizedBox(height: 16),
                          _LineupPredictionPanel(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  PronoSectionHeader(
                    title: 'Classement',
                    pageAccent: _pageAccent,
                    action: GestureDetector(
                      onTap: onOpenGlobalRanking,
                      child: Text(
                        'TOUT VOIR',
                        style: PronoType.kicker.copyWith(
                          color: PronoArenaTheme.goldDeep,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ClassementPreview(
                    uid: uid,
                    board: board,
                    loading:
                        boardSnap.connectionState == ConnectionState.waiting &&
                            !boardSnap.hasData,
                    onOpen: onOpenGlobalRanking,
                  ),
                  PronoMyLeaguesShortcut(
                    uid: uid,
                    pageAccent: PronoPageAccent.social,
                    padding: const EdgeInsets.only(top: 22),
                  ),
                  const SizedBox(height: 28),
                  _MesPronosSection(uid: uid),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                PronoArenaTheme.gutter,
                30,
                PronoArenaTheme.gutter,
                bottomInset,
              ),
              sliver: SliverToBoxAdapter(
                child: PronoSocialHubBody(
                  uid: uid,
                  displayName: displayName,
                  showTip: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Bandeau joueur ──────────────────────────────────────────────────────────

/// « Ta saison » — place + points + XP, en papier sous la photo.
class _SeasonBand extends StatelessWidget {
  final String uid;
  final GlobalLeaderboardView? board;

  const _SeasonBand({required this.uid, this.board});

  @override
  Widget build(BuildContext context) {
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
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: XpService.levelsDocStream(),
        builder: (context, cfgSnap) {
          final config = cfgSnap.data?.data();
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(uid),
            builder: (context, userSnap) {
              final xp = XpService.displayXp(userSnap.data?.data());
              final level = PronoSocialService.levelFromXp(xp, config: config);
              final levelLabel = PronoSocialService.levelLabelFromXp(
                xp,
                config: config,
              );
              final palierName = levelLabel.trim().isEmpty
                  ? 'Niveau $level'
                  : levelLabel.trim();
              final prog = PronoSocialService.progressInLevel(
                xp,
                config: config,
              );
              final toNext = PronoSocialService.xpToNextLevel(
                xp,
                config: config,
              );
              final xpLabel = toNext == null
                  ? 'Palier max · $palierName'
                  : 'Niv. $level · ${toNext.round()} XP vers le suivant';

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.leaderboardEntryStream(uid),
                builder: (context, entrySnap) {
                  final me = board?.me;
                  final rank = board?.myRank;
                  final total = board?.totalCount ?? 0;
                  final d = entrySnap.data?.data() ?? const <String, dynamic>{};
                  final streakVal = (d['pronoStreak'] as num?)?.toInt() ?? 0;
                  final ptsVal =
                      me?.points ?? (d['points'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PronoArenaTheme.gutter,
                      20,
                      PronoArenaTheme.gutter,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TA SAISON',
                              style: PronoType.kicker,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                palierName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: PronoType.kickerGoldPaper,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rank == null ? '—' : frenchRankLabel(rank),
                                    style: PronoType.display.copyWith(
                                      fontSize: 56,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rank == null
                                        ? 'Pas encore classé'
                                        : (total > 0
                                            ? 'sur $total'
                                            : 'au classement'),
                                    style: PronoType.meta,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$ptsVal',
                                      style: PronoType.display.copyWith(
                                        fontSize: 56,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      child: Text(
                                        'PTS',
                                        style: PronoType.kickerGoldPaper,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  streakVal > 0
                                      ? '$streakVal matchs de série'
                                      : 'Série à lancer',
                                  style: PronoType.meta.copyWith(
                                    color: PronoArenaTheme.textSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _XpRule(progress: prog),
                        const SizedBox(height: 9),
                        Text(
                          xpLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PronoType.meta,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Réglure d’XP — un filet qui se remplit en or, pas une pilule Material.
class _XpRule extends StatelessWidget {
  final double progress;

  const _XpRule({required this.progress});

  @override
  Widget build(BuildContext context) {
    final target = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: PronoArenaTheme.animSlow,
          curve: PronoArenaTheme.animCurve,
          builder: (context, value, _) {
            return Stack(
              children: [
                Container(
                  height: 4,
                  width: maxW,
                  color: PronoArenaTheme.surfaceMuted,
                ),
                Container(
                  height: 4,
                  width: maxW * value,
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

// ── Classement compact ──────────────────────────────────────────────────────

class _ClassementPreview extends StatelessWidget {
  final String uid;
  final GlobalLeaderboardView? board;
  final bool loading;
  final VoidCallback onOpen;

  const _ClassementPreview({
    required this.uid,
    required this.board,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PronoLoadingTape(rows: 3, horizontalPadding: 0);
    }
    final view = board;
    if (view == null || view.rows.isEmpty) {
      return GestureDetector(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Pose un prono pour entrer au classement.',
            style: PronoType.caption,
          ),
        ),
      );
    }

    final top = view.rows.take(5).toList();
    final me = view.me;
    final myRank = view.myRank;
    final meInTop = me != null && top.any((r) => r.uid == uid);

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PronoPressRankingHeader(nameLabel: 'Pronostiqueur'),
          for (final r in top)
            PronoPressRankingRow(
              rank: r.rank,
              title: r.displayName,
              valueLabel: '${r.points}',
              isMe: r.uid == uid,
              xiCount: r.perfectXiCount,
            ),
          if (!meInTop && me != null && myRank != null) ...[
            const PronoPressRankingZone(label: 'Ta place'),
            PronoPressRankingRow(
              rank: myRank,
              title: me.displayName,
              valueLabel: '${me.points}',
              isMe: true,
              xiCount: me.perfectXiCount,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mes pronos ──────────────────────────────────────────────────────────────

class _MesPronosSection extends StatelessWidget {
  final String uid;

  const _MesPronosSection({required this.uid});

  void _openFull(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MesPronosFullPage(uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MyPronoItem>>(
      stream: PronoSocialService.watchMyRecentPredictions(uid, limit: 50),
      builder: (context, snap) {
        final items = snap.data ?? const <MyPronoItem>[];
        final dateLabel = (DateTime d) => PronoDateHeader.labelFor(d);
        final latest = latestPlayedMyPronoJournee(
          items,
          dateLabel: dateLabel,
        );
        final showMore = hasOlderMyPronoJournees(
          items,
          dateLabel: dateLabel,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PronoSectionHeader(
              title: 'Mes pronos',
              pageAccent: PronoPageAccent.accueil,
              action: showMore
                  ? GestureDetector(
                      onTap: () => _openFull(context),
                      child: Text(
                        'VOIR PLUS',
                        style: PronoType.kicker.copyWith(
                          color: PronoArenaTheme.goldDeep,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              'Or = domicile  ·  Gris = extérieur  — le chiffre à droite, c’est ton prono.',
              style: PronoType.caption,
            ),
            const SizedBox(height: 10),
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const PronoLoadingTape(rows: 6, horizontalPadding: 0)
            else if (snap.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Impossible de charger tes pronos pour le moment.',
                  style: PronoType.caption,
                ),
              )
            else if (latest == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucun prono posé. Va sur Match pour jouer.',
                  style: PronoType.caption,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  latest.label.toUpperCase(),
                  style: PronoType.kicker,
                ),
              ),
              for (final row in latest.items) MesPronoLine(item: row),
              if (showMore) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openFull(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'VOIR PLUS',
                      textAlign: TextAlign.center,
                      style: PronoType.kicker.copyWith(
                        color: PronoArenaTheme.goldDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

// ── Vestiaire · XI probable ─────────────────────────────────────────────────

class _LineupPredictionPanel extends StatelessWidget {
  const _LineupPredictionPanel();

  @override
  Widget build(BuildContext context) {
    return PronoRoomPanel(
      eyebrow: 'XI probable Sedan',
      accent: PronoPageAccent.accueil,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devine les 11 titulaires',
            style: PronoType.headline.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Fiche du match → onglet Composition. Tu choisis 11 joueurs de '
            'l’effectif, les points tombent avec la compo officielle. '
            'XI verrouillé ${LineupPrediction.lockWindowLabel} — '
            '${LineupPrediction.lockReasonLabel}',
            style: PronoType.caption,
          ),
          const SizedBox(height: 16),
          Text('BARÈME', style: PronoType.kickerGoldPaper),
          const SizedBox(height: 10),
          const PronoStatLedger(
            valueColor: PronoArenaTheme.goldDeep,
            cells: [
              (label: '9 sur 11', value: '+1'),
              (label: '10 sur 11', value: '+2'),
              (label: '11 sur 11', value: '+3'),
            ],
          ),
          const SizedBox(height: 10),
          PronoXpScaleBuilder(
            builder: (context, xp) => Text(
              'Points de classement. Ton XI rapporte aussi de l’XP : '
              '+${xp.xiNine}, +${xp.xiTen} ou +${xp.xiPerfect} XP — et '
              '+${xp.xiPlayed} XP rien que pour avoir joué.',
              style: PronoType.meta.copyWith(color: PronoArenaTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
