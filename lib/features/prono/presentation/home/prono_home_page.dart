import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../services/prono_social_service.dart';
import '../../../../utils/open_prono_for_match.dart';
import '../../data/firestore_prono_repository.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_gamified_encart.dart';
import 'prono_powered_by_encart.dart';

class PronoHomePage extends StatelessWidget {
  final String uid;
  final String displayName;
  final FirestorePronoRepository repo;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenSeason;
  final VoidCallback onOpenSocial;
  final VoidCallback onOpenGlobalRanking;

  const PronoHomePage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.repo,
    required this.onOpenMatches,
    required this.onOpenSeason,
    required this.onOpenSocial,
    required this.onOpenGlobalRanking,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottomInset = PronoTokens.bottomContentInset(context);

    return CustomScrollView(
      clipBehavior: Clip.hardEdge,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _PronoHomeHero(topPad: top, uid: uid, displayName: displayName),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration:
                    PronoTokens.homeOverlapSheetDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: PronoTokens.barStripeColors(active: true),
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const PronoPoweredByEncart(),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: onOpenMatches,
                        icon: const Icon(Icons.sports_soccer_rounded),
                        label: Text(
                          'Voir les matchs',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PronoTokens.accentDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          side: BorderSide(
                            color: PronoTokens.accentGold.withAlpha(130),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PronoTokens.radiusMd + 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _PronoHomeSectionTitle(
                        eyebrow: 'AU PROGRAMME',
                        icon: Icons.event_available_rounded,
                        label: 'À venir',
                        accent: PronoIconAccent.matches,
                      ),
                      const SizedBox(height: 12),
                      _PronoHomeNextMatchesStrip(repo: repo, uid: uid),
                      const SizedBox(height: 22),
                      _PronoHomeSectionTitle(
                        eyebrow: 'EN UN CLIC',
                        icon: Icons.bolt_rounded,
                        label: 'Raccourcis',
                        accent: PronoIconAccent.energy,
                      ),
                      const SizedBox(height: 12),
                      _PronoHomeQuickLinks(
                        onOpenGlobalRanking: onOpenGlobalRanking,
                        onOpenSeason: onOpenSeason,
                        onOpenSocial: onOpenSocial,
                      ),
                      const SizedBox(height: 22),
                      _PronoHomeSectionTitle(
                        eyebrow: 'TON PARCOURS',
                        icon: Icons.insights_rounded,
                        label: 'Ta progression',
                        accent: PronoIconAccent.progress,
                      ),
                      const SizedBox(height: 12),
                      _PronoHomeMiniSeason(uid: uid, onOpenSeason: onOpenSeason),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 12 + bottomInset)),
      ],
    );
  }
}

class _PronoHomeSectionTitle extends StatelessWidget {
  final String eyebrow;
  final IconData icon;
  final String label;
  final PronoIconAccent accent;

  const _PronoHomeSectionTitle({
    required this.eyebrow,
    required this.icon,
    required this.label,
    this.accent = PronoIconAccent.primary,
  });

