import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_stats_schema.dart';

class MatchStatsDisplay {
  final MatchStatsVisibility visibility;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> events;

  const MatchStatsDisplay({
    required this.visibility,
    this.stats = const {},
    this.events = const [],
  });

  static const hidden = MatchStatsDisplay(visibility: MatchStatsVisibility.hidden);

  bool get shouldShow =>
      visibility != MatchStatsVisibility.hidden &&
      (stats.isNotEmpty || events.isNotEmpty);
}

/// Lecture unique stats match côté app (fiche, cartes).
class MatchStatsRepository {
  MatchStatsRepository._();
  static final instance = MatchStatsRepository._();

  static final _matches = FirebaseFirestore.instance.collection('matches');
  static final _live = FirebaseFirestore.instance.collection('live').doc('current');

  MatchStatsDisplay fromMatchData(Map<String, dynamic>? matchData) {
    if (matchData == null) return MatchStatsDisplay.hidden;

    final events = MatchStatsSchema.eventsFromMatchDoc(matchData);
    final stats = MatchStatsSchema.normalizeMap(
      matchData['stats'] as Map<String, dynamic>?,
    );
    final hasEvents = events.isNotEmpty;
    final st = (matchData['status'] ?? 'upcoming').toString();
    final early = matchData['earlyPublish'] == true;

    if (matchData['showStats'] == false && !hasEvents) {
      return MatchStatsDisplay.hidden;
    }
    if (st == 'upcoming' && !early && !hasEvents) {
      return MatchStatsDisplay.hidden;
    }

    var visibility = MatchStatsSchema.visibilityFromMatchDoc(matchData);
    if (visibility == MatchStatsVisibility.hidden && hasEvents) {
      visibility = MatchStatsVisibility.published;
    }
    if (stats.isEmpty && events.isEmpty) {
      return MatchStatsDisplay.hidden;
    }
    return MatchStatsDisplay(
      visibility: visibility,
      stats: stats,
      events: events,
    );
  }

  Stream<MatchStatsDisplay> watch(String matchId) {
    return _matches.doc(matchId).snapshots().map((snap) {
      if (!snap.exists) return MatchStatsDisplay.hidden;
      return fromMatchData(snap.data());
    });
  }

  /// Preview live mirror (TV / encart) — complète la fiche si preview actif.
  Stream<MatchStatsDisplay> watchWithLivePreview(String matchId) {
    return _matches.doc(matchId).snapshots().asyncExpand((matchSnap) {
      final base = fromMatchData(matchSnap.data());
      return _live.snapshots().map((liveSnap) {
        final live = liveSnap.data();
        if (live == null) return base;

        final liveMid = (live['matchId'] as String? ?? '').trim();
        final previewId = (live['statsPreviewMatchId'] as String? ?? '').trim();
        final liveLinked = liveMid == matchId || previewId == matchId;
        final liveEvents = liveLinked
            ? MatchStatsSchema.parseGameEvents(live['events'])
            : const <Map<String, dynamic>>[];
        final mergedEvents = MatchStatsSchema.mergeGameEvents(
          base.events,
          liveEvents,
        );

        if (base.shouldShow) {
          var stats = base.stats;
          if (liveLinked) {
            final liveStats = MatchStatsSchema.normalizeMap(
              live['statsPreview'] as Map<String, dynamic>?,
            );
            if (liveStats.isNotEmpty) stats = liveStats;
          }
          if (mergedEvents.length == base.events.length &&
              stats.length == base.stats.length) {
            return base;
          }
          return MatchStatsDisplay(
            visibility: base.visibility,
            stats: stats,
            events: mergedEvents,
          );
        }

        if (!liveLinked) return base;

        final stats = MatchStatsSchema.normalizeMap(
          live['statsPreview'] as Map<String, dynamic>?,
        );
        if (stats.isEmpty && mergedEvents.isEmpty) return base;
        return MatchStatsDisplay(
          visibility: stats.isNotEmpty
              ? MatchStatsVisibility.preview
              : base.visibility != MatchStatsVisibility.hidden
                  ? base.visibility
                  : MatchStatsVisibility.preview,
          stats: stats.isNotEmpty ? stats : base.stats,
          events: mergedEvents,
        );
      });
    });
  }
}
