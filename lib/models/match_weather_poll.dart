import '../services/match_weather_service.dart';
import 'match_fan_poll_window.dart';

/// Sondage météo fiche match — options figées (compteurs stables).
class MatchWeatherPollOption {
  final String id;
  final String label;
  final String said;

  const MatchWeatherPollOption({
    required this.id,
    required this.label,
    required this.said,
  });
}

/// « Qui amène le k-way » — 1 choix / user. Fiche prochain CSSA, fermeture KO+20.
abstract final class MatchWeatherPoll {
  static const String collection = 'match_weather_votes';
  static const String votesSub = 'votes';

  static const MatchWeatherPollOption kway = MatchWeatherPollOption(
    id: 'kway',
    label: 'Oui, obligatoire',
    said: 'k-way',
  );

  static const MatchWeatherPollOption doudoune = MatchWeatherPollOption(
    id: 'doudoune',
    label: 'Doudoune, clairement',
    said: 'doudoune',
  );

  static const MatchWeatherPollOption casquette = MatchWeatherPollOption(
    id: 'casquette',
    label: 'Casquette et basta',
    said: 'casquette',
  );

  static const MatchWeatherPollOption ardennais = MatchWeatherPollOption(
    id: 'ardennais',
    label: 'Non, je suis un vrai Ardennais',
    said: 'vrai Ardennais',
  );

  /// Même id Firestore, libellé casquette (« Casquette ou rien ? »).
  static const MatchWeatherPollOption ardennaisRien = MatchWeatherPollOption(
    id: 'ardennais',
    label: 'Rien, je suis un vrai Ardennais',
    said: 'vrai Ardennais',
  );

  static const List<MatchWeatherPollOption> options = [
    kway,
    doudoune,
    casquette,
    ardennais,
  ];

  static const Set<String> optionIds = {
    'kway',
    'doudoune',
    'casquette',
    'ardennais',
  };

  static bool isValidOptionId(String id) => optionIds.contains(id);

  static MatchWeatherPollOption? optionById(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Pas d’H-30 : ouvert dès la fiche, fermé à KO+20 exclus.
  static bool isOpen(DateTime kickoff, {DateTime? now}) =>
      MatchFanPollWindow.isKwayOpen(kickoff: kickoff, now: now);

  static String promptFor(MatchWeatherMode mode, int? tempC) {
    switch (_kindFor(mode, tempC)) {
      case _MatchWeatherPollKind.kway:
        return 'Qui amène le k-way ?';
      case _MatchWeatherPollKind.doudoune:
        return 'Qui sort la doudoune ?';
      case _MatchWeatherPollKind.casquette:
        return 'Casquette ou rien ?';
    }
  }

  /// 2 choix (3 si pluie + froid : k-way et doudoune). Ids Firestore inchangés.
  static List<MatchWeatherPollOption> optionsFor(
    MatchWeatherMode mode,
    int? tempC,
  ) {
    final kind = _kindFor(mode, tempC);
    final wet = mode == MatchWeatherMode.rain || mode == MatchWeatherMode.storm;
    final cold = tempC != null && tempC <= 12;
    switch (kind) {
      case _MatchWeatherPollKind.doudoune:
        return const [doudoune, ardennais];
      case _MatchWeatherPollKind.casquette:
        return const [casquette, ardennaisRien];
      case _MatchWeatherPollKind.kway:
        if (wet && cold) return const [kway, doudoune, ardennais];
        return const [kway, ardennais];
    }
  }

  static Set<String> optionIdsFor(MatchWeatherMode mode, int? tempC) =>
      {for (final o in optionsFor(mode, tempC)) o.id};

  static _MatchWeatherPollKind _kindFor(MatchWeatherMode mode, int? tempC) {
    switch (mode) {
      case MatchWeatherMode.rain:
      case MatchWeatherMode.storm:
        return _MatchWeatherPollKind.kway;
      case MatchWeatherMode.snow:
        return _MatchWeatherPollKind.doudoune;
      case MatchWeatherMode.clear:
      case MatchWeatherMode.sunClouds:
      case MatchWeatherMode.clouds:
        if (tempC != null && tempC <= 12) return _MatchWeatherPollKind.doudoune;
        if (tempC != null && tempC >= 20) return _MatchWeatherPollKind.casquette;
        return _MatchWeatherPollKind.kway;
      case MatchWeatherMode.fog:
      case MatchWeatherMode.none:
        return _MatchWeatherPollKind.kway;
    }
  }

  /// « 4 ont dit doudoune » / « 1 a dit k-way ».
  static String saidLine(MatchWeatherPollOption option, int count) {
    if (count <= 0) return '';
    if (count == 1) return '1 a dit ${option.said}';
    return '$count ont dit ${option.said}';
  }

  static String tallyLine(
    Map<String, int> counts, {
    List<MatchWeatherPollOption>? visible,
  }) {
    final parts = <String>[];
    final seen = <String>{};
    for (final o in visible ?? options) {
      if (!seen.add(o.id)) continue;
      final n = counts[o.id] ?? 0;
      if (n <= 0) continue;
      parts.add(saidLine(o, n));
    }
    return parts.join('  ·  ');
  }

  /// Un seul choix par uid : un second vote remplace le premier.
  static Map<String, String> applyVote({
    required Map<String, String> votesByUid,
    required String uid,
    required String optionId,
    required DateTime kickoff,
    DateTime? now,
    MatchWeatherMode? mode,
    int? tempC,
  }) {
    if (uid.isEmpty) return votesByUid;
    if (mode != null) {
      if (!optionIdsFor(mode, tempC).contains(optionId)) return votesByUid;
    } else if (!isValidOptionId(optionId)) {
      return votesByUid;
    }
    if (!isOpen(kickoff, now: now)) return Map<String, String>.from(votesByUid);
    final next = Map<String, String>.from(votesByUid);
    next[uid] = optionId;
    return next;
  }

  static Map<String, int> countsFromVotes(Map<String, String> votesByUid) {
    final counts = <String, int>{};
    for (final id in votesByUid.values) {
      if (!isValidOptionId(id)) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}

class MatchWeatherPollSnapshot {
  final Map<String, int> counts;
  final String? myOptionId;

  const MatchWeatherPollSnapshot({
    this.counts = const {},
    this.myOptionId,
  });

  int countFor(String optionId) => counts[optionId] ?? 0;
}

enum _MatchWeatherPollKind { kway, doudoune, casquette }
