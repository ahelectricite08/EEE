import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../utils/open_prono_for_match.dart';
import '../../data/firestore_prono_repository.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../social/prono_social_hub_page.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_tab_hero_sliver.dart';

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
          subtitle:
              'Salut $displayName — matchs, points, duels et potes.',
          pageAccent: _pageAccent,
          bannerSlot: PronoBannerSlot.home,
        ),
        PronoTabHeroSliver.sheetLeadInSliver(),
        SliverToBoxAdapter(
          child: _PronoHomeHeroStats(uid: uid),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FilledButton.icon(
                onPressed: onOpenMatches,
                icon: const Icon(Icons.sports_soccer_rounded, size: 20),
                label: Text(
                  'Voir les matchs',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                style: PronoTheme.primaryCtaStyle(pageAccent: _pageAccent),
              ),
              const SizedBox(height: 24),
              const _PronoHomeSectionTitle(
                label: 'Prochains matchs',
                icon: Icons.event_available_rounded,
                pageAccent: _pageAccent,
              ),
              const SizedBox(height: 8),
              _PronoHomeNextMatchesStrip(repo: repo, uid: uid),
              const SizedBox(height: 28),
              // Multijoueur / Social — contenu principal Accueil (sans tip Communauté).
              PronoSocialHubBody(
                uid: uid,
                displayName: displayName,
                showTip: false,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PronoHomeSectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  final PronoPageAccent pageAccent;

  const _PronoHomeSectionTitle({
    required this.label,
    required this.icon,
    required this.pageAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PronoArenaTheme.sectionAccentMark(pageAccent, size: 7),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: pageAccent.color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: PronoTokens.text,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PronoHomeNextMatchesStrip extends StatelessWidget {
  final FirestorePronoRepository repo;
  final String uid;

  const _PronoHomeNextMatchesStrip({required this.repo, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repo.watchUpcomingMatches(limit: 40),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PronoTokens.textMuted,
                ),
              ),
            ),
          );
        }
        final raw = snap.data ?? const [];
        final now = DateTime.now();
        final upcoming =
            raw.where((m) => m.date.isAfter(now)).toList(growable: false);
        if (upcoming.isEmpty) {
          return Text(
            'Aucun match à venir.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: PronoTokens.textMuted,
            ),
          );
        }
        final inWindow = upcoming.where((m) {
          final days = m.date.difference(now).inDays;
          return days <= 7;
        }).take(8);
        final toShow = inWindow.isNotEmpty ? inWindow : upcoming.take(5);

        return SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: toShow.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = toShow.elementAt(i);
              final daysLeft = m.date.difference(now).inDays;
              final locked = !now.isBefore(m.date);
              final tooEarly = !locked && daysLeft > 7;
              final canProno = !locked && !tooEarly;
              return _HomeMatchMiniCard(
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

class _HomeMatchMiniCard extends StatelessWidget {
  final FirestorePronoRepository repo;
  final String uid;
  final PronoMatchListItem match;
  final bool canProno;
  final bool tooEarly;

  const _HomeMatchMiniCard({
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
    final t1 = match.team1;
    final t2 = match.team2;
    final dateStr = DateFormat('EEE d MMM', 'fr_FR').format(match.date);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.watchPredictionDoc(match.id, uid),
      builder: (context, predSnap) {
        final hasPred =
            predSnap.hasData && (predSnap.data?.exists ?? false);
        final pd = predSnap.data?.data();
        final ps1 = _predScore(pd, 'score1Pred');
        final ps2 = _predScore(pd, 'score2Pred');
        final ctaLabel = !canProno
            ? (tooEarly ? 'Bientôt' : 'Fermé')
            : (hasPred ? 'Modifier' : 'Jouer');
        return _HomeMatchMiniCardInteractive(
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }
          },
          child: Ink(
            width: 168,
            height: 128,
            decoration: PronoTheme.cardDecoration(
              radius: PronoTokens.radiusMd,
              pageAccent: PronoPageAccent.matchs,
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: canProno
                        ? PronoPageAccent.matchs.color
                        : PronoTokens.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PronoTokens.text,
                    height: 1.1,
                  ),
                ),
                Text(
                  'vs $t2',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: PronoTokens.textMuted,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                if (hasPred && ps1 != null && ps2 != null)
                  Text(
                    '$ps1 — $ps2',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: PronoPageAccent.matchs.color,
                      letterSpacing: -0.3,
                      height: 1,
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: PronoTokens.animFast,
                    curve: PronoTokens.animCurve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: PronoTheme.playChipDecoration(
                      enabled: canProno,
                      pageAccent: PronoPageAccent.matchs,
                    ),
                    child: Text(
                      ctaLabel.toUpperCase(),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: canProno
                            ? PronoPageAccent.matchs.onColor
                            : PronoTokens.textSoft,
                        letterSpacing: 0.8,
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

class _HomeMatchMiniCardInteractive extends StatefulWidget {
  final bool canProno;
  final VoidCallback onTap;
  final Widget child;

  const _HomeMatchMiniCardInteractive({
    required this.canProno,
    required this.onTap,
    required this.child,
  });

  @override
  State<_HomeMatchMiniCardInteractive> createState() =>
      _HomeMatchMiniCardInteractiveState();
}

class _HomeMatchMiniCardInteractiveState
    extends State<_HomeMatchMiniCardInteractive> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTapDown: widget.canProno ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.canProno ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            widget.canProno ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: PronoTokens.animFast,
          curve: PronoTokens.animCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PronoHomeHeroStats extends StatelessWidget {
  final String uid;

  const _PronoHomeHeroStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    const pageAccent = PronoHomePage._pageAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: XpService.levelsDocStream(),
                  builder: (context, cfgSnap) {
                    final config = cfgSnap.data?.data();
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: PronoSocialService.userDocStream(uid),
                      builder: (context, userSnap) {
                        final xp = XpService.displayXp(userSnap.data?.data());
                        final prog = PronoSocialService.progressInLevel(
                          xp,
                          config: config,
                        );
                        final toNext =
                            PronoSocialService.xpToNextLevel(xp, config: config);
                        final xpLabel = toNext == null
                            ? 'Palier max'
                            : '${toNext.round()} XP restants';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '$xp XP',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: pageAccent.color,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    xpLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: PronoTokens.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: prog),
                                duration: PronoTokens.animSlow,
                                curve: PronoTokens.animCurve,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    backgroundColor: PronoTokens.surfaceMuted,
                                    color: pageAccent.color,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: XpService.levelsDocStream(),
                builder: (context, cfgSnap) {
                  final config = cfgSnap.data?.data();
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: PronoSocialService.userDocStream(uid),
                    builder: (context, userSnap) {
                      final xp = XpService.displayXp(userSnap.data?.data());
                      final level =
                          PronoSocialService.levelFromXp(xp, config: config);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: PronoTheme.cardDecoration(radius: 8),
                        child: Column(
                          children: [
                            Text(
                              'NIV.',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: PronoTokens.textMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '$level',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: PronoTokens.text,
                                height: 1,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.leaderboardEntryStream(uid),
            builder: (context, snap) {
              final d = snap.data?.data() ?? const <String, dynamic>{};
              final pts = (d['points'] as num?)?.toInt() ?? 0;
              final streak = (d['pronoStreak'] as num?)?.toInt() ?? 0;
              return Row(
                children: [
                  Expanded(
                    child: _HeroStat(label: '$pts pts', accent: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroStat(
                      label: streak > 0 ? '$streak en série' : 'Série',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final bool accent;

  const _HeroStat({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    const pageAccent = PronoHomePage._pageAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PronoTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PronoTokens.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: accent ? pageAccent.color : PronoTokens.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
