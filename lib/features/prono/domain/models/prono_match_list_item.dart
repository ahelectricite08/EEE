import 'package:cloud_firestore/cloud_firestore.dart';

/// Match affichable dans le feed prono (couche domaine).
class PronoMatchListItem {
  final String id;
  final String team1;
  final String team2;
  final DateTime date;
  final String competition;
  final String? logo1;
  final String? logo2;
  final String status;
  final int? score1;
  final int? score2;

  const PronoMatchListItem({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.competition,
    this.logo1,
    this.logo2,
    this.status = 'upcoming',
    this.score1,
    this.score2,
  });

  factory PronoMatchListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = d['date'];
    DateTime when;
    if (raw is Timestamp) {
      when = raw.toDate();
    } else {
      when = DateTime.now();
    }
    return PronoMatchListItem(
      id: doc.id,
      team1: (d['team1'] ?? '').toString(),
      team2: (d['team2'] ?? '').toString(),
      date: when,
      competition: (d['competition'] ?? 'Championnat').toString(),
      logo1: d['logo1'] as String?,
      logo2: d['logo2'] as String?,
      status: (d['status'] ?? 'upcoming').toString(),
      score1: _score(d['score1'] ?? d['homeScore']),
      score2: _score(d['score2'] ?? d['awayScore']),
    );
  }
}

int? _score(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString().trim());
}

/// Même affiche le même jour : une seule carte prono (fiche FFF prioritaire).
String pronoFixtureDedupeKey(PronoMatchListItem item) {
  final d = item.date;
  final t1 = item.team1.trim().toLowerCase();
  final t2 = item.team2.trim().toLowerCase();
  final pair = t1.compareTo(t2) <= 0 ? '$t1|$t2' : '$t2|$t1';
  return '$pair|${item.competition.trim().toLowerCase()}|${d.year}|${d.month}|${d.day}';
}

bool preferFffPronoMatch(PronoMatchListItem candidate, PronoMatchListItem current) {
  final candFff = candidate.id.startsWith('fff_');
  final curFff = current.id.startsWith('fff_');
  if (candFff && !curFff) return true;
  if (curFff && !candFff) return false;
  final candScore = candidate.score1 != null && candidate.score2 != null;
  final curScore = current.score1 != null && current.score2 != null;
  if (candScore && !curScore) return true;
  if (curScore && !candScore) return false;
  return candidate.id.compareTo(current.id) > 0;
}
