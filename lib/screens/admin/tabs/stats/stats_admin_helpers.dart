import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/match_stats_schema.dart';
import '../../../../utils/match_competition.dart';

/// Données dérivées d'un doc `matches` — partagées entre tableau, live et comparaison.
class AdminMatchRowData {
  AdminMatchRowData({
    required this.doc,
    required this.d,
    required this.s,
    required this.t1,
    required this.t2,
    required this.date,
    required this.score,
    required this.showScoreChip,
    required this.hasStats,
    required this.goals,
    required this.goalStr,
    required this.yH,
    required this.yA,
    required this.rH,
    required this.rA,
  });

  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> d;
  final Map<String, dynamic> s;
  final String t1;
  final String t2;
  final String date;
  final String score;
  /// Pastille score dans l’historique (FFF, live ou buteurs saisis).
  final bool showScoreChip;
  final bool hasStats;
  final List<Map<String, dynamic>> goals;
  final String goalStr;
  final int yH;
  final int yA;
  final int rH;
  final int rA;

  String get id => doc.id;

  String get competition =>
      MatchCompetition.displayLabel(d['competition'] as String?);

  DateTime? get matchDate {
    final ts = d['date'] as Timestamp?;
    return ts?.toDate();
  }

  bool get isSedanHome => t1.toUpperCase().contains('SEDAN');
  bool get isSedanAway => t2.toUpperCase().contains('SEDAN');

  /// Côté Sedan dans les stats (team1 = stats côté 1).
  bool get sedanIsHome {
    if (isSedanHome) return true;
    if (isSedanAway) return false;
    return true;
  }

  String sv(String k1, String k2) =>
      s.containsKey(k1) ? '${s[k1]}-${s[k2]}' : '-';

  String get crossLine {
    final a1 = (s['crossAcc1'] as int?) ?? 0;
    final a2 = (s['crossAcc2'] as int?) ?? 0;
    final t1c = a1 + ((s['crossInacc1'] as int?) ?? 0);
    final t2c = a2 + ((s['crossInacc2'] as int?) ?? 0);
    if (t1c + t2c == 0) return '-';
    return '$a1/$t1c – $a2/$t2c';
  }

  String get possessionLine => s.containsKey('possession1')
      ? '${s['possession1']}% / ${s['possession2'] ?? 0}%'
      : '';

  /// Valeur stat côté Sedan pour une paire de clés (team1/team2).
  num? sedanStat(String k1, String k2) {
    if (!hasStats) return null;
    if (sedanIsHome && s.containsKey(k1)) return s[k1] as num?;
    if (!sedanIsHome && s.containsKey(k2)) return s[k2] as num?;
    return null;
  }

