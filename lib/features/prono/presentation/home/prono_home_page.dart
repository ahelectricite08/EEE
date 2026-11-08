import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/match_model.dart';
import '../../../../navigation/prono_championship_rollout.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../utils/open_prono_for_match.dart';
import '../../../../widgets/donation_banner.dart';
import '../../data/firestore_prono_repository.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../../domain/my_compo.dart';
import '../../domain/my_prono.dart';
import '../../../../services/lineup_prediction_service.dart';
import '../social/prono_social_hub_page.dart';
import 'mes_compo_line.dart';
import 'mes_compos_full_page.dart';
import 'mes_prono_line.dart';
import 'mes_pronos_full_page.dart';
import 'prono_home_xi_panel.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_predict_stage.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';
import '../../../../widgets/prono_leaderboard_style.dart';
import 'best_scorer_challenge_welcome.dart';

/// Arène Pronos — masthead photo, bandeau de saison, classement, mes pronos.
class PronoHomePage extends StatefulWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final String uid;
  final String displayName;
  final FirestorePronoRepository repo;
  final VoidCallback onOpenGlobalRanking;
  final VoidCallback onOpenMatches;

  const PronoHomePage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.repo,
    required this.onOpenGlobalRanking,
    required this.onOpenMatches,
  });

  @override
  State<PronoHomePage> createState() => _PronoHomePageState();
}

class _PronoHomePageState extends State<PronoHomePage> {
  final ValueNotifier<GlobalLeaderboardView?> _board =
      ValueNotifier<GlobalLeaderboardView?>(null);
  StreamSubscription<GlobalLeaderboardView>? _boardSub;
  bool _boardLoading = true;

  @override
  void initState() {
    super.initState();
    _bindBoard(widget.uid);
  }

