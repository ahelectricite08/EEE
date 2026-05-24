import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/match_stats_schema.dart';

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
  final bool hasStats;
  final List<Map<String, dynamic>> goals;
  final String goalStr;
  final int yH;
  final int yA;
  final int rH;
  final int rA;

  String get id => doc.id;

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

  factory AdminMatchRowData.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final s = d['stats'] as Map<String, dynamic>? ?? {};
    final t1 = (d['team1'] as String? ?? '');
    final t2 = (d['team2'] as String? ?? '');
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final date = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : '-';
    final score = '${d['scoreHome'] ?? '-'}-${d['scoreAway'] ?? '-'}';
    final hasStats = s.isNotEmpty;
    final rawEvents = d['events'];
    final goals = rawEvents is List
        ? rawEvents
              .whereType<Map<String, dynamic>>()
              .where((e) => e['type'] == 'goal')
              .toList()
        : <Map<String, dynamic>>[];
    final goalStr = goals.isEmpty
        ? '-'
        : goals
              .map((e) {
                final p = (e['player'] as String? ?? '').split(' ').last;
                final m = e['minute'] ?? '?';
                return '$p $m\'';
              })
              .join('  ');
    final yH =
        (d['yellowHome'] as int?) ?? (d['yellow_home'] as int?) ?? 0;
    final yA =
        (d['yellowAway'] as int?) ?? (d['yellow_away'] as int?) ?? 0;
    final rH = (d['redHome'] as int?) ?? (d['red_home'] as int?) ?? 0;
    final rA = (d['redAway'] as int?) ?? (d['red_away'] as int?) ?? 0;
    return AdminMatchRowData(
      doc: doc,
      d: d,
      s: s,
      t1: t1,
      t2: t2,
      date: date,
      score: score,
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

StatsWorkflowStep statsWorkflowStep(Map<String, dynamic> matchData) {
  final state = MatchStatsPublicationState.fromFirestore(
    matchData['statsState']?.toString(),
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

/// Libellé court pour l'état publication stats d'un match.
String statsPublicationLabel(Map<String, dynamic> matchData) =>
    statsWorkflowLabel(statsWorkflowStep(matchData));

/// Match Sedan candidat pour la saisie live (fenêtre ±48 h, alignée CF).
AdminMatchRowData? pickLiveMatchCandidate(List<AdminMatchRowData> rows) {
  if (rows.isEmpty) return null;
  final now = DateTime.now();
  const window = Duration(hours: 48);

  bool inWindow(AdminMatchRowData r) {
    final dt = r.matchDate;
    if (dt == null) return false;
    return dt.difference(now).abs() <= window;
  }

  int priority(AdminMatchRowData r) {
    final state = MatchStatsPublicationState.fromFirestore(
      r.d['statsState']?.toString(),
    );
    if (state == MatchStatsPublicationState.preview) return 0;
    if (state == MatchStatsPublicationState.draft && r.hasStats) return 1;
    if (state == MatchStatsPublicationState.draft) return 2;
    if (state == MatchStatsPublicationState.none) return 3;
    return 4; // published — last resort in live window
  }

  final candidates = rows.where(inWindow).toList();
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final pa = priority(a);
    final pb = priority(b);
    if (pa != pb) return pa.compareTo(pb);
    final da = a.matchDate ?? DateTime(1970);
    final db = b.matchDate ?? DateTime(1970);
    return da.difference(now).abs().compareTo(db.difference(now).abs());
  });
  return candidates.first;
}

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
