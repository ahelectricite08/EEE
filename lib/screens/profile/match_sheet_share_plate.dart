import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/sedan_squad.dart';
import '../../services/live_state_service.dart';
import '../../services/match_sheet_share_service.dart';
import '../../services/sedan_squad_service.dart';
import 'match_story_visual.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

/// Plaque profil admin / CM : kit stories 9:16 (pas la feuille de match).
class MatchSheetSharePlate extends StatelessWidget {
  const MatchSheetSharePlate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveStateService.watchCurrentSnapshots(),
      builder: (context, liveSnap) {
        final live = liveSnap.data?.data();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .orderBy('date', descending: true)
              .limit(24)
              .snapshots(),
          builder: (context, matchesSnap) {
            final docs = matchesSnap.data?.docs ?? const [];
            final picked = pickMatchStorySource(
              live: live,
              matches: [
                for (final d in docs) (id: d.id, data: d.data()),
              ],
            );
            if (picked == null) {
              return const _KitPaper(empty: true);
            }
            return _KitLiveMerged(
              matchId: picked.id,
              picked: picked.data,
              live: live,
            );
          },
        );
      },
    );
  }
}

class _KitLiveMerged extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> picked;
  final Map<String, dynamic>? live;

  const _KitLiveMerged({
    required this.matchId,
    required this.picked,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('match_stats')
              .doc(matchId)
              .snapshots(),
          builder: (context, statsSnap) {
            final liveForMatch = live != null &&
                    (live!['matchId'] as String? ?? '').trim() == matchId
                ? live
                : null;
            final merged = MatchSheetShareService.composeStoryDoc(
              live: liveForMatch,
              match: picked,
              stats: statsSnap.data?.data(),
            );
            merged['matchId'] = matchId;
            final squadRev = squadSnap.data?.players.length ?? 0;
            return KeyedSubtree(
              key: ValueKey('kit-$matchId-$squadRev'),
              child: _KitPaper(
                empty: false,
                data: merged,
              ),
            );
          },
        );
      },
    );
  }
}

class _KitPaper extends StatelessWidget {
  final bool empty;
  final Map<String, dynamic> data;

  const _KitPaper({
    required this.empty,
    this.data = const {},
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: profilePaper(
        edge: empty ? null : profileGreenBright.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 14,
                  color: profileGreenBright,
                ),
                const SizedBox(width: 6),
                Text('STORIES RÉSEAUX', style: ProfileType.kicker),
                const Spacer(),
                Text(
                  'PORTRAIT 9:16',
                  style: ProfileType.kicker.copyWith(
                    color: profileGreenBright,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: profileHairline),
            const SizedBox(height: 10),
            if (empty) ...[
              Text(
                'Visuel vertical pour les réseaux',
                style: ProfileType.title.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                'Lance le live ou ouvre un match Sedan 1ère.',
                style: ProfileType.caption,
              ),
            ] else ...[
              Text(
                kitMatchTitle(data),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileType.title.copyWith(fontSize: 22, height: 1.05),
              ),
              const SizedBox(height: 10),
              _StoryKitActionList(data: data, dense: false),
              const SizedBox(height: 10),
              Text(
                'Admin / CM · stories Instagram / TikTok',
                style: ProfileType.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau compact dans le pilotage live (admin / CM).
class MatchStoryKitStrip extends StatelessWidget {
  final Map<String, dynamic> data;

  const MatchStoryKitStrip({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (!MatchSheetShareService.isSedanPremiereMatch(data)) {
      return const SizedBox.shrink();
    }
    final matchId = MatchSheetShareService.storyMatchIdOf(data);
    if (matchId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _StripShell(
          child: _StoryKitActionList(data: data, dense: true),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('match_stats')
            .doc(matchId)
            .snapshots(),
        builder: (context, statsSnap) {
          final merged = MatchSheetShareService.composeStoryDoc(
            live: data,
            stats: statsSnap.data?.data(),
          );
          merged['matchId'] = matchId;
          return _StripShell(
            child: _StoryKitActionList(data: merged, dense: true),
          );
        },
      ),
    );
  }
}

class _StripShell extends StatelessWidget {
  final Widget child;

  const _StripShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: profilePaper(
        edge: profileGreenBright.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 14,
                  color: profileGreenBright,
                ),
                const SizedBox(width: 6),
                Text('STORIES RÉSEAUX', style: ProfileType.kicker),
                const Spacer(),
                Text(
                  '9:16',
                  style: ProfileType.kicker.copyWith(
                    color: profileGreenBright,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StoryKitActionList extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool dense;

  const _StoryKitActionList({
    required this.data,
    required this.dense,
  });

  void _open(
    BuildContext context,
    MatchStoryKind kind, {
    MatchSheetScorer? goal,
  }) {
    unawaited(openMatchStory(context, kind: kind, data: data, goal: goal));
  }

  @override
  Widget build(BuildContext context) {
    final lineupReady = hasSedanStoryStarters(data);
    final goals = cssaGoalStoryScorers(data);

    if (dense) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _KitChip(
            label: 'Coup d’envoi',
            onTap: () => _open(context, MatchStoryKind.kickoff),
          ),
          _KitChip(
            label: 'Composition',
            muted: !lineupReady,
            onTap: () => _open(context, MatchStoryKind.lineup),
          ),
          for (final g in goals)
            _KitChip(
              label: 'But ${g.minute}\' ${g.player}',
              onTap: () => _open(context, MatchStoryKind.goal, goal: g),
            ),
          _KitChip(
            label: 'Mi-temps',
            onTap: () => _open(context, MatchStoryKind.halfTime),
          ),
          _KitChip(
            label: 'Fin de match',
            onTap: () => _open(context, MatchStoryKind.fullTime),
          ),
        ],
      );
    }

    return Column(
      children: [
        _KitRow(
          label: 'Coup d’envoi',
          onTap: () => _open(context, MatchStoryKind.kickoff),
        ),
        _KitRow(
          label: 'Composition du jour',
          muted: !lineupReady,
          onTap: () => _open(context, MatchStoryKind.lineup),
        ),
        for (final g in goals)
          _KitRow(
            label: 'But ${g.minute}\' ${g.player}',
            onTap: () => _open(context, MatchStoryKind.goal, goal: g),
          ),
        _KitRow(
          label: 'Mi-temps',
          onTap: () => _open(context, MatchStoryKind.halfTime),
        ),
        _KitRow(
          label: 'Fin de match',
          onTap: () => _open(context, MatchStoryKind.fullTime),
        ),
      ],
    );
  }
}

class _KitRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;

  const _KitRow({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  muted
                      ? Icons.hourglass_empty_rounded
                      : Icons.crop_portrait_rounded,
                  size: 16,
                  color: profileGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: profileText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: muted ? profileMutedText : profileGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KitChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;

  const _KitChip({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.45 : 1,
      child: Material(
        color: muted ? profileSurfaceMuted : profileGreen,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: muted ? profileHairline : profileGreenDeep,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: muted ? profileMutedText : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
