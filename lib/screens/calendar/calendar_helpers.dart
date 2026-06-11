import '../../models/match_model.dart';
import '../../utils/match_competition.dart';

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
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String matchSubtitle(MatchModel match) {
  if (match.status == MatchStatus.finished) {
    return 'Resultat final';
  }
  if (match.status == MatchStatus.live) {
    return 'Rencontre en direct';
  }
  return 'Coup d envoi programme';
}
