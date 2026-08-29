import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/lineup_prediction.dart';
import '../../../../navigation/prono_championship_rollout.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/feature_flags_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../utils/open_prono_for_match.dart';
import '../../data/firestore_prono_repository.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../social/prono_social_hub_page.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';
import 'best_scorer_challenge_welcome.dart';

/// Arène Pronos — masthead photo, bandeau de saison en papier, puis réglures.
class PronoHomePage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final String uid;
  final String displayName;
  final FirestorePronoRepository repo;
  final VoidCallback onOpenMatches;

  const PronoHomePage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.repo,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
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
          subtitle: 'Salut $displayName — matchs, points, duels et potes.',
          pageAccent: _pageAccent,
          bannerSlot: PronoBannerSlot.home,
        ),
        PronoTabHeroSliver.sheetLeadInSliver(),
        // Relevé de saison : bord à bord sous la photo, en papier — la photo
        // tient déjà le rôle du bloc sombre de l'écran.
        SliverToBoxAdapter(
          child: _SeasonBand(uid: uid, onOpenMatches: onOpenMatches),
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
              const PronoSectionHeader(
                title: 'Prochains matchs',
                pageAccent: _pageAccent,
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: _NextMatchesStrip(repo: repo, uid: uid),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            PronoArenaTheme.gutter,
            30,
            PronoArenaTheme.gutter,
            bottomInset,
          ),
          sliver: SliverToBoxAdapter(
            // Multijoueur / Social — contenu principal Accueil (sans tip Communauté).
            child: PronoSocialHubBody(
              uid: uid,
              displayName: displayName,
              showTip: false,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bandeau joueur ──────────────────────────────────────────────────────────

/// « Ta saison » — plaque de papier pleine largeur : les points, le palier,
/// l’action.
///
/// L’écran est coiffé d’une photo : la dalle d’encre de l’écran est déjà
/// dépensée là-haut. Le relevé se tient donc en ivoire, avec un filet or en
/// arête, des gouttières et un chiffre de points imposant — c’est la taille
/// du nombre, pas un aplat sombre, qui fait le poids du bloc.
class _SeasonBand extends StatelessWidget {
  final String uid;
  final VoidCallback onOpenMatches;

  const _SeasonBand({required this.uid, required this.onOpenMatches});

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
              final prog = PronoSocialService.progressInLevel(
                xp,
                config: config,
              );
              final toNext = PronoSocialService.xpToNextLevel(
                xp,
                config: config,
              );
              final xpLabel = toNext == null
                  ? 'Palier max atteint'
                  : '${toNext.round()} XP restants';

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.leaderboardEntryStream(uid),
                builder: (context, boardSnap) {
                  final d =
                      boardSnap.data?.data() ?? const <String, dynamic>{};
                  final pts = (d['points'] as num?)?.toInt() ?? 0;
                  final streak = (d['pronoStreak'] as num?)?.toInt() ?? 0;

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
                            Expanded(
                              child: Text('TA SAISON', style: PronoType.kicker),
                            ),
                            Text('Niveau $level', style: PronoType.meta),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$pts',
                              style: PronoType.display.copyWith(fontSize: 68),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child:
                                  Text('PTS', style: PronoType.kickerGoldPaper),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _XpRule(progress: prog),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                xpLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PronoType.meta,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              streak > 0
                                  ? '$streak matchs de série'
                                  : 'Série à lancer',
                              style: PronoType.meta.copyWith(
                                color: PronoArenaTheme.textSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Contrôle, donc encre permise — mais borné en
                        // largeur : une bande sombre pleine largeur ferait
                        // de nouveau bloc sous la photo.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 244),
                          child: PronoInkCta(
                            label: 'Voir les matchs',
                            icon: Icons.sports_soccer_rounded,
                            onTap: onOpenMatches,
                          ),
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
    // FractionallySizedBox inside Align gets unbounded width in this Column.
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

// ── Vestiaire · XI probable ─────────────────────────────────────────────────

/// Encart d’aide — jeu « XI probable » Sedan (composition avant match).
///
/// Même barème, même langage de chiffres que le tableau d’affichage du jeu
/// dans la fiche match : l’encart annonce, le jeu exécute.
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

// ── Prochains matchs ────────────────────────────────────────────────────────

class _NextMatchesStrip extends StatelessWidget {
  final FirestorePronoRepository repo;
  final String uid;

  static const double _height = 156;

  const _NextMatchesStrip({required this.repo, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repo.watchUpcomingMatches(limit: 40),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: _height, child: _GhostTickets());
        }
        final raw = snap.data ?? const [];
        final now = DateTime.now();
        final upcoming =
            raw.where((m) => m.date.isAfter(now)).toList(growable: false);
        if (upcoming.isEmpty) {
          return const _StripEmpty();
        }
        final inWindow = upcoming.where((m) {
          final days = m.date.difference(now).inDays;
          return days <= 7;
        }).take(8);
        final toShow = inWindow.isNotEmpty ? inWindow : upcoming.take(5);

        return SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: PronoArenaTheme.gutter,
            ),
            itemCount: toShow.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              final m = toShow.elementAt(i);
              final daysLeft = m.date.difference(now).inDays;
              final locked = !now.isBefore(m.date);
              final tooEarly = !locked && daysLeft > 7;
              final canProno = !locked && !tooEarly;
              return _MatchTicket(
                repo: repo,
                uid: uid,
                match: m,
                canProno: canProno,
                tooEarly: tooEarly,
              );
            },
          ),
        );
      },
    );
  }
}