  @override
  Widget build(BuildContext context) {
    final tone = PronoTokens.iconAccentColors(accent);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PronoTokens.surface,
            Color.lerp(PronoTokens.surface, tone.$3, 0.055) ??
                PronoTokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 2),
        border: Border.all(
          color:
              Color.lerp(tone.$3, PronoTokens.border, 0.45)!.withAlpha(100),
        ),
        boxShadow: [
          BoxShadow(
            color: PronoTokens.accentDeep.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: tone.$3.withAlpha(22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tone.$3,
                  Color.lerp(tone.$3, PronoTokens.accentGold, 0.35)!,
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                PronoTokens.iconBadgeCircleDecoration(accent: accent),
            child: Icon(
              icon,
              size: 20,
              color: tone.$3,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: tone.$3,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                    height: 0.98,
                    letterSpacing: 0.35,
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

/// Bandeau horizontal : matchs ouverts aux pronos en priorité, sinon prochains.
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
            height: 104,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PronoTokens.accent,
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
            'Aucun match à venir dans le calendrier.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PronoTokens.textMuted,
              height: 1.35,
            ),
          );
        }
        final inWindow = upcoming.where((m) {
          final days = m.date.difference(now).inDays;
          return days <= 7;
        }).take(8);
        final toShow = inWindow.isNotEmpty ? inWindow : upcoming.take(5);

        return SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: toShow.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
    final matchTone =
        PronoTokens.iconAccentColors(PronoIconAccent.matches);
    final t1 = match.team1;
    final t2 = match.team2;
    final dateStr =
        DateFormat('EEE d MMM', 'fr_FR').format(match.date).toUpperCase();
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
            : (hasPred ? 'Modifier mon prono' : 'Pronostiquer');
        return Material(
      color: Colors.transparent,
      child: InkWell(
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
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 1),
        child: Ink(
          width: 172,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 1),
            border: Border.all(
              color: Color.lerp(
                    canProno ? matchTone.$3 : PronoTokens.textSoft,
                    PronoTokens.border,
                    canProno ? 0.38 : 0.72,
                  )!
                  .withAlpha(canProno ? 105 : 88),
              width: canProno ? 1.15 : 1,
            ),
            boxShadow: [
              ...PronoTokens.cardShadow(context),
              BoxShadow(
                color: (canProno ? matchTone.$3 : PronoTokens.accent).withAlpha(
                  canProno ? 16 : 6,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: PronoTokens.surface,
              borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        colors: canProno
                            ? PronoTokens.barStripeColors(active: true)
                            : [
                                PronoTokens.textSoft.withAlpha(100),
                                PronoTokens.border,
                              ],
                      ),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: canProno ? matchTone.$3 : PronoTokens.textSoft,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: PronoTokens.text,
                      height: 1,
                    ),
                  ),
                  Text(
                    'vs $t2',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PronoTokens.textMuted,
                    ),
                  ),
                  const Spacer(),
                  if (hasPred && ps1 != null && ps2 != null) ...[
                    Text(
                      '$ps1 — $ps2',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: PronoTokens.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Icon(
                        canProno
                            ? (hasPred
                                ? Icons.edit_rounded
                                : Icons.touch_app_rounded)
                            : Icons.schedule_rounded,
                        size: 14,
                        color: canProno ? matchTone.$3 : PronoTokens.textSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ctaLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: canProno ? matchTone.$3 : PronoTokens.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}

class _PronoHomeQuickLinks extends StatelessWidget {
  final VoidCallback onOpenGlobalRanking;
  final VoidCallback onOpenSeason;
  final VoidCallback onOpenSocial;

  const _PronoHomeQuickLinks({
    required this.onOpenGlobalRanking,
    required this.onOpenSeason,
    required this.onOpenSocial,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      PronoIconAccent accent = PronoIconAccent.primary,
      /// Demi-largeur (2 colonnes) : plus d’espace texte, pas de coupure mi-mot.
      bool compact = false,
    }) {
      final tone = PronoTokens.iconAccentColors(accent);
      final iconPad = compact ? 7.0 : 10.0;
      final iconSize = compact ? 19.0 : 22.0;
      final titleSize = compact ? 15.0 : 16.0;
      final subSize = compact ? 10.0 : 11.0;
      final hPad = compact ? 10.0 : 12.0;
      final vPad = compact ? 12.0 : 13.0;

      Widget titleBlock() {
        final titleStyle = GoogleFonts.barlowCondensed(
          fontSize: titleSize,
          fontWeight: FontWeight.w900,
          color: PronoTokens.text,
          height: 1.0,
          letterSpacing: compact ? 0.15 : 0.2,
        );
        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: titleStyle,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: PronoTokens.accentDeep.withAlpha(200),
              ),
            ],
          );
        }
        return Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: titleStyle,
        );
      }

      Widget subtitleBlock() {
        return Text(
          subtitle,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: GoogleFonts.inter(
            fontSize: subSize,
            fontWeight: FontWeight.w600,
            color: PronoTokens.textMuted,
            height: compact ? 1.28 : 1.35,
          ),
        );
      }

      return Material(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 1),
          splashColor: tone.$3.withAlpha(30),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 1),
              border: Border.all(
                color: Color.lerp(tone.$3, PronoTokens.border, 0.48)!
                    .withAlpha(100),
              ),
              boxShadow: [
                ...PronoTokens.cardShadow(context),
                BoxShadow(
                  color: tone.$3.withAlpha(18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    PronoTokens.surface,
                    Color.lerp(PronoTokens.surface, tone.$3, 0.04) ??
                        PronoTokens.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 1),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: vPad,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPad),
                      decoration: PronoTokens.iconBadgeDecoration(
                        radius: compact ? 12 : 14,
                        accent: accent,
                      ),
                      child: Icon(
                        icon,
                        color: tone.$3,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleBlock(),
                          SizedBox(height: compact ? 5 : 6),
                          subtitleBlock(),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration:
                                PronoTokens.chevronCircleDecoration(),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: tile(
                icon: Icons.leaderboard_rounded,
                title: 'Classement',
                subtitle: 'Top 50 global',
                onTap: onOpenGlobalRanking,
                accent: PronoIconAccent.ranking,
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                icon: Icons.insights_rounded,
                title: 'Progression',
                subtitle: 'Stats, XP & niveau',
                onTap: onOpenSeason,
                accent: PronoIconAccent.progress,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.groups_rounded,
          title: 'Social',
          subtitle: 'Amis, duels, ligues',
          onTap: onOpenSocial,
          accent: PronoIconAccent.social,
        ),
        const SizedBox(height: 14),
        PronoGamifiedTipCard.homeBoost(),
      ],
    );
  }
}

