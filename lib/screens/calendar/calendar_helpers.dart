import '../../models/match_model.dart';

enum CalendarViewMode { upcoming, results }

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
  if (mode == CalendarViewMode.upcoming) {
    return match.status != MatchStatus.finished;
  }
  return match.status == MatchStatus.finished;
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
