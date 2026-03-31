import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { upcoming, live, finished }

class MatchModel {
  final String id;
  final String team1;
  final String team2;
  final String? logo1;
  final String? logo2;
  final int? score1;
  final int? score2;
  final DateTime date;
  final String competition;
  final MatchStatus status;
  final String? replayVideoId; // YouTube ID
  final Map<String, dynamic>? stats;
  final String? rank1;   // ex: "6"
  final String? rank2;   // ex: "10"
  final String? form1;   // ex: "WWDDLW"
  final String? form2;   // ex: "LWLWW"

  MatchModel({
    required this.id,
    required this.team1,
    required this.team2,
    this.logo1,
    this.logo2,
    this.score1,
    this.score2,
    required this.date,
    required this.competition,
    required this.status,
    this.replayVideoId,
    this.stats,
    this.rank1,
    this.rank2,
    this.form1,
    this.form2,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    MatchStatus status;
    switch (d['status']) {
      case 'live':
        status = MatchStatus.live;
        break;
      case 'finished':
        status = MatchStatus.finished;
        break;
      default:
        status = MatchStatus.upcoming;
    }
    return MatchModel(
      id: doc.id,
      team1: d['team1'] ?? 'Équipe 1',
      team2: d['team2'] ?? 'Équipe 2',
      logo1: d['logo1'],
      logo2: d['logo2'],
      score1: d['score1'],
      score2: d['score2'],
      date: (d['date'] as Timestamp).toDate(),
      competition: d['competition'] ?? 'Championnat',
      status: status,
      replayVideoId: d['replayVideoId'],
      stats: d['stats'] as Map<String, dynamic>?,
      rank1: d['rank1']?.toString(),
      rank2: d['rank2']?.toString(),
      form1: d['form1']?.toString(),
      form2: d['form2']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'team1': team1,
    'team2': team2,
    'logo1': logo1,
    'logo2': logo2,
    'score1': score1,
    'score2': score2,
    'date': date.toIso8601String(),
    'competition': competition,
    'status': status.name,
    'replayVideoId': replayVideoId,
    'stats': stats,
    'rank1': rank1,
    'rank2': rank2,
    'form1': form1,
    'form2': form2,
  };

  factory MatchModel.fromJson(Map<String, dynamic> d) => MatchModel(
    id: d['id'] ?? '',
    team1: d['team1'] ?? '',
    team2: d['team2'] ?? '',
    logo1: d['logo1'],
    logo2: d['logo2'],
    score1: d['score1'],
    score2: d['score2'],
    date: DateTime.parse(d['date']),
    competition: d['competition'] ?? '',
    status: MatchStatus.values.firstWhere(
      (s) => s.name == d['status'], orElse: () => MatchStatus.upcoming),
    replayVideoId: d['replayVideoId'],
    stats: d['stats'] != null ? Map<String, dynamic>.from(d['stats']) : null,
    rank1: d['rank1'],
    rank2: d['rank2'],
    form1: d['form1'],
    form2: d['form2'],
  );

  // ── Mock data ──────────────────────────────────────────────────────────
  static List<MatchModel> mockUpcoming = [
    MatchModel(
      id: 'm1',
      team1: 'CSSA',
      team2: 'AS Montélimar',
      date: DateTime.now().add(const Duration(days: 3, hours: 14)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
      rank1: '6', rank2: '10',
      form1: 'WWDDLW', form2: 'LWLWW',
    ),
    MatchModel(
      id: 'm2',
      team1: 'Valence FC',
      team2: 'CSSA',
      date: DateTime.now().add(const Duration(days: 10, hours: 20)),
      competition: 'Coupe Régionale',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm3',
      team1: 'CSSA',
      team2: 'Oyonnax FC',
      date: DateTime.now().add(const Duration(days: 17, hours: 15)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
  ];

  /// Mock toutes équipes (pour le calendrier complet sans filtre Sedan)
  static List<MatchModel> mockAllUpcoming = [
    MatchModel(
      id: 'm1', team1: 'SEDAN ARDENNES CS', team2: 'Bogny FC',
      date: DateTime.now().add(const Duration(days: 3, hours: 20)),
      competition: 'Régional 1', status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm2', team1: 'Sarreguemines FC', team2: 'Amnéville CSO',
      date: DateTime.now().add(const Duration(days: 3, hours: 18)),
      competition: 'Régional 1', status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm3', team1: 'Forbach FC', team2: 'CS Obernai',
      date: DateTime.now().add(const Duration(days: 3, hours: 15)),
      competition: 'Régional 1', status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm4', team1: 'AS Yutz', team2: 'Laxou FC',
      date: DateTime.now().add(const Duration(days: 3, hours: 15)),
      competition: 'Régional 1', status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm5', team1: 'SEDAN ARDENNES CS', team2: 'Sarreguemines FC',
      date: DateTime.now().add(const Duration(days: 10, hours: 20)),
      competition: 'Coupe Régionale', status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm6', team1: 'Amnéville CSO', team2: 'Forbach FC',
      date: DateTime.now().add(const Duration(days: 17, hours: 15)),
      competition: 'Régional 1', status: MatchStatus.upcoming,
    ),
  ];

  static List<MatchModel> mockResults = [
    MatchModel(
      id: 'r1',
      team1: 'CSSA',
      team2: 'Romans SC',
      score1: 3,
      score2: 1,
      date: DateTime.now().subtract(const Duration(days: 4)),
      competition: 'Régional 1',
      status: MatchStatus.finished,
      replayVideoId: 'dQw4w9WgXcQ',
      stats: {
        'possession1': 58, 'possession2': 42,
        'tirs1': 14, 'tirs2': 8,
        'passes1': 412, 'passes2': 289,
        'corners1': 6, 'corners2': 3,
        'fautes1': 11, 'fautes2': 14,
      },
    ),
    MatchModel(
      id: 'r2',
      team1: 'Grenoble B',
      team2: 'CSSA',
      score1: 0,
      score2: 2,
      date: DateTime.now().subtract(const Duration(days: 11)),
      competition: 'Régional 1',
      status: MatchStatus.finished,
    ),
    MatchModel(
      id: 'r3',
      team1: 'CSSA',
      team2: 'Étoile Sportive',
      score1: 1,
      score2: 1,
      date: DateTime.now().subtract(const Duration(days: 18)),
      competition: 'Coupe Régionale',
      status: MatchStatus.finished,
    ),
  ];
}