  @override
  void didUpdateWidget(covariant PronoHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _bindBoard(widget.uid);
    }
  }

  void _bindBoard(String uid) {
    _boardSub?.cancel();
    _boardLoading = true;
    _boardSub = PronoSocialService.watchGlobalLeaderboardWindow(uid).listen(
      (view) {
        _boardLoading = false;
        _board.value = view;
      },
    );
  }

  @override
  void dispose() {
    _boardSub?.cancel();
    _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final bottomInset = PronoTokens.bottomContentInset(context);

    return CustomScrollView(
      clipBehavior: Clip.hardEdge,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        PronoTabHeroSliver.build(
          context,
          title: 'Arène Pronos',
          subtitle: 'Ta saison, tes scores, ton XI.',
          pageAccent: PronoHomePage._pageAccent,
          bannerSlot: PronoBannerSlot.home,
        ),
        PronoTabHeroSliver.sheetLeadInSliver(),
        SliverToBoxAdapter(
          child: ValueListenableBuilder<GlobalLeaderboardView?>(
            valueListenable: _board,
            builder: (context, board, _) {
              return _SeasonBand(uid: uid, board: board);
            },
          ),
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
              const SizedBox(height: 16),
              PronoSectionHeader(
                title: 'À jouer',
                pageAccent: PronoHomePage._pageAccent,
                action: GestureDetector(
                  onTap: widget.onOpenMatches,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      'Voir tous les matchs',
                      textAlign: TextAlign.right,
                      style: PronoType.kicker.copyWith(
                        color: PronoArenaTheme.goldDeep,
                        fontSize: 9,
                        letterSpacing: 0.35,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _NextScoreToPlay(
                uid: uid,
                repo: widget.repo,
                onOpenMatches: widget.onOpenMatches,
              ),
              const SizedBox(height: 16),
              PronoHomeXiPanel(uid: uid),
              const SizedBox(height: 28),
              _MesPronosSection(uid: uid),
              const SizedBox(height: 28),
              _MesComposSection(uid: uid),
              const SizedBox(height: 28),
              PronoSectionHeader(
                title: 'Classement',
                pageAccent: PronoHomePage._pageAccent,
                action: GestureDetector(
                  onTap: widget.onOpenGlobalRanking,
                  child: Text(
                    'TOUT VOIR',
                    style: PronoType.kicker.copyWith(
                      color: PronoArenaTheme.goldDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<GlobalLeaderboardView?>(
                valueListenable: _board,
                builder: (context, board, _) {
                  return _ClassementPreview(
                    uid: uid,
                    board: board,
                    loading: _boardLoading && board == null,
                    onOpen: widget.onOpenGlobalRanking,
                  );
                },
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            PronoArenaTheme.gutter,
            28,
            PronoArenaTheme.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: PronoSocialHubBody(
              uid: uid,
              displayName: widget.displayName,
              compact: true,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            0,
            20,
            0,
            bottomInset,
          ),
          sliver: const SliverToBoxAdapter(
            child: DonationBanner(slot: SoutenezDvcrBannerSlot.prono),
          ),
        ),
      ],
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

    final podium = view.rows.take(3).toList();
    final me = view.me;
    final myRank = view.myRank;
    final meOnPodium = me != null && podium.any((r) => r.uid == uid);

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PronoLbPodium(
            top: [
              for (final r in podium)
                (
                  rank: r.rank,
                  name: r.displayName,
                  score: '${r.points}',
                  isMe: r.uid == uid,
                  avatarUrl: r.avatarUrl,
                ),
            ],
          ),
          if (view.totalCount > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${view.totalCount} pronostiqueurs',
                textAlign: TextAlign.center,
                style: PronoType.meta,
              ),
            ),
          if (!meOnPodium && me != null && myRank != null) ...[
            const PronoPressRankingZone(label: 'Ta place'),
            PronoPressRankingRow(
              rank: myRank,
              title: me.displayName,
              valueLabel: '${me.points}',
              isMe: true,
              xiCount: me.perfectXiCount,
              avatarUrl: me.avatarUrl,
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
                  'Aucun prono posé. Commence au-dessus, ou va sur Matchs.',
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

// ── Mes compos ──────────────────────────────────────────────────────────────

class _MesComposSection extends StatelessWidget {
  final String uid;

  const _MesComposSection({required this.uid});

  void _openFull(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MesComposFullPage(uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MyCompoItem>>(
      stream: LineupPredictionService.watchMyCompos(uid),
      builder: (context, snap) {
        final items = snap.data ?? const <MyCompoItem>[];
        final latest = items.isEmpty ? null : items.take(2).toList();
        final showMore = items.length > 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PronoSectionHeader(
              title: 'Mes compos',
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
            const SizedBox(height: 10),
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const PronoLoadingTape(rows: 4, horizontalPadding: 0)
            else if (snap.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Impossible de charger tes compos pour le moment.',
                  style: PronoType.caption,
                ),
              )
            else if (latest == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucune compo posée. Compose un XI Sedan au-dessus.',
                  style: PronoType.caption,
                ),
              )
            else ...[
              for (final row in latest) MesCompoLine(item: row),
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

// ── Prochain score à poser ──────────────────────────────────────────────────

class _NextScoreToPlay extends StatelessWidget {
  final String uid;
  final FirestorePronoRepository repo;
  final VoidCallback onOpenMatches;

  const _NextScoreToPlay({
    required this.uid,
    required this.repo,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    if (!PronoChampionshipRollout.isHubVisible) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<PronoMatchListItem>>(
      stream: repo.watchUpcomingMatches(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        if (!snap.hasData) {
          return const PronoLoadingTape(rows: 1, horizontalPadding: 0);
        }
        final rows = snap.data ?? const <PronoMatchListItem>[];
        PronoMatchListItem? playable;
        PronoMatchListItem? inPlay;
        PronoMatchListItem? upcoming;
        for (final m in rows) {
          if (isMatchPronoWindowOpen(m.date)) {
            playable ??= m;
          } else if (isMatchPronoInPlay(
            m.date,
            status: m.status,
            score1: m.score1,
            score2: m.score2,
          )) {
            inPlay ??= m;
          } else if (!isMatchPronoLocked(m.date)) {
            upcoming ??= m;
          }
        }
        final match = playable ?? inPlay ?? upcoming;
        if (match == null) {
          return Text(
            'Pas de match à pronostiquer pour l’instant.',
            style: PronoType.caption,
          );
        }
        final open = isMatchPronoWindowOpen(match.date);
        final live = isMatchPronoInPlay(
          match.date,
          status: match.status,
          score1: match.score1,
          score2: match.score2,
        );
        final when =
            '${PronoDateHeader.labelFor(match.date)} · '
            '${DateFormat('HH:mm', 'fr_FR').format(match.date)}';
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('predictions')
              .doc('${match.id}_$uid')
              .snapshots(),
          builder: (context, predSnap) {
            final data = predSnap.data?.data();
            final hasPred = predSnap.data?.exists == true;
            final p1 = MatchModel.parseScoreField(data?['score1Pred']);
            final p2 = MatchModel.parseScoreField(data?['score2Pred']);
            final shownPred = hasPred && p1 != null && p2 != null;
            final caption = open
                ? (shownPred
                    ? 'Tu peux encore modifier ton prono.'
                    : 'Pronostique le score de ce match.')
                : live
                    ? (shownPred
                        ? 'Match en cours — prono verrouillé.'
                        : 'Match en cours — tu n’as pas posé de score.')
                    : 'Les scores s’ouvrent 7 jours avant le coup d’envoi.';
            final cta = open
                ? (shownPred ? 'Modifier le score' : 'Pronostiquer le score')
                : live
                    ? 'Voir le match'
                    : 'Voir les matchs';
            final kicker = shownPred
                ? 'TON PRONO'
                : (live ? 'EN COURS' : 'À JOUER');
            return PronoRoomPanel(
              eyebrow: 'Score du match',
              accent: PronoPageAccent.matchs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(when, style: PronoType.meta),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: PronoClubSide(
                          name: match.team1,
                          logoUrl: match.logo1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kicker,
                              style: PronoType.kickerGoldPaper,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shownPred
                                  ? pronoScorePair(p1, p2)
                                  : '—',
                              style: PronoType.scoreCompact.copyWith(
                                fontSize: 26,
                              ),
                            ),
                            if (live &&
                                match.score1 != null &&
                                match.score2 != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'LIVE ${pronoScorePair(match.score1!, match.score2!)}',
                                style: PronoType.kicker,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: PronoClubSide(
                          name: match.team2,
                          logoUrl: match.logo2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(caption, style: PronoType.caption),
                  const SizedBox(height: 16),
                  PronoInkCta(
                    label: cta,
                    icon: Icons.sports_soccer_rounded,
                    onTap: open || live
                        ? () => openPronoForMatch(
                              context,
                              matchId: match.id,
                              competition: match.competition,
                            )
                        : onOpenMatches,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
