import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import 'match_controller.dart';
import 'match_service.dart';

/// Match proposé au démarrage d’un direct (admin / pilotage rapide).
class LiveStartSuggestion {
  final MatchModel? match;
  final String? message;

  const LiveStartSuggestion({this.match, this.message});
}

/// Résultat du formulaire « démarrer le live ».
class LiveStartFormResult {
  final bool streamBroadcast;
  final MatchModel match;

  const LiveStartFormResult({
    required this.streamBroadcast,
    required this.match,
  });
}

/// Choix du match et suggestion par défaut pour lancer un live.
abstract final class LiveStartService {
  static const Duration _matchDurationFallback = Duration(hours: 2);
  static const Duration _nextMatchDelayAfterEnd = Duration(hours: 3);

  /// Fenêtre affichée dans la liste déroulante (aujourd’hui + N jours).
  static const int pickableDaysAhead = 5;

  /// Début (00:00 aujourd’hui) et fin exclusive (00:00 après le 5e jour).
  static ({DateTime start, DateTime end}) pickableWindow({DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    final end = start.add(Duration(days: pickableDaysAhead + 1));
    return (start: start, end: end);
  }

  static bool isInPickableWindow(MatchModel match, {DateTime? now}) {
    final window = pickableWindow(now: now);
    return !match.date.isBefore(window.start) &&
        match.date.isBefore(window.end);
  }

  /// Charge les matchs depuis Firestore (web + mobile), sans filtre Sedan du cache app.
  static Future<List<MatchModel>> loadPickableMatches({DateTime? now}) async {
    final window = pickableWindow(now: now);
    try {
      final fromServer = await MatchService.fetchInDateRange(
        startInclusive: window.start,
        endExclusive: window.end,
      );
      return _normalizePickable(fromServer, now: now);
    } catch (e, st) {
      debugPrint('DVCR live picker Firestore: $e\n$st');
      await MatchController.instance.init();
      return _normalizePickable(
        MatchController.instance.upcoming,
        now: now,
        extra: MatchController.instance.results,
      );
    }
  }

  static List<MatchModel> _normalizePickable(
    Iterable<MatchModel> primary, {
    DateTime? now,
    Iterable<MatchModel>? extra,
  }) {
    final seen = <String>{};
    final out = <MatchModel>[];
    final all = <MatchModel>[...primary];
    if (extra != null) all.addAll(extra);

    for (final m in all) {
      if (m.team1.trim().isEmpty || m.team2.trim().isEmpty) continue;
      if (!isInPickableWindow(m, now: now)) continue;
      if (seen.add(m.id)) out.add(m);
    }

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  static String matchLabel(MatchModel match) {
    final date = DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(match.date);
    final comp = match.competition.trim();
    final compSuffix = comp.isEmpty ? '' : ' · $comp';
    return '${match.team1} vs ${match.team2} — $date$compSuffix';
  }

  /// Suggestion par défaut dans la fenêtre : dernier match récent ou prochain à venir.
  static LiveStartSuggestion pickSuggestedFrom(
    List<MatchModel> pickable, {
    DateTime? now,
  }) {
    if (pickable.isEmpty) {
      return LiveStartSuggestion(
        match: null,
        message:
            'Aucun match prévu dans les $pickableDaysAhead prochains jours. '
            'Vérifie le calendrier dans Admin → Match.',
      );
    }

    final n = now ?? DateTime.now();
    final finished = pickable
        .where((m) => m.status == MatchStatus.finished)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final upcoming = pickable
        .where((m) => m.status != MatchStatus.finished)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent = finished.isNotEmpty ? finished.first : null;

    if (recent != null) {
      final switchAt = recent.date
          .add(_matchDurationFallback)
          .add(_nextMatchDelayAfterEnd);
      if (n.isBefore(switchAt)) {
        final remaining = switchAt.difference(n);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final timerLabel = hours > 0
            ? '${hours}h${minutes.toString().padLeft(2, '0')}'
            : '$minutes min';
        return LiveStartSuggestion(
          match: recent,
          message:
              'Par défaut : dernier match joué (stats live). '
              'Liste = calendrier Firestore, $pickableDaysAhead prochains jours. '
              'Prochain auto dans $timerLabel.',
        );
      }
    }

    final next = upcoming.isNotEmpty ? upcoming.first : pickable.first;
    return LiveStartSuggestion(
      match: next,
      message:
          'Matchs des $pickableDaysAhead prochains jours (toutes équipes) — change si besoin.',
    );
  }
}
