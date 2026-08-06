import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/match_stats_schema.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/home/home_palette.dart';
import '../services/match_stats_repository.dart';
import 'live_stats_sheet.dart';
import 'match_rating_summary.dart';

const Color _panelGreen = homeGreen;
const Color _panelInk = homeText;
const Color _panelMuted = homeMutedText;
const Color _panelPaper = homeSurface;

/// Sous le score : stats + compositions (carte match) + note si besoin.
class MatchCardBottomPanel extends StatelessWidget {
  final String matchId;
  final MatchModel match;
  final bool showStats;
  final bool showLiveStatsEntry;
  final bool isLive;
  final bool isHomeCard;
  final bool lightSurface;
  final Map<String, dynamic>? fallbackStats;

  const MatchCardBottomPanel({
    super.key,
    required this.matchId,
    required this.match,
    required this.showStats,
    required this.showLiveStatsEntry,
    required this.isLive,
    this.isHomeCard = false,
    required this.lightSurface,
    this.fallbackStats,
  });

  @override
  Widget build(BuildContext context) {
    if (match.status == MatchStatus.upcoming) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .snapshots(),
      builder: (context, matchSnap) {
        final matchDoc = matchSnap.data?.data() ?? {};

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('match_stats')
              .doc(matchId)
              .snapshots(),
          builder: (context, statsSnap) {
            final statsDoc = statsSnap.data?.data();
            final lineups = _resolveLineups(
              matchDoc: matchDoc,
              statsDoc: statsDoc,
              liveDoc: null,
            );

            if (isLive) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('live')
                    .doc('current')
                    .snapshots(),
                builder: (context, liveSnap) {
                  final live = liveSnap.data?.data();
                  final linked = live != null &&
                      (live['matchId'] as String? ?? '').trim() == matchId;
                  if (!linked) return const SizedBox.shrink();

                  final liveLineups = _resolveLineups(
                    matchDoc: matchDoc,
                    statsDoc: statsDoc,
                    liveDoc: live,
                  );
                  return _buildStack(
                    context: context,
                    matchDoc: matchDoc,
                    lineups: liveLineups,
                    liveDoc: live,
                  );
                },
              );
            }

            return _buildStack(
              context: context,
              matchDoc: matchDoc,
              lineups: lineups,
              liveDoc: null,
            );
          },
        );
      },
    );
  }

  MatchLineups _resolveLineups({
    required Map<String, dynamic> matchDoc,
    Map<String, dynamic>? statsDoc,
    Map<String, dynamic>? liveDoc,
  }) {
    if (liveDoc != null) {
      final live = MatchLineups.fromDoc(liveDoc);
      if (live.hasAnyContent) return live;
    }
    return MatchLineups.mergeDocs(matchDoc, statsDoc);
  }

  Widget _buildStack({
    required BuildContext context,
    required Map<String, dynamic> matchDoc,
    required MatchLineups lineups,
    Map<String, dynamic>? liveDoc,
  }) {
    if (isHomeCard) {
      final liveStatsOn =
          isLive && (liveDoc?['statsEnabled'] == true || showLiveStatsEntry);
      return _HomeCardBottom(
        matchDoc: matchDoc,
        lineups: lineups,
        matchId: matchId,
        match: match,
        isLive: isLive,
        statsActive: isLive ? liveStatsOn : showStats,
        lightSurface: lightSurface,
        fallbackStats: fallbackStats,
      );
    }

    final showLineup = lineups.hasAnyContent;
    final liveStatsOn =
        isLive && (liveDoc?['statsEnabled'] == true || showLiveStatsEntry);
    final statsPanel = liveStatsOn || showStats;

    final children = <Widget>[];

    if (statsPanel) {
      children.add(
        _MatchCardStatsPanel(
          matchId: matchId,
          team1: match.team1,
          team2: match.team2,
          matchStatus: match.status,
          lightSurface: lightSurface,
          fallbackStats: fallbackStats,
        ),
      );
    }

    if (showLineup) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(
        _buildPanelShell(
          lightSurface: lightSurface,
          accent: _panelGreen,
          icon: Icons.groups_rounded,
          title: 'COMPOSITIONS',
          compact: statsPanel,
          child: _LineupBody(
            lineups: lineups,
            team1: match.team1,
            team2: match.team2,
            lightSurface: lightSurface,
            compact: statsPanel,
          ),
        ),
      );
    }

    final rating = MatchRatingSnapshot.fromDoc(matchDoc);
    if (rating != null &&
        match.status == MatchStatus.finished &&
        !isLive) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(
        MatchRatingPanel(
          rating: rating,
          lightSurface: lightSurface,
          compact: statsPanel || showLineup,
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Accueil : stats actives → petits encarts ; sinon compo en grand si toggle + données.
class _HomeCardBottom extends StatelessWidget {
  final Map<String, dynamic> matchDoc;
  final MatchLineups lineups;
  final String matchId;
  final MatchModel match;
  final bool isLive;
  final bool statsActive;
  final bool lightSurface;
  final Map<String, dynamic>? fallbackStats;

  const _HomeCardBottom({
    required this.matchDoc,
    required this.lineups,
    required this.matchId,
    required this.match,
    required this.isLive,
    required this.statsActive,
    required this.lightSurface,
    this.fallbackStats,
  });

  bool _statsHaveContent(MatchStatsDisplay display) {
    if (!MatchStatsSchema.isEmpty(display.stats)) return true;
    if (fallbackStats != null && !MatchStatsSchema.isEmpty(fallbackStats)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatsDisplay>(
      stream: MatchStatsRepository.instance.watchWithLivePreview(matchId),
      builder: (context, snap) {
        final display = snap.data ?? MatchStatsDisplay.hidden;
        final statsOn = statsActive;
        final statsFilled = _statsHaveContent(display);
        final compoFilled = lineups.hasAnyContent;
        final compoOnHome = lineups.showOnCard && compoFilled;

        final children = <Widget>[];

        // Live + stats : bandeaux bas (match_card), rien dans le corps.
        if (statsOn && isLive) {
          return const SizedBox.shrink();
        }

        if (statsOn && statsFilled) {
          children.add(
            _HomeActionChip(
              icon: Icons.insights_rounded,
              label: 'Voir les stats',
              accent: _panelGreen,
              onTap: () => showLiveStatsBottomSheet(context),
            ),
          );
        } else if (compoOnHome) {
          children.add(
            _buildPanelShell(
              lightSurface: lightSurface,
              accent: _panelGreen,
              icon: Icons.groups_rounded,
              title: 'COMPOSITIONS',
              child: _LineupBody(
                lineups: lineups,
                team1: match.team1,
                team2: match.team2,
                lightSurface: lightSurface,
              ),
            ),
          );
        } else if (!isLive && match.status == MatchStatus.finished) {
          final rating = MatchRatingSnapshot.fromDoc(matchDoc);
          if (rating != null) {
            children.add(
              MatchRatingPanel(
                rating: rating,
                lightSurface: lightSurface,
              ),
            );
          }
        }

        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

void showMatchLineupPreviewSheet(
  BuildContext context, {
  required MatchLineups lineups,
  required String team1,
  required String team2,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: homeSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: MainShellInsets.sheetContentPadding(
        ctx,
        left: 18,
        top: 16,
        right: 18,
        extra: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COMPOSITIONS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: homeMutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _LineupBody(
            lineups: lineups,
            team1: team1,
            team2: team2,
            lightSurface: true,
          ),
        ],
      ),
    ),
  );
}

class _HomeActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HomeActionChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withAlpha(14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withAlpha(70)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildPanelShell({
  required bool lightSurface,
  required Color accent,
  required IconData icon,
  required String title,
  required Widget child,
  bool compact = false,
}) {
  return Container(
    padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 8 : 10),
    decoration: BoxDecoration(
      color: lightSurface
          ? _panelPaper.withAlpha(230)
          : Colors.black.withAlpha(115),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: lightSurface
            ? const Color(0xFFD8D2C4)
            : Colors.white.withAlpha(40),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 10),
        child,
      ],
    ),
  );
}

class _LineupBody extends StatelessWidget {
  final MatchLineups lineups;
  final String team1;
  final String team2;
  final bool lightSurface;
  final bool compact;

  const _LineupBody({
    required this.lineups,
    required this.team1,
    required this.team2,
    required this.lightSurface,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = lightSurface ? _panelInk : Colors.white;
    final muted = lightSurface ? _panelMuted : Colors.white70;
    final maxStarters = compact ? 7 : 11;
    final maxSubs = compact ? 3 : 5;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _LineupColumn(
              label: team1,
              side: lineups.home,
              ink: ink,
              muted: muted,
              lightSurface: lightSurface,
              alignEnd: false,
              maxStarters: maxStarters,
              maxSubs: maxSubs,
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: muted.withAlpha(60),
          ),
          Expanded(
            child: _LineupColumn(
              label: team2,
              side: lineups.away,
              ink: ink,
              muted: muted,
              lightSurface: lightSurface,
              alignEnd: true,
              maxStarters: maxStarters,
              maxSubs: maxSubs,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupColumn extends StatelessWidget {
  final String label;
  final MatchLineupSide side;
  final Color ink;
  final Color muted;
  final bool lightSurface;
  final bool alignEnd;
  final int maxStarters;
  final int maxSubs;

  const _LineupColumn({
    required this.label,
    required this.side,
    required this.ink,
    required this.muted,
    required this.lightSurface,
    required this.alignEnd,
    required this.maxStarters,
    required this.maxSubs,
  });

  @override
  Widget build(BuildContext context) {
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    Widget coachRow() {
      if (side.coach.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _panelGreen.withAlpha(lightSurface ? 18 : 35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _panelGreen.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports, size: 12, color: _panelGreen.withAlpha(220)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                side.coach,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget playerLine(String name, {bool sub = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          sub ? '↔ $name' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: sub ? muted : ink,
            height: 1.2,
          ),
        ),
      );
    }

    final starters = side.starters.take(maxStarters).toList();
    final subs = side.substitutes.take(maxSubs).toList();
    final extraStarters = side.starters.length - starters.length;
    final extraSubs = side.substitutes.length - subs.length;

    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          label.length > 12 ? '${label.substring(0, 12)}…' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        coachRow(),
        ...starters.map((n) => playerLine(n)),
        if (extraStarters > 0)
          Text(
            '+$extraStarters titulaire${extraStarters > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Remplaçants',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
          ...subs.map((n) => playerLine(n, sub: true)),
          if (extraSubs > 0)
            Text(
              '+$extraSubs',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
        ],
      ],
    );
  }
}

class _MatchCardStatsPanel extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;
  final MatchStatus matchStatus;
  final bool lightSurface;
  final Map<String, dynamic>? fallbackStats;

  const _MatchCardStatsPanel({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.matchStatus,
    required this.lightSurface,
    this.fallbackStats,
  });

  int _i(Map<String, dynamic> s, String k1, String k2) {
    final v = s[k1] ?? s[k2];
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatsDisplay>(
      stream: MatchStatsRepository.instance.watchWithLivePreview(matchId),
      builder: (context, snap) {
        var stats = snap.data?.stats ?? const <String, dynamic>{};
        if (stats.isEmpty && fallbackStats != null) {
          stats = MatchStatsSchema.normalizeMap(fallbackStats);
        }
        if (stats.isEmpty) return const SizedBox.shrink();

        final p1 = _i(stats, 'possession1', 'possessionMillis1');
        final p2 = _i(stats, 'possession2', 'possessionMillis2');
        final t1 = _i(stats, 'tirs1', 'shots1');
        final t2 = _i(stats, 'tirs2', 'shots2');

        final ink = lightSurface ? _panelInk : Colors.white;
        final muted = lightSurface ? _panelMuted : Colors.white70;
        final barA = lightSurface ? _panelGreen : const Color(0xFFC8A436);
        final barB = lightSurface
            ? const Color(0xFFD8D2C4)
            : Colors.white.withAlpha(90);

        Widget bar(String label, int v1, int v2, {bool percent = false}) {
          final total = (v1 + v2).clamp(1, 999999);
          final r1 = v1 / total;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    percent ? '$v1%' : '$v1',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    percent ? '$v2%' : '$v2',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Row(
                  children: [
                    Expanded(
                      flex: (r1 * 100).round().clamp(1, 99),
                      child: Container(height: 4, color: barA),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: ((1 - r1) * 100).round().clamp(1, 99),
                      child: Container(height: 4, color: barB),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return _buildPanelShell(
          lightSurface: lightSurface,
          accent: barA,
          icon: Icons.insights_rounded,
          title: 'STATS DU MATCH',
          child: Column(
            children: [
              if (p1 > 0 || p2 > 0) ...[
                bar('POSSESSION', p1, p2, percent: true),
                const SizedBox(height: 8),
              ],
              if (t1 > 0 || t2 > 0) bar('TIRS', t1, t2),
            ],
          ),
        );
      },
    );
  }
}
