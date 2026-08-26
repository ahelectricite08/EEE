import '../../models/match_model.dart';

enum MatchesViewMode { upcoming, results }

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Jours calendaires entre aujourd’hui (minuit local) et [date] (minuit local).
int calendarDaysFromToday(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  return day.difference(today).inDays;
}

String matchTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Mois FR courts et lisibles — jamais 3 lettres pour août / juin / juillet.
const kFrenchMonthShort = [
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

const kFrenchMonthFull = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String frenchMonthShort(DateTime date) => kFrenchMonthShort[date.month - 1];

String frenchMonthFull(DateTime date) => kFrenchMonthFull[date.month - 1];

String shortDateLabel(DateTime date) {
  const weekdays = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${frenchMonthShort(date)}';
}

String compactDateLabel(DateTime date) {
  const weekdays = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${frenchMonthShort(date).toUpperCase()}';
}

String longDateLabel(DateTime date) {
  const weekdays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${weekdays[date.weekday - 1]} ${date.day} ${frenchMonthFull(date)} · ${hh}h$mm';
}

String sectionDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final current = DateTime(date.year, date.month, date.day);
  final diff = current.difference(today).inDays;
  if (diff == 0) return "AUJOURD'HUI";
  if (diff == 1) return 'DEMAIN';
  if (diff == -1) return 'HIER';
  return compactDateLabel(date);
}

bool isSedanTeam(String team) {
  final upper = team.toUpperCase();
  return upper.contains('SEDAN') || upper.contains('CSSA');
}

/// Même détection que les cartes CSSA (`isSedanTeam` sur les deux clubs).
bool isSedanMatch(MatchModel match) =>
    isSedanTeam(match.team1) || isSedanTeam(match.team2);

/// Dans une même journée : Sedan d’abord, puis heure, puis noms.
int compareMatchesWithinDay(
  MatchModel a,
  MatchModel b, {
  required bool descending,
}) {
  final aSedan = isSedanMatch(a);
  final bSedan = isSedanMatch(b);
  if (aSedan != bSedan) return aSedan ? -1 : 1;

  final byTime =
      descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date);
  if (byTime != 0) return byTime;

  final nameA = '${a.team1} ${a.team2}'.toUpperCase();
  final nameB = '${b.team1} ${b.team2}'.toUpperCase();
  final byName = nameA.compareTo(nameB);
  return descending ? -byName : byName;
}

String normalizeTeamLabel(String value) {
  return value
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Ë', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Ä', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Ö', 'O')
      .replaceAll('Ù', 'U')
      .replaceAll('Û', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ç', 'C')
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim();
}

bool teamMatchesPreference(String candidate, String? preference) {
  if (preference == null || preference.trim().isEmpty) {
    return false;
  }
  final normalizedCandidate = normalizeTeamLabel(candidate);
  final normalizedPreference = normalizeTeamLabel(preference);
  if (normalizedCandidate.isEmpty || normalizedPreference.isEmpty) {
    return false;
  }
  if (isSedanTeam(normalizedCandidate) && isSedanTeam(normalizedPreference)) {
    return true;
  }
  return normalizedCandidate == normalizedPreference ||
      normalizedCandidate.contains(normalizedPreference) ||
      normalizedPreference.contains(normalizedCandidate);
}

bool matchIncludesPreferredTeam(MatchModel match, String? preference) {
  return teamMatchesPreference(match.team1, preference) ||
      teamMatchesPreference(match.team2, preference);
}

String competitionShortLabel(String competition) {
  final label = competition.trim();
  if (label.length <= 22) return label;
  return '${label.substring(0, 22)}...';
}

String rankingLeagueLabel(String season) {
  switch (season) {
    case '2025-2026':
      return 'Regional 1 · Grand Est';
    case '2026-2027':
      return 'Saison suivante · Grand Est';
    default:
      return 'Grand Est';
  }
}

String teamInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (name.isEmpty) return '--';
  return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
}

Map<DateTime, List<MatchModel>> groupMatchesByDay(
  List<MatchModel> matches, {
  required bool descending,
}) {
  final groups = <DateTime, List<MatchModel>>{};
  for (final match in matches) {
    final day = DateTime(match.date.year, match.date.month, match.date.day);
    groups.putIfAbsent(day, () => []).add(match);
  }

  final sortedKeys = groups.keys.toList()
    ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
  final ordered = <DateTime, List<MatchModel>>{};
  for (final key in sortedKeys) {
    final dayMatches = groups[key]!
      ..sort((a, b) => compareMatchesWithinDay(a, b, descending: descending));
    ordered[key] = dayMatches;
  }
  return ordered;
}
