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

  const PronoMatchListItem({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.competition,
    this.logo1,
    this.logo2,
    this.status = 'upcoming',
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
    );
  }
}
