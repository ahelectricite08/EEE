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
    if (matchData['showStats'] == false) return MatchStatsDisplay.hidden;
    final st = (matchData['status'] ?? 'upcoming').toString();
    final early = matchData['earlyPublish'] == true;
    if (st == 'upcoming' && !early) return MatchStatsDisplay.hidden;

    final visibility = MatchStatsSchema.visibilityFromMatchDoc(matchData);
    if (visibility == MatchStatsVisibility.hidden) {
      return MatchStatsDisplay.hidden;
    }
    final stats = MatchStatsSchema.normalizeMap(
      matchData['stats'] as Map<String, dynamic>?,
    );
    final events = _parseEvents(matchData['events']);
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
        if (base.shouldShow) return base;
        final live = liveSnap.data();
        if (live == null) return base;
        final previewId = (live['statsPreviewMatchId'] as String? ?? '').trim();
        if (previewId != matchId) return base;
        final stats = MatchStatsSchema.normalizeMap(
          live['statsPreview'] as Map<String, dynamic>?,
        );
        if (stats.isEmpty) return base;
        return MatchStatsDisplay(
          visibility: MatchStatsVisibility.preview,
          stats: stats,
          events: base.events,
        );
      });
    });
  }

  static List<Map<String, dynamic>> _parseEvents(dynamic raw) =>
      (raw is List ? raw : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .where((e) => const {'goal', 'yellow', 'red'}.contains(e['type']))
          .toList()
        ..sort(
          (a, b) =>
              (a['minute'] as int? ?? 0).compareTo(b['minute'] as int? ?? 0),
        );
}
