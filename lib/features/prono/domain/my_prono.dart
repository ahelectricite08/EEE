import 'package:flutter/foundation.dart';

/// Prono déjà posé par l’utilisateur (accueil « Mes pronos »).
@immutable
class MyPronoItem {
  final String matchId;
  final String team1;
  final String team2;
  final DateTime matchDate;
  final int predHome;
  final int predAway;
  final int? resHome;
  final int? resAway;
  /// `null` = pas encore scoré.
  final int? points;
  /// Journée / round FFF si le doc le porte.
  final int? journee;
  final String? logo1;
  final String? logo2;
  final String? competition;

  const MyPronoItem({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.matchDate,
    required this.predHome,
    required this.predAway,
    this.resHome,
    this.resAway,
    this.points,
    this.journee,
    this.logo1,
    this.logo2,
    this.competition,
  });

  String get pointsLabel {
    final p = points;
    if (p == null) return 'en att.';
    if (p > 0) return '+$p';
    return '0';
  }

  bool get isPending => points == null;

  bool get hasResult => resHome != null && resAway != null;

  String get verdictLabel {
    final p = points;
    if (p == null) return 'En attente';
    if (p >= 3) return 'Score exact';
    if (p == 1) return 'Bon résultat';
    return 'À côté';
  }
}

@immutable
class MyPronoGroup {
  final String label;
  final List<MyPronoItem> items;

  const MyPronoGroup({required this.label, required this.items});
}

int? parsePronoJournee(Map<String, dynamic>? data) {
  if (data == null) return null;
  const keys = [
    'journee',
    'fffJournee',
    'fffDay',
    'matchday',
    'dayNumber',
  ];
  for (final k in keys) {
    final n = _positiveInt(data[k]);
    if (n != null) return n;
  }
  return null;
}

int? _positiveInt(dynamic v) {
  if (v == null) return null;
  int? n;
  if (v is int) {
    n = v;
  } else if (v is num) {
    n = v.round();
  } else {
    n = int.tryParse(v.toString().trim());
  }
  if (n == null || n <= 0) return null;
  return n;
}

String frenchRankLabel(int rank) => rank == 1 ? '1er' : '${rank}e';

/// Groupe par journée si au moins un item a [MyPronoItem.journee], sinon par date.
List<MyPronoGroup> groupMyPronos(
  List<MyPronoItem> items, {
  String Function(DateTime date)? dateLabel,
}) {
  if (items.isEmpty) return const [];
  final sorted = [...items]
    ..sort((a, b) => b.matchDate.compareTo(a.matchDate));
  final hasRound = sorted.any((e) => e.journee != null);

  if (hasRound) {
    final buckets = <int, List<MyPronoItem>>{};
    final leftover = <MyPronoItem>[];
    for (final e in sorted) {
      final j = e.journee;
      if (j == null) {
        leftover.add(e);
        continue;
      }
      (buckets[j] ??= []).add(e);
    }
    final keys = buckets.keys.toList()
      ..sort((a, b) {
        final da = buckets[a]!.first.matchDate;
        final db = buckets[b]!.first.matchDate;
        return db.compareTo(da);
      });
    final out = <MyPronoGroup>[
      for (final k in keys)
        MyPronoGroup(label: 'Journée $k', items: buckets[k]!),
    ];
    if (leftover.isNotEmpty) {
      out.addAll(_groupsByDate(leftover, dateLabel));
    }
    return out;
  }

  return _groupsByDate(sorted, dateLabel);
}

DateTime _calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _groupNewest(MyPronoGroup g) =>
    g.items.map((e) => e.matchDate).reduce((a, b) => a.isAfter(b) ? a : b);

/// Accueil : la dernière journée **jouée** (scorée, avec score, ou déjà sifflée).
/// Les journées encore à venir restent dans « Voir plus ».
MyPronoGroup? latestPlayedMyPronoJournee(
  List<MyPronoItem> items, {
  String Function(DateTime date)? dateLabel,
  DateTime? now,
}) {
  if (items.isEmpty) return null;
  final t = now ?? DateTime.now();
  final played = items.where((e) {
    if (!e.isPending || e.hasResult) return true;
    return !t.isBefore(e.matchDate);
  }).toList();
  final pool = played.isNotEmpty ? played : items;
  final groups = groupMyPronos(pool, dateLabel: dateLabel);
  if (groups.isEmpty) return null;

  var newest = groups.first;
  var newestDate = _groupNewest(newest);
  for (final g in groups.skip(1)) {
    final d = _groupNewest(g);
    if (d.isAfter(newestDate)) {
      newest = g;
      newestDate = d;
    }
  }

  final hasRound = pool.any((e) => e.journee != null);
  if (hasRound) return newest;

  final latestDay = _calendarDay(newestDate);
  final merged = <MyPronoItem>[];
  for (final g in groups) {
    final d = _calendarDay(_groupNewest(g));
    if (latestDay.difference(d).inDays <= 1) {
      merged.addAll(g.items);
    }
  }
  merged.sort((a, b) => b.matchDate.compareTo(a.matchDate));
  return MyPronoGroup(label: newest.label, items: merged);
}

bool hasOlderMyPronoJournees(
  List<MyPronoItem> items, {
  String Function(DateTime date)? dateLabel,
  DateTime? now,
}) {
  final latest = latestPlayedMyPronoJournee(
    items,
    dateLabel: dateLabel,
    now: now,
  );
  if (latest == null) return false;
  final ids = latest.items.map((e) => e.matchId).toSet();
  return items.any((e) => !ids.contains(e.matchId));
}

List<MyPronoGroup> _groupsByDate(
  List<MyPronoItem> items,
  String Function(DateTime date)? dateLabel,
) {
  final buckets = <String, List<MyPronoItem>>{};
  final order = <String>[];
  for (final e in items) {
    final d = e.matchDate;
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = [];
    }
    buckets[key]!.add(e);
  }
  return [
    for (final k in order)
      MyPronoGroup(
        label: dateLabel?.call(buckets[k]!.first.matchDate) ?? k,
        items: buckets[k]!,
      ),
  ];
}
