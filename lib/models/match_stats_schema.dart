import 'match_model.dart';

/// Schéma stats match v1 (noms FR canoniques).

/// Score domicile / extérieur pour affichage admin et cartes.
class ResolvedMatchScore {
  const ResolvedMatchScore({
    required this.home,
    required this.away,
    this.fromEvents = false,
    this.fromStored = false,
  });

  final int home;
  final int away;
  final bool fromEvents;
  final bool fromStored;

  bool get isKnown => fromEvents || fromStored;

  String get display => '$home-$away';
}

/// Compteurs buts / cartons dérivés des événements.
class MatchEventSideCounts {
  const MatchEventSideCounts({
    this.goalsHome = 0,
    this.goalsAway = 0,
    this.yellowHome = 0,
    this.yellowAway = 0,
    this.redHome = 0,
    this.redAway = 0,
  });

  final int goalsHome;
  final int goalsAway;
  final int yellowHome;
  final int yellowAway;
  final int redHome;
  final int redAway;

  int get totalGoals => goalsHome + goalsAway;
  int get totalCards =>
      yellowHome + yellowAway + redHome + redAway;
}
enum MatchStatsPublicationState {
  none,
  draft,
  preview,
  published;

  static MatchStatsPublicationState fromFirestore(String? raw) {
    switch (raw) {
      case 'draft':
        return MatchStatsPublicationState.draft;
      case 'preview':
        return MatchStatsPublicationState.preview;
      case 'published':
        return MatchStatsPublicationState.published;
      default:
        return MatchStatsPublicationState.none;
    }
  }

  String get firestoreValue {
    switch (this) {
      case MatchStatsPublicationState.draft:
        return 'draft';
      case MatchStatsPublicationState.preview:
        return 'preview';
      case MatchStatsPublicationState.published:
        return 'published';
      case MatchStatsPublicationState.none:
        return 'none';
    }
  }
}

enum MatchStatsVisibility {
  hidden,
  preview,
  published,
}

abstract final class MatchStatsSchema {
  /// Événements de jeu suivis (fiche match, live, cartes).
  /// Inclut les alertes Direct (but annulé / hors-jeu) — indépendants des stats chiffrées.
  static const Set<String> trackedGameEventTypes = {
    'goal',
    'own_goal',
    'yellow',
    'red',
    'substitution',
    'goal_cancelled',
    'goal_disallowed',
    'offside',
  };

  /// Alias push / Live Activity → types canoniques timeline.
  static String normalizeGameEventType(dynamic type) {
    final t = type?.toString().trim().toLowerCase() ?? '';
    return switch (t) {
      'yellow_card' => 'yellow',
      'red_card' => 'red',
      'sub' || 'subs' || 'remplacement' => 'substitution',
      _ => t,
    };
  }

  static bool isTrackedGameEvent(dynamic type) =>
      trackedGameEventTypes.contains(normalizeGameEventType(type));
  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  /// Normalise alias EN / anciens champs vers le schéma FR v1.
  static Map<String, dynamic> normalizeMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return {};
    final s = Map<String, dynamic>.from(raw);

    int g(String fr, String en) => _int(s[fr] ?? s[en]);
    double gd(String k) => _double(s[k]);

    final out = <String, dynamic>{
      'tirs1': g('tirs1', 'shots1'),
      'tirs2': g('tirs2', 'shots2'),
      'tirsCadres1': g('tirsCadres1', 'onTarget1'),
      'tirsCadres2': g('tirsCadres2', 'onTarget2'),
      'blocked1': g('blocked1', 'blocked1'),
      'blocked2': g('blocked2', 'blocked2'),
      'poteau1': g('poteau1', 'poteau1'),
      'poteau2': g('poteau2', 'poteau2'),
      'xg1': gd('xg1'),
      'xg2': gd('xg2'),
      'passes1': g('passes1', 'passAcc1'),
      'passes2': g('passes2', 'passAcc2'),
      'passInacc1': g('passInacc1', 'passInacc1'),
      'passInacc2': g('passInacc2', 'passInacc2'),
      'keyPass1': g('keyPass1', 'keyPass1'),
      'keyPass2': g('keyPass2', 'keyPass2'),
      'crossAcc1': g('crossAcc1', 'crossAcc1'),
      'crossAcc2': g('crossAcc2', 'crossAcc2'),
      'crossInacc1': g('crossInacc1', 'crossInacc1'),
      'crossInacc2': g('crossInacc2', 'crossInacc2'),
      'duelWon1': g('duelWon1', 'duelWon1'),
      'duelWon2': g('duelWon2', 'duelWon2'),
      'tackleWon1': g('tackleWon1', 'tackleWon1'),
      'tackleWon2': g('tackleWon2', 'tackleWon2'),
      'tackleLost1': g('tackleLost1', 'tackleLost1'),
      'tackleLost2': g('tackleLost2', 'tackleLost2'),
      'aerialWon1': g('aerialWon1', 'aerialWon1'),
      'aerialWon2': g('aerialWon2', 'aerialWon2'),
      'corners1': g('corners1', 'corners1'),
      'corners2': g('corners2', 'corners2'),
      'horsJeu1': g('horsJeu1', 'offsides1'),
      'horsJeu2': g('horsJeu2', 'offsides2'),
      'fautes1': g('fautes1', 'fouls1'),
      'fautes2': g('fautes2', 'fouls2'),
      'arretsGardien1': g('arretsGardien1', 'saves1'),
      'arretsGardien2': g('arretsGardien2', 'saves2'),
      'possessionMs1': g('possessionMs1', 'possessionMillis1'),
      'possessionMs2': g('possessionMs2', 'possessionMillis2'),
    };

