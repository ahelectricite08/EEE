/// Schéma stats match v1 (noms FR canoniques).
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

  static MatchStatsVisibility visibilityFromMatchDoc(Map<String, dynamic>? d) {
    if (d == null) return MatchStatsVisibility.hidden;
    final state = MatchStatsPublicationState.fromFirestore(
      d['statsState']?.toString(),
    );
    final stats = normalizeMap(d['stats'] as Map<String, dynamic>?);
    final events = d['events'];
    final hasEvents = events is List && events.isNotEmpty;

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
}
