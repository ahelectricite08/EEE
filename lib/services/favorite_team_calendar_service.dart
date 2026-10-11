import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/fff_season_config.dart';
import '../models/match_model.dart';
import '../screens/matches/matches_helpers.dart';
import '../utils/match_device_calendar.dart';
import 'match_service.dart';
import 'user_preferences_service.dart';

enum FavoriteTeamCalendarStatus {
  webUnsupported,
  noFavoriteTeam,
  noUpcomingMatches,
  shared,
  cancelled,
  failed,
}

class FavoriteTeamCalendarOutcome {
  const FavoriteTeamCalendarOutcome({
    required this.status,
    this.count = 0,
    this.teamName,
  });

  final FavoriteTeamCalendarStatus status;
  final int count;
  final String? teamName;

  bool get mentionsPossibleDuplicates =>
      status == FavoriteTeamCalendarStatus.shared && count > 0;
}

/// Export des matchs à venir de l’équipe favorite vers le calendrier téléphone
/// (fichier .ics, même UID que [MatchDeviceCalendar]).
abstract final class FavoriteTeamCalendarService {
  FavoriteTeamCalendarService._();

  static String? normalizedFavoriteTeam(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static String currentSeasonLabel([DateTime? now]) =>
      FffSeasonConfig.frenchFootballSeasonLabel(now);

  static DateTime seasonStart(String seasonLabel) {
    final years = FffSeasonConfig.parseSeasonYears(seasonLabel);
    if (years == null) {
      final y = DateTime.now().year;
      return DateTime(y, 7, 1);
    }
    return DateTime(years.$1, 7, 1);
  }

  static DateTime seasonEndExclusive(String seasonLabel) {
    final years = FffSeasonConfig.parseSeasonYears(seasonLabel);
    if (years == null) {
      return DateTime(DateTime.now().year + 1, 7, 1);
    }
    return DateTime(years.$2, 7, 1);
  }

  /// Bornage requête : aujourd’hui → fin de saison (pas l’historique).
  static DateTime fetchStart({
    DateTime? now,
    required String seasonLabel,
  }) {
    final t = now ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    final start = seasonStart(seasonLabel);
    return today.isAfter(start) ? today : start;
  }

  static bool belongsToSeason(MatchModel match, String seasonLabel) {
    if (FffSeasonConfig.dateInSeason(match.date, seasonLabel)) return true;
    final fs = match.fffSeason?.trim();
    return fs != null && fs.isNotEmpty && fs == seasonLabel;
  }

  static bool isStillToPlay(MatchModel match, DateTime now) {
    if (match.status == MatchStatus.finished) return false;
    if (match.status == MatchStatus.live) return false;
    final matchDay = DateTime(match.date.year, match.date.month, match.date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (matchDay.isBefore(today)) return false;
    if (MatchDeviceCalendar.hasKnownKickoff(match.date) &&
        match.date.isBefore(now)) {
      return false;
    }
    return true;
  }

  static List<MatchModel> selectExportable({
    required Iterable<MatchModel> matches,
    required String favoriteTeam,
    required String seasonLabel,
    DateTime? now,
  }) {
    final team = normalizedFavoriteTeam(favoriteTeam);
    if (team == null) return const [];
    final t = now ?? DateTime.now();
    final out = matches.where((m) {
      if (!matchIncludesPreferredTeam(m, team)) return false;
      if (!belongsToSeason(m, seasonLabel)) return false;
      return isStillToPlay(m, t);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  static String successMessage(int count, {bool warnDuplicates = true}) {
    final n = count;
    final head = n <= 1
        ? '$n match ajouté au calendrier.'
        : '$n matchs ajoutés au calendrier.';
    if (!warnDuplicates) return head;
    return '$head Si des matchs étaient déjà là, tu peux avoir des doublons.';
  }

  static String emptyMessage(String team) =>
      'Aucun match à venir pour $team cette saison.';

  static Future<FavoriteTeamCalendarOutcome> exportToDevice(
    BuildContext context, {
    String? favoriteTeam,
    DateTime? now,
  }) async {
    if (kIsWeb) {
      return const FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.webUnsupported,
      );
    }

    final team = normalizedFavoriteTeam(
      favoriteTeam ?? UserPreferencesService.instance.favoriteTeam,
    );
    if (team == null) {
      return const FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.noFavoriteTeam,
      );
    }

    final t = now ?? DateTime.now();
    final season = currentSeasonLabel(t);
    final start = fetchStart(now: t, seasonLabel: season);
    final end = seasonEndExclusive(season);

    List<MatchModel> all;
    try {
      all = await MatchService.fetchInDateRange(
        startInclusive: start,
        endExclusive: end,
        includeR2: true,
      );
    } catch (_) {
      return FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.failed,
        teamName: team,
      );
    }

    final selected = selectExportable(
      matches: all,
      favoriteTeam: team,
      seasonLabel: season,
      now: t,
    );
    if (selected.isEmpty) {
      return FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.noUpcomingMatches,
        teamName: team,
      );
    }
    if (!context.mounted) {
      return FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.cancelled,
        teamName: team,
      );
    }

    final share = await MatchDeviceCalendar.addManyToDevice(
      context,
      selected,
      fileName: 'dvcr_${_fileSlug(team)}.ics',
      subject: 'Matchs $team',
    );
    switch (share) {
      case MatchCalendarShareResult.shared:
        return FavoriteTeamCalendarOutcome(
          status: FavoriteTeamCalendarStatus.shared,
          count: selected.length,
          teamName: team,
        );
      case MatchCalendarShareResult.cancelled:
        return FavoriteTeamCalendarOutcome(
          status: FavoriteTeamCalendarStatus.cancelled,
          teamName: team,
        );
      case MatchCalendarShareResult.unsupported:
        return FavoriteTeamCalendarOutcome(
          status: FavoriteTeamCalendarStatus.webUnsupported,
          teamName: team,
        );
      case MatchCalendarShareResult.failed:
        return FavoriteTeamCalendarOutcome(
          status: FavoriteTeamCalendarStatus.failed,
          teamName: team,
        );
    }
  }

  static String _fileSlug(String team) {
    final s = team.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    if (s.isEmpty) return 'equipe';
    return s.length > 32 ? s.substring(0, 32) : s;
  }
}
