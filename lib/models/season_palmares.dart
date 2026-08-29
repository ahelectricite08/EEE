import 'package:cloud_firestore/cloud_firestore.dart';

import 'match_model.dart';
import '../utils/match_calendar_filter.dart';
import '../utils/match_competition.dart';

/// Palmarès saison : moyenne des notes du match + Hommes du match.
class SeasonPalmares {
  const SeasonPalmares({
    required this.seasonLabel,
    required this.averageNote,
    required this.ratedMatchCount,
    required this.hdm,
    required this.noteHistory,
  });

  final String seasonLabel;
  final double? averageNote;
  final int ratedMatchCount;
  final List<HdmPlayerTally> hdm;
  final List<RatedMatchRow> noteHistory;

  bool get isEmpty => hdm.isEmpty && ratedMatchCount == 0;

  String get averageNoteLabel {
    final avg = averageNote;
    if (avg == null) return '—';
    return formatClubNote(avg);
  }

  /// Moyenne des notes **par match** (chaque affiche compte autant), pas pondérée
  /// au nombre de votes.
  static SeasonPalmares fromMatchDocs({
    required String seasonLabel,
    required Iterable<SeasonPalmaresMatchDoc> docs,
  }) {
    final seasonMatches = <SeasonPalmaresMatchDoc>[];
    for (final doc in docs) {
      final match = doc.toMatchModel();
      if (match == null) continue;
      if (!MatchCalendarFilter.visibleInAppCalendar(
        match,
        displaySeason: seasonLabel,
        activeSeasonLabel: seasonLabel,
      )) {
        continue;
      }
      // Récap = championnat Régional 1 seulement (pas d’amical, pas de coupe).
      if (!MatchCompetition.matchesStatsFilter(
        match.competition,
        categoryId: 'championship',
        championshipLevel: 'Régional 1',
      )) {
        continue;
      }
      seasonMatches.add(doc.copyWith(match: match));
    }

    seasonMatches.sort((a, b) => b.match!.date.compareTo(a.match!.date));

    final noteRows = <RatedMatchRow>[];
    var noteSum = 0.0;
    for (final doc in seasonMatches) {
      final rating = doc.rating;
      if (rating == null) continue;
      noteRows.add(
        RatedMatchRow(
          matchId: doc.id,
          date: doc.match!.date,
          fixtureLabel: fixtureLabelFor(doc.match!),
          average: rating.$1,
          totalVotes: rating.$2,
        ),
      );
      noteSum += rating.$1;
    }

    final hdmByKey = <String, _HdmAcc>{};
    for (final doc in seasonMatches) {
      final name = doc.hdmName;
      if (name.isEmpty) continue;
      final key = _hdmKey(name);
      final ref = HdmMatchRef(
        matchId: doc.id,
        date: doc.match!.date,
        fixtureLabel: fixtureLabelFor(doc.match!),
      );
      final acc = hdmByKey[key];
      if (acc == null) {
        hdmByKey[key] = _HdmAcc(displayName: name, matches: [ref]);
      } else {
        acc.matches.add(ref);
      }
    }

    final hdm = hdmByKey.values
        .map(
          (acc) => HdmPlayerTally(
            name: acc.displayName,
            count: acc.matches.length,
            matches: acc.matches,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.count != b.count) return b.count.compareTo(a.count);
        return b.matches.first.date.compareTo(a.matches.first.date);
      });

    return SeasonPalmares(
      seasonLabel: seasonLabel,
      averageNote: noteRows.isEmpty ? null : noteSum / noteRows.length,
      ratedMatchCount: noteRows.length,
      hdm: hdm,
      noteHistory: noteRows,
    );
  }

  static String fixtureLabelFor(MatchModel match) {
    final opp = MatchCalendarFilter.involvesSedan(match)
        ? (isSedanName(match.team1) ? match.team2 : match.team1)
        : '${match.team1} — ${match.team2}';
    final trimmed = opp.trim();
    return trimmed.isEmpty ? 'Match' : trimmed;
  }

  static bool isSedanName(String team) {
    final upper = team.toUpperCase();
    return upper.contains('SEDAN') || upper.contains('CSSA');
  }

  static String formatClubNote(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String _hdmKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class SeasonPalmaresMatchDoc {
  const SeasonPalmaresMatchDoc({
    required this.id,
    required this.data,
    this.match,
  });

  final String id;
  final Map<String, dynamic> data;
  final MatchModel? match;

  SeasonPalmaresMatchDoc copyWith({MatchModel? match}) {
    return SeasonPalmaresMatchDoc(
      id: id,
      data: data,
      match: match ?? this.match,
    );
  }

  String get hdmName {
    if (data['showMotm'] == false) return '';
    final published = (data['manOfTheMatchName'] as String? ?? '').trim();
    if (published.isNotEmpty) return published;
    return (data['motmVoteWinnerName'] as String? ?? '').trim();
  }

  /// (moyenne, total votes) si une vraie note est persistée sur le match.
  (double, int)? get rating {
    final totalRaw = data['matchRatingTotal'];
    final total = totalRaw is num ? totalRaw.toInt() : 0;
    if (total <= 0) return null;
    final avgRaw = data['matchRatingAverage'];
    final sumRaw = data['matchRatingSum'];
    var avg = avgRaw is num ? avgRaw.toDouble() : 0.0;
    final sum = sumRaw is num ? sumRaw.toInt() : 0;
    if (avg <= 0 && sum > 0) avg = sum / total;
    if (avg <= 0) return null;
    return (avg, total);
  }

  MatchModel? toMatchModel() {
    final date = _dateOf(data['date']);
    if (date == null) return null;
    MatchStatus status;
    switch (data['status']) {
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
      id: id,
      team1: (data['team1'] as String? ?? '').trim(),
      team2: (data['team2'] as String? ?? '').trim(),
      date: date,
      competition: (data['competition'] as String? ?? 'Championnat').trim(),
      status: status,
      fffSeason: data['fffSeason']?.toString(),
      manual: data['manual'] == true,
    );
  }

  static DateTime? _dateOf(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class HdmPlayerTally {
  const HdmPlayerTally({
    required this.name,
    required this.count,
    required this.matches,
  });

  final String name;
  final int count;
  final List<HdmMatchRef> matches;
}

class HdmMatchRef {
  const HdmMatchRef({
    required this.matchId,
    required this.date,
    required this.fixtureLabel,
  });

  final String matchId;
  final DateTime date;
  final String fixtureLabel;
}

class RatedMatchRow {
  const RatedMatchRow({
    required this.matchId,
    required this.date,
    required this.fixtureLabel,
    required this.average,
    required this.totalVotes,
  });

  final String matchId;
  final DateTime date;
  final String fixtureLabel;
  final double average;
  final int totalVotes;
}

class _HdmAcc {
  _HdmAcc({required this.displayName, required this.matches});

  final String displayName;
  final List<HdmMatchRef> matches;
}