  factory AdminMatchRowData.fromDoc(
    QueryDocumentSnapshot doc, {
    Map<String, dynamic>? sheet,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    final matchStats = d['stats'] as Map<String, dynamic>? ?? {};
    final sheetStats = sheet?['stats'] as Map<String, dynamic>? ?? {};
    final s = MatchStatsSchema.normalizeMap(
      MatchStatsSchema.isEmpty(sheetStats) ? matchStats : sheetStats,
    );
    final t1 = (d['team1'] as String? ?? '');
    final t2 = (d['team2'] as String? ?? '');
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final date = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : '-';
    final events = MatchStatsSchema.eventsFromMatchDoc(d);
    final goals =
        events.where((e) => (e['type'] as String? ?? '') == 'goal').toList();
    final resolved = MatchStatsSchema.resolveMatchScores(d, events: events);
    final score = resolved.display;
    final hasStats = s.isNotEmpty;
    final goalStr = goals.isEmpty
        ? '-'
        : goals
              .map((e) {
                final line = MatchStatsSchema.eventPlayerLine(e);
                final name = line.isNotEmpty
                    ? line.split(' ').last
                    : '';
                final m = e['minute'] ?? '?';
                return name.isEmpty ? "? $m'" : '$name $m\'';
              })
              .join('  ');
    final yH =
        (d['yellowHome'] as int?) ?? (d['yellow_home'] as int?) ?? 0;
    final yA =
        (d['yellowAway'] as int?) ?? (d['yellow_away'] as int?) ?? 0;
    final rH = (d['redHome'] as int?) ?? (d['red_home'] as int?) ?? 0;
    final rA = (d['redAway'] as int?) ?? (d['red_away'] as int?) ?? 0;
    final showScoreChip = resolved.isKnown ||
        goals.isNotEmpty ||
        hasStats ||
        yH + yA + rH + rA > 0;
    return AdminMatchRowData(
      doc: doc,
      d: d,
      s: s,
      t1: t1,
      t2: t2,
      date: date,
      score: score,
      showScoreChip: showScoreChip,
      hasStats: hasStats,
      goals: goals,
      goalStr: goalStr,
      yH: yH,
      yA: yA,
      rH: rH,
      rA: rA,
    );
  }
}

/// Étapes du parcours stats (simple pour le jour de match).
enum StatsWorkflowStep {
  prepare, // à saisir
  live, // en direct dans l'app
  official, // clôturé
}

StatsWorkflowStep statsWorkflowStep(
  Map<String, dynamic> matchData, {
  String? sheetState,
}) {
  final state = MatchStatsPublicationState.fromFirestore(
    sheetState ?? matchData['statsState']?.toString(),
  );
  switch (state) {
    case MatchStatsPublicationState.published:
      return StatsWorkflowStep.official;
    case MatchStatsPublicationState.preview:
      return StatsWorkflowStep.live;
    default:
      return StatsWorkflowStep.prepare;
  }
}

String statsWorkflowLabel(StatsWorkflowStep step) {
  switch (step) {
    case StatsWorkflowStep.prepare:
      return 'À saisir';
    case StatsWorkflowStep.live:
      return 'En direct';
    case StatsWorkflowStep.official:
      return 'Officiel';
  }
}

Color statsWorkflowColor(StatsWorkflowStep step) {
  switch (step) {
    case StatsWorkflowStep.prepare:
      return const Color(0xFF9E9E9E);
    case StatsWorkflowStep.live:
      return const Color(0xFF4A90D9);
    case StatsWorkflowStep.official:
      return const Color(0xFF4CAF50);
  }
}

String statsPrimaryAction(StatsWorkflowStep step) {
  switch (step) {
    case StatsWorkflowStep.prepare:
      return 'Commencer la saisie';
    case StatsWorkflowStep.live:
      return 'Continuer la saisie';
    case StatsWorkflowStep.official:
      return 'Voir les stats';
  }
}

/// Libellé de section pour l’historique groupé.
String statsHistorySectionLabel(AdminMatchRowData row) {
  final rank = statsCompetitionSortRank(row.d['competition'] as String?);
  switch (rank) {
    case 0:
      return row.competition;
    case 1:
      return 'Coupes';
    case 2:
      return 'Matchs amicaux';
    default:
      return 'Autres';
  }
}

/// Ordre d’affichage : championnat → coupes → amical → reste.
int statsCompetitionSortRank(String? competition) {
  if (MatchCompetition.isRegularSeason(competition)) return 0;
  if (MatchCompetition.isCup(competition)) return 1;
  if (MatchCompetition.isFriendly(competition)) return 2;
  return 3;
}

/// Tri liste stats : par date (récent d’abord) ; si [groupByCompetition], puis par type.
void sortStatsMatchRows(
  List<AdminMatchRowData> rows, {
  bool groupByCompetition = false,
}) {
  rows.sort((a, b) {
    if (groupByCompetition) {
      final ca = statsCompetitionSortRank(a.d['competition'] as String?);
      final cb = statsCompetitionSortRank(b.d['competition'] as String?);
      if (ca != cb) return ca.compareTo(cb);
      final la = MatchCompetition.displayLabel(a.d['competition'] as String?);
      final lb = MatchCompetition.displayLabel(b.d['competition'] as String?);
      final lc = la.compareTo(lb);
      if (lc != 0) return lc;
    }
    final da = a.matchDate;
    final db = b.matchDate;
    if (da == null && db == null) return b.t1.compareTo(a.t1);
    if (da == null) return 1;
    if (db == null) return -1;
    final byDate = db.compareTo(da);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  });
}

/// Libellé court pour l'état publication stats d'un match.
String statsPublicationLabel(Map<String, dynamic> matchData) =>
    statsWorkflowLabel(statsWorkflowStep(matchData));

/// Match déjà clôturé côté stats (officiel ou terminé) — va dans Archive.
bool isStatsSessionClosed(
  AdminMatchRowData row, {
  Map<String, Map<String, dynamic>> sheetsById = const {},
}) {
  final step = statsWorkflowStep(
    row.d,
    sheetState: sheetsById[row.id]?['state']?.toString(),
  );
  if (step == StatsWorkflowStep.official) return true;
  final status = (row.d['status'] as String? ?? '').toLowerCase();
  return status == 'finished';
}

/// Session active : live en cours sur ce match, ou aperçu récent (pas officiel).
AdminMatchRowData? pickStatsEnDirectSession(
  List<AdminMatchRowData> rows, {
  Map<String, Map<String, dynamic>> sheetsById = const {},
  String? liveMatchId,
}) {
  if (rows.isEmpty) return null;
  final now = DateTime.now();

  if (liveMatchId != null && liveMatchId.isNotEmpty) {
    for (final r in rows) {
      if (r.id == liveMatchId && !isStatsSessionClosed(r, sheetsById: sheetsById)) {
        return r;
      }
    }
  }

  AdminMatchRowData? bestPreview;
  Duration? bestDelta;
  for (final r in rows) {
    if (isStatsSessionClosed(r, sheetsById: sheetsById)) continue;
    final step = statsWorkflowStep(
      r.d,
      sheetState: sheetsById[r.id]?['state']?.toString(),
    );
    if (step != StatsWorkflowStep.live) continue;
    final dt = r.matchDate;
    if (dt == null) continue;
    final delta = now.difference(dt).abs();
    if (delta > const Duration(hours: 8)) continue;
    if (bestDelta == null || delta < bestDelta) {
      bestDelta = delta;
      bestPreview = r;
    }
  }
  return bestPreview;
}

/// Prochains matchs à venir — liste « En direct » avant coup d’envoi.
List<AdminMatchRowData> pickUpcomingStatsEntry(
  List<AdminMatchRowData> rows, {
  Map<String, Map<String, dynamic>> sheetsById = const {},
}) {
  final now = DateTime.now();
  final upcoming = rows.where((r) {
    if (isStatsSessionClosed(r, sheetsById: sheetsById)) return false;
    final status = (r.d['status'] as String? ?? 'upcoming').toLowerCase();
    if (status == 'finished' || status == 'live') return false;
    final dt = r.matchDate;
    if (dt == null) return false;
    return !dt.isBefore(now.subtract(const Duration(hours: 3)));
  }).toList();
  upcoming.sort((a, b) {
    final da = a.matchDate ?? now;
    final db = b.matchDate ?? now;
    return da.compareTo(db);
  });
  return upcoming;
}

/// @deprecated Utiliser [pickStatsEnDirectSession].
AdminMatchRowData? pickLiveMatchCandidate(List<AdminMatchRowData> rows) =>
    pickStatsEnDirectSession(rows);

/// Matchs récents pour l'onglet Live (±7 jours).
List<AdminMatchRowData> filterRecentLiveRows(
  List<AdminMatchRowData> rows, {
  int limit = 10,
}) {
  final now = DateTime.now();
  const window = Duration(days: 7);
  final recent = rows.where((r) {
    final dt = r.matchDate;
    if (dt == null) return false;
    return dt.difference(now).abs() <= window;
  }).toList();
  recent.sort((a, b) {
    final da = a.matchDate ?? DateTime(1970);
    final db = b.matchDate ?? DateTime(1970);
    return db.compareTo(da);
  });
  return recent.take(limit).toList();
}

/// Moyenne saison Sedan pour l'encart Saison.
class SedanSeasonAverage {
  const SedanSeasonAverage({
    required this.label,
    required this.value,
    required this.count,
  });