/// Billet de match — papier fileté, date en tête, affiche au centre, verdict
/// en pied. Le seul reste d’encre est le tampon d’action : c’est un contrôle.
class _MatchTicket extends StatelessWidget {
  final FirestorePronoRepository repo;
  final String uid;
  final PronoMatchListItem match;
  final bool canProno;
  final bool tooEarly;

  static const double _width = 178;

  const _MatchTicket({
    required this.repo,
    required this.uid,
    required this.match,
    required this.canProno,
    required this.tooEarly,
  });

  static int? _predScore(Map<String, dynamic>? d, String k) {
    if (d == null) return null;
    final v = d[k];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE d MMM', 'fr_FR').format(match.date);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.watchPredictionDoc(match.id, uid),
      builder: (context, predSnap) {
        final hasPred = predSnap.hasData && (predSnap.data?.exists ?? false);
        final pd = predSnap.data?.data();
        final ps1 = _predScore(pd, 'score1Pred');
        final ps2 = _predScore(pd, 'score2Pred');
        final showScore = hasPred && ps1 != null && ps2 != null;
        final ctaLabel = !canProno
            ? (tooEarly ? 'Bientôt' : 'Fermé')
            : (hasPred ? 'Modifier' : 'Jouer');

        return _TicketPressable(
          canProno: canProno,
          onTap: () {
            if (canProno) {
              openPronoForMatch(context, matchId: match.id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tooEarly
                        ? 'Les pronos ouvrent 7 jours avant le coup d’envoi.'
                        : 'Fenêtre de prono fermée pour ce match.',
                    style: PronoType.body.copyWith(
                      color: PronoArenaTheme.onInk,
                    ),
                  ),
                  backgroundColor: PronoArenaTheme.ink,
                ),
              );
            }
          },
          child: Container(
            width: _width,
            height: _NextMatchesStrip._height,
            decoration: PronoArenaTheme.ticketPaper(),
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.kicker,
                ),
                const SizedBox(height: 13),
                Text(
                  match.team1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.fixture.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  match.team2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.fixture.copyWith(
                    color: PronoArenaTheme.textMuted,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                Container(height: 1, color: PronoArenaTheme.hairline),
                const SizedBox(height: 10),
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showScore
                        ? Text(
                            '$ps1–$ps2',
                            maxLines: 1,
                            style: PronoType.scoreCompact.copyWith(
                              color: PronoArenaTheme.goldDeep,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            color: canProno
                                ? PronoArenaTheme.ink
                                : PronoArenaTheme.surfaceMuted,
                            child: Text(
                              ctaLabel.toUpperCase(),
                              style: PronoType.kicker.copyWith(
                                letterSpacing: 1.1,
                                color: canProno
                                    ? PronoArenaTheme.onInk
                                    : PronoArenaTheme.textSoft,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketPressable extends StatefulWidget {
  final bool canProno;
  final VoidCallback onTap;
  final Widget child;

  const _TicketPressable({
    required this.canProno,
    required this.onTap,
    required this.child,
  });

  @override
  State<_TicketPressable> createState() => _TicketPressableState();
}

class _TicketPressableState extends State<_TicketPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.canProno ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.canProno ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.canProno ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: PronoArenaTheme.animFast,
        curve: PronoArenaTheme.animCurve,
        child: widget.child,
      ),
    );
  }
}

/// Billets fantômes — le chargement garde la forme du contenu, pas un spinner.
class _GhostTickets extends StatelessWidget {
  const _GhostTickets();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: PronoArenaTheme.gutter),
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Opacity(
            opacity: 1 - (i * 0.28),
            child: Container(
              width: _MatchTicket._width,
              decoration: PronoArenaTheme.ticketPaper(),
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ghostBar(70, 9),
                  const SizedBox(height: 18),
                  _ghostBar(108, 13),
                  const SizedBox(height: 7),
                  _ghostBar(88, 13),
                  const Spacer(),
                  _ghostBar(56, 20),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _ghostBar(double w, double h) => Container(
        width: w,
        height: h,
        color: PronoArenaTheme.surfaceMuted,
      );
}

/// Aucun match — bande réglée, pas une carte vide.
class _StripEmpty extends StatelessWidget {
  const _StripEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: PronoArenaTheme.gutter),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: PronoArenaTheme.border),
          bottom: BorderSide(color: PronoArenaTheme.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 22,
            color: PronoArenaTheme.edgeHighlight,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun match à venir',
                  style: PronoType.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 3),
                Text(
                  'Dès qu’un match est au calendrier, il apparaît ici.',
                  style: PronoType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
