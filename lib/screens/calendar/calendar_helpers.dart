import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/match_model.dart';
import '../../utils/match_competition.dart';
import '../matches/matches_helpers.dart' show frenchMonthShort, isSedanTeam;

enum CalendarViewMode { upcoming, results }

/// Clé filtre compétition (libellé canonique, ex. « MATCH AMICAL »).
String calendarCompetitionKey(MatchModel match) =>
    MatchCompetition.displayLabel(match.competition).toUpperCase();

/// Puces compétition : TOUT + catégories présentes dans le mois / mode courant.
String calendarCompetitionChipLabel(String key) {
  if (key == 'TOUT') return 'Tout';
  for (final label in MatchCompetition.all) {
    if (label.toUpperCase() == key.toUpperCase()) return label;
  }
  if (key.isEmpty) return key;
  return key[0].toUpperCase() + key.substring(1).toLowerCase();
}

List<String> calendarCompetitionChips(Iterable<String> fromMatches) {
  final present = fromMatches.map((s) => s.toUpperCase()).toSet();
  final ordered = <String>['TOUT'];
  for (final label in MatchCompetition.all) {
    final key = label.toUpperCase();
    if (present.contains(key)) ordered.add(key);
  }
  final extras = present.where((k) => k != 'TOUT' && !ordered.contains(k)).toList()
    ..sort();
  ordered.addAll(extras);
  return ordered;
}

/// Aujourd'hui (date locale, sans heure).
DateTime _todayDateOnly() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day);
}

/// Tous les jours du mois [focus] sont strictement avant aujourd'hui.
bool isCalendarMonthFullyPast(DateTime focus) {
  final last = DateTime(focus.year, focus.month + 1, 0);
  return last.isBefore(_todayDateOnly());
}

/// Tous les jours du mois [focus] sont strictement après aujourd'hui.
bool isCalendarMonthFullyFuture(DateTime focus) {
  final first = DateTime(focus.year, focus.month, 1);
  return first.isAfter(_todayDateOnly());
}

bool matchesCalendarMode(MatchModel match, CalendarViewMode mode) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(match.date.year, match.date.month, match.date.day);

  if (mode == CalendarViewMode.upcoming) {
    if (match.status == MatchStatus.live) return true;
    if (match.status == MatchStatus.upcoming) {
      return !day.isBefore(today);
    }
    return false;
  }
  if (match.status == MatchStatus.finished) return true;
  if (match.status == MatchStatus.live) return true;
  // Manuel resté « à venir » alors que la date est passée → onglet résultats.
  if (match.manual && match.status == MatchStatus.upcoming && day.isBefore(today)) {
    return true;
  }
  return day.isBefore(today);
}

String timeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String weekdayShort(DateTime date) {
  const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return labels[date.weekday - 1];
}

String fullDateLabel(DateTime date) {
  const weekdays = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${frenchMonthShort(date)}';
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String matchSubtitle(MatchModel match) {
  if (match.status == MatchStatus.finished) {
    return 'Résultat final';
  }
  if (match.status == MatchStatus.live) {
    return 'Rencontre en direct';
  }
  return 'Coup d’envoi programmé';
}

/// Photo de stade déjà en data : champ match, sinon fiche équipe domicile.
String? embeddedStadiumUrl(MatchModel match) {
  final url = match.stadiumImageUrl?.trim();
  if (url != null && url.isNotEmpty) return url;
  return null;
}

Stream<String?> watchHomeStadiumImage(String teamName) {
  final name = teamName.trim();
  if (name.isEmpty) return Stream<String?>.value(null);
  return FirebaseFirestore.instance
      .collection('teams')
      .where('name', isEqualTo: name)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final url =
            (snapshot.docs.first.data()['stadiumImageUrl'] as String?)?.trim();
        return (url == null || url.isEmpty) ? null : url;
      });
}

/// Domicile CSSA = team1 Sedan. Extérieur = team2 Sedan.
String? sedanVenueStamp(MatchModel match) {
  if (isSedanTeam(match.team1)) return 'DOMICILE';
  if (isSedanTeam(match.team2)) return 'EXTÉRIEUR';
  return null;
}

/// Libellé fan sous le score, point de vue CSSA. Null si pas Sedan,
/// pas terminé, ou score manquant.
/// Le booléen Firestore `manual` (saisie admin) n’est jamais affiché ici.
String? sedanFanResultStamp(MatchModel match) {
  if (match.status != MatchStatus.finished) return null;
  final score1 = match.score1;
  final score2 = match.score2;
  if (score1 == null || score2 == null) return null;
  final home = isSedanTeam(match.team1);
  final away = isSedanTeam(match.team2);
  if (!home && !away) return null;
  final ours = home ? score1 : score2;
  final theirs = home ? score2 : score1;
  if (ours > theirs) return 'Victoire';
  if (ours == theirs) return 'Nul';
  return 'Défaite';
}

String? matchVenueLine(MatchModel match) {
  final lieu = match.lieu?.trim();
  final ville = (match.ville ?? match.city)?.trim();
  if (lieu != null && lieu.isNotEmpty && ville != null && ville.isNotEmpty) {
    return '$lieu  ·  $ville';
  }
  if (lieu != null && lieu.isNotEmpty) return lieu;
  if (ville != null && ville.isNotEmpty) return ville;
  return null;
}
