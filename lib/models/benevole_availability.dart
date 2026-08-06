import 'package:cloud_firestore/cloud_firestore.dart';

import 'benevole_posts.dart';

/// Réponse dispo bénévole — `benevole_responses/{matchId}_{uid}`.
class BenevoleAvailabilityResponse {
  final String id;
  final String matchId;
  final String uid;
  final String email;
  final String statutPresence;
  final String voeu1;
  final String voeu2;
  final String voeu3;
  final DateTime? submittedAt;
  final bool makeOk;

  const BenevoleAvailabilityResponse({
    required this.id,
    required this.matchId,
    required this.uid,
    required this.email,
    required this.statutPresence,
    this.voeu1 = '',
    this.voeu2 = '',
    this.voeu3 = '',
    this.submittedAt,
    this.makeOk = false,
  });

  factory BenevoleAvailabilityResponse.fromFirestore(
    String id,
    Map<String, dynamic> d,
  ) {
    DateTime? ts;
    final raw = d['submittedAt'] ?? d['updatedAt'];
    if (raw is Timestamp) ts = raw.toDate();
    return BenevoleAvailabilityResponse(
      id: id,
      matchId: (d['matchId'] ?? '').toString(),
      uid: (d['uid'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      statutPresence:
          (d['statutPresence'] ?? BenevolePresenceStatus.present).toString(),
      voeu1: (d['voeu1'] ?? '').toString(),
      voeu2: (d['voeu2'] ?? '').toString(),
      voeu3: (d['voeu3'] ?? '').toString(),
      submittedAt: ts,
      makeOk: d['makeOk'] == true,
    );
  }
}

/// Match enrichi pour le formulaire bénévoles.
class BenevoleMatchCard {
  final String matchId;
  final String team1;
  final String team2;
  final DateTime date;
  final String competition;
  final String benevoleType;
  final String lieu;
  final String ville;
  final String adresse;
  final String domicileExterieur;
  final String? briefUrl;
  final bool formOpen;

  const BenevoleMatchCard({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.date,
    required this.competition,
    required this.benevoleType,
    required this.lieu,
    required this.ville,
    required this.adresse,
    required this.domicileExterieur,
    this.briefUrl,
    required this.formOpen,
  });

  String get nomEvenement => '$team1 vs $team2';

  /// Jours restants avant le coup d’envoi (calendrier local, jour entier).
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final kick = DateTime(date.year, date.month, date.day);
    return kick.difference(today).inDays;
  }

  /// Fenêtre ouverte : J-20 inclus → J-6 inclus.
  static bool isFormOpenFor(DateTime matchDate, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final kick = DateTime(matchDate.year, matchDate.month, matchDate.day);
    final days = kick.difference(today).inDays;
    return days >= 6 && days <= 20;
  }

  /// Visible dans la liste : de J-20 jusqu’au match (brief après J-6).
  static bool isVisibleFor(DateTime matchDate, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final kick = DateTime(matchDate.year, matchDate.month, matchDate.day);
    final days = kick.difference(today).inDays;
    return days >= 0 && days <= 20;
  }
}