    final p1 = _int(s['possession1']);
    final p2 = _int(s['possession2']);
    if (p1 > 0 || p2 > 0) {
      out['possession1'] = p1;
      out['possession2'] = p2;
    } else {
      final ms1 = _int(out['possessionMs1']);
      final ms2 = _int(out['possessionMs2']);
      final total = ms1 + ms2;
      if (total > 0) {
        out['possession1'] = ((ms1 / total) * 100).round();
        out['possession2'] = 100 - (out['possession1'] as int);
      }
    }

    final active = s['possessionActiveTeam'];
    if (active == 1 || active == 2) {
      out['possessionActiveTeam'] = active;
    }

  out.removeWhere((_, v) => v == 0 && v is! double);
    return out;
  }

  static bool isEmpty(Map<String, dynamic>? stats) {
    final n = normalizeMap(stats);
    return n.isEmpty;
  }

  /// Fusionne `live/current`, fiche match et preview TV pour l’affichage spectateur.
  static Map<String, dynamic> resolveFromLiveHub({
    required Map<String, dynamic> live,
    Map<String, dynamic>? match,
  }) {
    Map<String, dynamic> raw(Map<String, dynamic>? m) =>
        m == null ? <String, dynamic>{} : Map<String, dynamic>.from(m);

    var stats = raw(live['stats'] as Map<String, dynamic>?);
    if (isEmpty(stats)) {
      stats = raw(match?['stats'] as Map<String, dynamic>?);
    }
    if (isEmpty(stats)) {
      stats = raw(live['statsPreview'] as Map<String, dynamic>?);
    }
    return normalizeMap(stats.isEmpty ? null : stats);
  }

  static MatchStatsVisibility visibilityFromMatchDoc(Map<String, dynamic>? d) {
    if (d == null) return MatchStatsVisibility.hidden;
    final state = MatchStatsPublicationState.fromFirestore(
      d['statsState']?.toString(),
    );
    final stats = normalizeMap(d['stats'] as Map<String, dynamic>?);
    final hasEvents = eventsFromMatchDoc(d).isNotEmpty;

    if (state == MatchStatsPublicationState.published &&
        (!isEmpty(stats) || hasEvents)) {
      return MatchStatsVisibility.published;
    }
    if (state == MatchStatsPublicationState.preview &&
        (!isEmpty(stats) || hasEvents)) {
      return MatchStatsVisibility.preview;
    }
    if (d['showStats'] == true && (!isEmpty(stats) || hasEvents)) {
      return MatchStatsVisibility.published;
    }
    final early = d['earlyPublish'] == true;
    final st = d['status']?.toString() ?? 'upcoming';
    if (early && st == 'upcoming' && (!isEmpty(stats) || hasEvents)) {
      return MatchStatsVisibility.preview;
    }
    if (st != 'upcoming' && (!isEmpty(stats) || hasEvents)) {
      return MatchStatsVisibility.published;
    }
    return MatchStatsVisibility.hidden;
  }

  /// Événements canoniques sur une fiche `matches` (`events` + legacy `liveEvents`).
  static List<Map<String, dynamic>> eventsFromMatchDoc(
    Map<String, dynamic>? doc,
  ) {
    if (doc == null) return [];
    return mergeGameEvents(
      parseGameEvents(doc['events']),
      parseGameEvents(doc['liveEvents']),
    );
  }

  /// Domicile / extérieur pour affichage timeline (bool explicite ou noms d’équipes).
  static bool isHomeTeamEvent(
    Map<String, dynamic> event,
    String team1,
    String team2,
  ) {
    final rawBool = event['isHome'];
    if (rawBool is bool) return rawBool;

    final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (side == 'home' || side == 'left' || side == 'team1') return true;
    if (side == 'away' || side == 'right' || side == 'team2') return false;

    final teamIndex = event['teamIndex'];
    if (teamIndex is num) return teamIndex.toInt() == 0;

    final teamRaw = (event['team'] ?? event['teamName'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final t1 = team1.trim().toUpperCase();
    final t2 = team2.trim().toUpperCase();

    if (teamRaw.isNotEmpty) {
      if (teamRaw == t1) return true;
      if (teamRaw == t2) return false;
      if (t1.isNotEmpty && teamRaw.contains(t1.split(' ').first)) return true;
      if (t2.isNotEmpty && teamRaw.contains(t2.split(' ').first)) return false;
    }
    return true;
  }

  /// Buts / cartons issus de `events` sur fiche match ou live.
  static List<Map<String, dynamic>> parseGameEvents(dynamic raw) =>
      (raw is List ? raw : <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => isTrackedGameEvent(e['type']))
          .toList()
        ..sort(
          (a, b) => _int(a['minute']).compareTo(_int(b['minute'])),
        );

  /// Fusionne deux listes d’événements (live + fiche match) sans doublons.
  static List<Map<String, dynamic>> mergeGameEvents(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.isEmpty) return List.from(b);
    if (b.isEmpty) return List.from(a);
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final e in [...a, ...b]) {
      final key = e['type'] == 'substitution'
          ? '${e['type']}|${e['minute']}|${e['playerOut']}|${e['playerIn']}|${e['team']}'
              .toLowerCase()
          : '${e['type']}|${e['minute']}|${e['player']}|${e['team']}'
              .toLowerCase();
      if (seen.add(key)) out.add(e);
    }
    out.sort((x, y) => _int(x['minute']).compareTo(_int(y['minute'])));
    return out;
  }

  /// Libellé joueur(s) pour affichage (buteur, remplacement, alerte Direct).
  static String eventPlayerLine(Map<String, dynamic> e) {
    final type = normalizeGameEventType(e['type']);
    if (type == 'substitution') {
      final out = (e['playerOut'] ?? e['player'] ?? '').toString().trim();
      final inPlayer = (e['playerIn'] ?? '').toString().trim();
      if (out.isNotEmpty && inPlayer.isNotEmpty) return '$out ⇄ $inPlayer';
      if (inPlayer.isNotEmpty) return inPlayer;
      return out.isNotEmpty ? out : '?';
    }
    final player = (e['player'] as String? ?? '').trim();
    final label = switch (type) {
      'goal_cancelled' => 'But annulé',
      'goal_disallowed' => 'But refusé',
      'offside' => 'Hors-jeu',
      'own_goal' => 'CSC',
      _ => '',
    };
    if (label.isEmpty) return player;
    if (player.isEmpty) return label;
    return '$label · $player';
  }

  /// Compte buts et cartons par côté à partir du fil d’événements.
  static MatchEventSideCounts countFromEvents(
    List<Map<String, dynamic>> events,
    String team1,
    String team2,
  ) {
    var goalsHome = 0;
    var goalsAway = 0;
    var yellowHome = 0;
    var yellowAway = 0;
    var redHome = 0;
    var redAway = 0;
    for (final e in events) {
      final type = (e['type'] as String? ?? '').trim().toLowerCase();
      final home = isHomeTeamEvent(e, team1, team2);
      switch (type) {
        case 'goal':
          if (home) {
            goalsHome++;
          } else {
            goalsAway++;
          }
        case 'yellow':
          if (home) {
            yellowHome++;
          } else {
            yellowAway++;
          }
        case 'red':
          if (home) {
            redHome++;
          } else {
            redAway++;
          }
        default:
          break;
      }
    }
    return MatchEventSideCounts(
      goalsHome: goalsHome,
      goalsAway: goalsAway,
      yellowHome: yellowHome,
      yellowAway: yellowAway,
      redHome: redHome,
      redAway: redAway,
    );
  }

  /// Score affiché : champs FFF (`score1`/`score2`), live (`scoreHome`), ou dérivé des buts.
  static ResolvedMatchScore resolveMatchScores(
    Map<String, dynamic> d, {
    List<Map<String, dynamic>>? events,
  }) {
    final t1 = (d['team1'] as String? ?? '').trim();
    final t2 = (d['team2'] as String? ?? '').trim();
    final allEvents = events ?? eventsFromMatchDoc(d);
    final counts = countFromEvents(allEvents, t1, t2);

    final storedHome = MatchModel.parseScoreField(
      d['score1'] ?? d['homeScore'] ?? d['scoreHome'],
    );
    final storedAway = MatchModel.parseScoreField(
      d['score2'] ?? d['awayScore'] ?? d['scoreAway'],
    );

    if (counts.totalGoals > 0) {
      final storedTotal = (storedHome ?? 0) + (storedAway ?? 0);
      if (storedHome == null && storedAway == null ||
          counts.totalGoals > storedTotal) {
        return ResolvedMatchScore(
          home: counts.goalsHome,
          away: counts.goalsAway,
          fromEvents: true,
        );
      }
    }

    if (storedHome != null && storedAway != null) {
      return ResolvedMatchScore(
        home: storedHome,
        away: storedAway,
        fromStored: true,
      );
    }

    if (counts.totalGoals > 0) {
      return ResolvedMatchScore(
        home: counts.goalsHome,
        away: counts.goalsAway,
        fromEvents: true,
      );
    }

    return ResolvedMatchScore(
      home: storedHome ?? 0,
      away: storedAway ?? 0,
      fromStored: storedHome != null || storedAway != null,
    );
  }

  /// Compte les buts par nom de joueur (stats / admin).
  static Map<String, int> goalsByPlayer(List<Map<String, dynamic>> events) {
    final counts = <String, int>{};
    for (final e in events) {
      if (e['type'] != 'goal') continue;
      final name = (e['player'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  static bool isSedanTeamLabel(String name) =>
      name.toUpperCase().contains('SEDAN');

  /// Événement du côté Sedan (nom d’équipe ou domicile/extérieur).
  static bool isSedanSideEvent(
    Map<String, dynamic> event,
    String team1,
    String team2,
  ) {
    final teamRaw = (event['team'] ?? event['teamName'] ?? '')
        .toString()
        .trim();
    if (teamRaw.isNotEmpty) {
      if (isSedanTeamLabel(teamRaw)) return true;
      final u = teamRaw.toUpperCase();
      if (isSedanTeamLabel(team1) && u == team1.trim().toUpperCase()) {
        return true;
      }
      if (isSedanTeamLabel(team2) && u == team2.trim().toUpperCase()) {
        return true;
      }
    }
    final home = isHomeTeamEvent(event, team1, team2);
    if (isSedanTeamLabel(team1) && home) return true;
    if (isSedanTeamLabel(team2) && !home) return true;
    return false;
  }

  /// Buts / cartons par joueur Sedan (faits de jeu live ou fiche match).
  static Map<String, Map<String, int>> sedanPlayerFacts(
    List<Map<String, dynamic>> events,
    String team1,
    String team2,
  ) {
    final out = <String, Map<String, int>>{};
    void bump(String player, String key) {
      final name = player.trim();
      if (name.isEmpty || name == '?' || name == 'Inconnu') return;
      final row = out.putIfAbsent(name, () => <String, int>{});
      row[key] = (row[key] ?? 0) + 1;
    }

    for (final e in events) {
      if (!isSedanSideEvent(e, team1, team2)) continue;
      final type = (e['type'] as String? ?? '').trim().toLowerCase();
      switch (type) {
        case 'goal':
          bump((e['player'] as String? ?? '').trim(), 'goals');
        case 'yellow':
          bump((e['player'] as String? ?? '').trim(), 'yellow');
        case 'red':
          bump((e['player'] as String? ?? '').trim(), 'red');
        case 'substitution':
          bump(
            (e['playerIn'] as String? ?? '').trim(),
            'subsIn',
          );
          bump(
            (e['playerOut'] ?? e['player'] ?? '').toString().trim(),
            'subsOut',
          );
        default:
          break;
      }
    }
    return out;
  }

}

/// Réglages publication (onglet Statistiques match) — indépendants des faits de jeu live.
class MatchStatsPublicationSettings {
  final bool workbenchOpen;
  final bool liveDisplay;
  final bool cardDisplay;
  final bool official;

  const MatchStatsPublicationSettings({
    this.workbenchOpen = true,
    this.liveDisplay = false,
    this.cardDisplay = false,
    this.official = false,
  });

  factory MatchStatsPublicationSettings.fromSheet(
    Map<String, dynamic>? sheet,
  ) {
    final s = sheet ?? {};
    final state = MatchStatsPublicationState.fromFirestore(
      s['state']?.toString(),
    );
    final legacyPreview = s['previewEnabled'] == true;
    return MatchStatsPublicationSettings(
      workbenchOpen: s['workbenchOpen'] != false,
      liveDisplay: s['liveDisplay'] == true || legacyPreview,
      cardDisplay: s['cardDisplay'] == true || legacyPreview,
      official: state == MatchStatsPublicationState.published,
    );
  }

  /// Champs fiche `match_stats` — pas le bandeau live (piloté via `live/current.statsEnabled`).
  Map<String, dynamic> toSheetPatch() {
    final preview = !official && cardDisplay;
    return {
      'workbenchOpen': workbenchOpen,
      'cardDisplay': cardDisplay,
      'state': official
          ? MatchStatsPublicationState.published.firestoreValue
          : preview
              ? MatchStatsPublicationState.preview.firestoreValue
              : MatchStatsPublicationState.draft.firestoreValue,
      'previewEnabled': preview,
    };
  }
}