  final String label;
  final String value;
  final int count;
}

const _seasonStatKeys = [
  ('possession1', 'possession2', 'Poss %'),
  ('tirs1', 'tirs2', 'Tirs'),
  ('tirsCadres1', 'tirsCadres2', 'Cadrés'),
  ('passes1', 'passes2', 'Passes'),
  ('corners1', 'corners2', 'Corners'),
  ('fautes1', 'fautes2', 'Fautes'),
  ('duelWon1', 'duelWon2', 'Duels'),
];

/// Buts / cartons Sedan cumulés sur la sélection de matchs (stats tab).
Map<String, Map<String, int>> aggregateSedanPlayerFacts(
  List<AdminMatchRowData> rows,
) {
  final total = <String, Map<String, int>>{};
  for (final row in rows) {
    final events = MatchStatsSchema.eventsFromMatchDoc(row.d);
    for (final entry
        in MatchStatsSchema.sedanPlayerFacts(events, row.t1, row.t2).entries) {
      final acc = total.putIfAbsent(entry.key, () => <String, int>{});
      for (final kv in entry.value.entries) {
        acc[kv.key] = (acc[kv.key] ?? 0) + kv.value;
      }
    }
  }
  return total;
}

List<SedanSeasonAverage> computeSedanSeasonAverages(
  List<AdminMatchRowData> rows,
) {
  final withStats = rows.where((r) => r.hasStats).toList();
  if (withStats.isEmpty) return [];

  return _seasonStatKeys.map((keys) {
    final values = <double>[];
    for (final row in withStats) {
      final v = row.sedanStat(keys.$1, keys.$2);
      if (v != null) values.add(v.toDouble());
    }
    if (values.isEmpty) {
      return SedanSeasonAverage(label: keys.$3, value: '-', count: 0);
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    final formatted = keys.$3 == 'Poss %'
        ? '${avg.round()}%'
        : avg == avg.roundToDouble()
            ? '${avg.round()}'
            : avg.toStringAsFixed(1);
    return SedanSeasonAverage(
      label: keys.$3,
      value: formatted,
      count: values.length,
    );
  }).toList();
}