class _PronoHomeMiniSeason extends StatelessWidget {
  final String uid;
  final VoidCallback onOpenSeason;

  const _PronoHomeMiniSeason({
    required this.uid,
    required this.onOpenSeason,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.pronoConfigStream(),
      builder: (context, cfgSnap) {
        final config = cfgSnap.data?.data();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.userDocStream(uid),
          builder: (context, userSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.leaderboardEntryStream(uid),
              builder: (context, lbSnap) {
                final d = PronoSocialService.mergeLeaderboardAndPronoProfileForXp(
                  lbSnap.data?.data(),
                  userSnap.data?.data(),
                );
                final points = (d['points'] as num?)?.toInt() ?? 0;
                final total = (d['totalPredictions'] as num?)?.toInt() ?? 0;
                final xp = PronoSocialService.resolvedPronoDisplayXp(
                  mergedLeaderboardStats: d,
                  userDocData: userSnap.data?.data(),
                  config: config,
                );
                final level = PronoSocialService.levelFromXp(xp, config: config);
                final label =
                    PronoSocialService.levelLabelFromXp(xp, config: config);
                final prog =
                    PronoSocialService.progressInLevel(xp, config: config);
                final toNext =
                    PronoSocialService.xpToNextLevel(xp, config: config);
                final nextLabel = toNext == null
                    ? 'Palier max atteint'
                    : '${toNext.round()} XP avant le prochain palier';
                final progTone =
                    PronoTokens.iconAccentColors(PronoIconAccent.progress);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpenSeason,
                    borderRadius:
                        BorderRadius.circular(PronoTokens.radiusLg + 2),
                    child: Ink(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(PronoTokens.radiusLg + 2),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PronoTokens.surface,
                            Color.lerp(
                                  PronoTokens.surface,
                                  progTone.$3,
                                  0.06,
                                ) ??
                                PronoTokens.surface,
                          ],
                        ),
                        border: Border.all(
                          color: Color.lerp(
                            progTone.$3,
                            PronoTokens.accentGold,
                            0.25,
                          )!.withAlpha(72),
                        ),
                        boxShadow: PronoTokens.cardShadow(context),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(PronoTokens.radiusLg),
                          color: PronoTokens.surface,
                          border: Border.all(
                            color: PronoTokens.border.withAlpha(100),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration:
                                      PronoTokens.iconBadgeDecoration(
                                    radius: 14,
                                    accent: PronoIconAccent.progress,
                                  ),
                                  child: Text(
                                    'L$level',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: PronoTokens.iconAccentColors(
                                        PronoIconAccent.progress,
                                      ).$3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: PronoTokens.text,
                                          height: 1,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      Text(
                                        '$points pts · $total pronos',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: PronoTokens.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration:
                                      PronoTokens.chevronCircleDecoration(),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: prog,
                                minHeight: 7,
                                backgroundColor: PronoTokens.surfaceMuted,
                                color: progTone.$3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              nextLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: PronoTokens.textMuted,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PronoHomeHero extends StatelessWidget {
  final double topPad;
  final String uid;
  final String displayName;

  const _PronoHomeHero({
    required this.topPad,
    required this.uid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    const sheetOverlap = 24.0;
    return SizedBox(
      height: 228 + topPad + sheetOverlap,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.12),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(90),
                  Color.lerp(
                    PronoTokens.accentDeep,
                    PronoTokens.accentGold,
                    0.12,
                  )!.withAlpha(210),
                  PronoTokens.accentDeep.withAlpha(238),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: topPad + 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salut $displayName',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withAlpha(235),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PRONOS',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    height: 0.92,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ici on joue le jeu jusqu’au coup de sifflet : matchs, points, '
                  'duels et potes.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(232),
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 14),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: PronoSocialService.leaderboardEntryStream(uid),
                  builder: (context, snap) {
                    final d = snap.data?.data() ?? const <String, dynamic>{};
                    final pts = (d['points'] as num?)?.toInt() ?? 0;
                    final streak = (d['pronoStreak'] as num?)?.toInt() ?? 0;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HeroChip(
                          icon: Icons.emoji_events_rounded,
                          label: '$pts pts',
                        ),
                        _HeroChip(
                          icon: Icons.local_fire_department_rounded,
                          label: streak > 0 ? '$streak série' : 'Série',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    // Fond assez dense : l’ancien vert institutionnel sur vert sombre
    // rendait les icônes (trophée / flamme) presque invisibles.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F1A).withAlpha(210),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PronoTokens.accentGold.withAlpha(160),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: PronoTokens.accentGold.withAlpha(35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 19,
            color: PronoTokens.accentGold,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x88000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
