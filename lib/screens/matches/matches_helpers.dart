import '../../models/match_model.dart';

enum MatchesViewMode { upcoming, results }

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String matchTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String shortDateLabel(DateTime date) {
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

String compactDateLabel(DateTime date) {
  const weekdays = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
  const months = [
    'JAN',
    'FÉV',
    'MAR',
    'AVR',
    'MAI',
    'JUI',
    'JUL',
    'AOÛ',
    'SEP',
    'OCT',
    'NOV',
    'DÉC',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
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
      ..sort(
        (a, b) =>
            descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
      );
    ordered[key] = dayMatches;
  }
  return ordered;
}
