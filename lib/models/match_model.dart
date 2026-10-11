import 'package:cloud_firestore/cloud_firestore.dart';

import 'match_stats_schema.dart';
import '../utils/match_competition.dart';

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
  final String? rank1; // ex: "6"
  final String? rank2; // ex: "10"
  final String? form1; // ex: "WWDDLW"
  final String? form2; // ex: "LWLWW"
  final String? wdl1; // ex: "12V 3N 4D"
  final String? wdl2; // ex: "8V 5N 6D"
  final String? stadiumImageUrl; // Photo du stade domicile

  /// Stade / lieu (FFF + admin). Aussi stocké Firestore sous `stadium`.
  final String? lieu;

  /// Ville du match (FFF + admin). Aussi stocké Firestore sous `city`.
  final String? ville;

  /// Alias anglais éventuel (sync FFF écrit `ville` + `city`).
  final String? city;

  /// Adresse complète saisie à la main (admin) — prioritaire pour « Y aller ».
  final String? adresse;

  /// Si vrai et statut [MatchStatus.upcoming], scores / stats peuvent s’afficher (publication anticipée).
  final bool earlyPublish;

  /// État publication stats : `none` | `draft` | `preview` | `published`.
  final String? statsState;

  /// Legacy : affichage forcé des stats sur cartes (dérivé de [statsState] si absent).
  final bool? showStats;

  /// Saison FFF
  final String? fffSeason;

  /// Fiche créée / modifiée à la main dans l’admin (pas uniquement sync FFF).
  final bool manual;

  /// Retransmission (fiche match + radio). `false` = match non retransmis.
  /// Absent en Firestore = retransmis (logos club si les URLs réseaux existent).
  final bool streamBroadcast;

  /// Score Firestore : int, double, String, ou champs alternatifs homeScore/awayScore (Cloud Functions).
  static int? parseScoreField(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }
    return null;
  }

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
    this.wdl1,
    this.wdl2,
    this.stadiumImageUrl,
    this.lieu,
    this.ville,
    this.city,
    this.adresse,
    this.earlyPublish = false,
    this.statsState,
    this.showStats,
    this.fffSeason,
    this.manual = false,
    this.streamBroadcast = true,
  });

  bool get showStatsOnCard =>
      MatchStatsSchema.visibilityFromMatchDoc({
        'statsState': statsState,
        'stats': stats,
        'showStats': showStats,
        'earlyPublish': earlyPublish,
        'status': status.name,
      }) !=
      MatchStatsVisibility.hidden;

  /// Forme + rang au classement (carte accueil) — championnat uniquement.
  bool get showsLeagueContextOnCard =>
      MatchCompetition.isRegularSeason(competition);

  bool get isSedanHome {
    final t1 = team1.toUpperCase();
    return t1.contains('SEDAN') || t1.contains('CSSA');
  }

  /// Ville pour météo : `ville`/`city`, sinon Sedan si domicile CSSA.
  String? resolveWeatherCity() {
    final explicit = (ville ?? city)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (isSedanHome) return 'Sedan';
    return null;
  }

  bool get kickoffHasPassed => !date.isAfter(DateTime.now());

  /// Calendrier : score / « terminé » dès le coup d’envoi passé (hors live).
  bool get displaysAsFinished =>
      status == MatchStatus.finished ||
      (status != MatchStatus.live && kickoffHasPassed);

  /// Statut affiché : un match passé avec score n’est plus « à venir ».
  static MatchStatus resolveDisplayStatus({
    required String? rawStatus,
    required DateTime date,
    int? score1,
    int? score2,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    MatchStatus status;
    switch ((rawStatus ?? '').trim().toLowerCase()) {
      case 'live':
        status = MatchStatus.live;
        break;
      case 'finished':
        status = MatchStatus.finished;
        break;
      default:
        status = MatchStatus.upcoming;
    }
    if (status == MatchStatus.finished && date.isAfter(t)) {
      return MatchStatus.upcoming;
    }
    if (status == MatchStatus.upcoming &&
        !date.isAfter(t) &&
        score1 != null &&
        score2 != null) {
      return MatchStatus.finished;
    }
    return status;
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final date = (d['date'] as Timestamp).toDate();
    final rawS1 = d['score1'] ?? d['homeScore'];
    final rawS2 = d['score2'] ?? d['awayScore'];
    final parsed1 = parseScoreField(rawS1);
    final parsed2 = parseScoreField(rawS2);
    final status = resolveDisplayStatus(
      rawStatus: d['status']?.toString(),
      date: date,
      score1: parsed1,
      score2: parsed2,
    );
    final earlyPublish = d['earlyPublish'] == true;
    final hideScores =
        status == MatchStatus.upcoming && date.isAfter(DateTime.now()) && !earlyPublish;
    return MatchModel(
      id: doc.id,
      team1: d['team1'] ?? 'Équipe 1',
      team2: d['team2'] ?? 'Équipe 2',
      logo1: d['logo1'],
      logo2: d['logo2'],
      score1: hideScores ? null : parsed1,
      score2: hideScores ? null : parsed2,
      date: date,
      competition: d['competition'] ?? 'Championnat',
      status: status,
      replayVideoId: d['replayVideoId'],
      stats: d['stats'] as Map<String, dynamic>?,
      rank1: d['rank1']?.toString(),
      rank2: d['rank2']?.toString(),
      form1: d['form1']?.toString(),
      form2: d['form2']?.toString(),
      wdl1: d['wdl1']?.toString(),
      wdl2: d['wdl2']?.toString(),
      stadiumImageUrl: d['stadiumImageUrl']?.toString(),
      lieu: (d['lieu'] ?? d['stadium'])?.toString(),
      ville: (d['ville'] ?? d['city'])?.toString(),
      city: d['city']?.toString(),
      adresse: d['adresse']?.toString(),
      earlyPublish: earlyPublish,
      statsState: d['statsState']?.toString(),
      showStats: d['showStats'] as bool?,
      fffSeason: d['fffSeason']?.toString(),
      manual: d['manual'] == true,
      streamBroadcast: d['streamBroadcast'] != false,
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
    'wdl1': wdl1,
    'wdl2': wdl2,
    'stadiumImageUrl': stadiumImageUrl,
    'lieu': lieu,
    'ville': ville,
    'city': city,
    'adresse': adresse,
    'earlyPublish': earlyPublish,
    'statsState': statsState,
    'showStats': showStats,
    'fffSeason': fffSeason,
    'streamBroadcast': streamBroadcast,
  };

  factory MatchModel.fromJson(Map<String, dynamic> d) {
    final date = DateTime.parse(d['date']);
    final parsed1 = parseScoreField(d['score1'] ?? d['homeScore']);
    final parsed2 = parseScoreField(d['score2'] ?? d['awayScore']);
    final status = resolveDisplayStatus(
      rawStatus: d['status']?.toString(),
      date: date,
      score1: parsed1,
      score2: parsed2,
    );
    final earlyPublish = d['earlyPublish'] == true;
    final hideScores =
        status == MatchStatus.upcoming && date.isAfter(DateTime.now()) && !earlyPublish;
    return MatchModel(
      id: d['id'] ?? '',
      team1: d['team1'] ?? '',
      team2: d['team2'] ?? '',
      logo1: d['logo1'],
      logo2: d['logo2'],
      score1: hideScores ? null : parsed1,
      score2: hideScores ? null : parsed2,
      date: date,
      competition: d['competition'] ?? '',
      status: status,
      replayVideoId: d['replayVideoId'],
      stats: d['stats'] != null ? Map<String, dynamic>.from(d['stats']) : null,
      rank1: d['rank1'],
      rank2: d['rank2'],
      form1: d['form1'],
      form2: d['form2'],
      wdl1: d['wdl1'],
      wdl2: d['wdl2'],
      stadiumImageUrl: d['stadiumImageUrl'],
      lieu: d['lieu'] ?? d['stadium'],
      ville: d['ville'] ?? d['city'],
      city: d['city'],
      adresse: d['adresse']?.toString(),
      earlyPublish: earlyPublish,
      statsState: d['statsState']?.toString(),
      showStats: d['showStats'] as bool?,
      fffSeason: d['fffSeason']?.toString(),
      manual: d['manual'] == true,
      streamBroadcast: d['streamBroadcast'] != false,
    );
  }

  // ── Mock data ──────────────────────────────────────────────────────────
  static List<MatchModel> mockUpcoming = [
    MatchModel(
      id: 'm1',
      team1: 'CSSA',
      team2: 'AS Montélimar',
      date: DateTime.now().add(const Duration(days: 3, hours: 14)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
      rank1: '6',
      rank2: '10',
      form1: 'WWDDLW',
      form2: 'LWLWW',
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
      id: 'm1',
      team1: 'SEDAN ARDENNES CS',
      team2: 'Bogny FC',
      date: DateTime.now().add(const Duration(days: 3, hours: 20)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm2',
      team1: 'Sarreguemines FC',
      team2: 'Amnéville CSO',
      date: DateTime.now().add(const Duration(days: 3, hours: 18)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm3',
      team1: 'Forbach FC',
      team2: 'CS Obernai',
      date: DateTime.now().add(const Duration(days: 3, hours: 15)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm4',
      team1: 'AS Yutz',
      team2: 'Laxou FC',
      date: DateTime.now().add(const Duration(days: 3, hours: 15)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm5',
      team1: 'SEDAN ARDENNES CS',
      team2: 'Sarreguemines FC',
      date: DateTime.now().add(const Duration(days: 10, hours: 20)),
      competition: 'Coupe Régionale',
      status: MatchStatus.upcoming,
    ),
    MatchModel(
      id: 'm6',
      team1: 'Amnéville CSO',
      team2: 'Forbach FC',
      date: DateTime.now().add(const Duration(days: 17, hours: 15)),
      competition: 'Régional 1',
      status: MatchStatus.upcoming,
    ),
  ];

}
