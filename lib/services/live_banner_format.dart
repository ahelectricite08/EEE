import '../models/match_stats_schema.dart';
import 'live_state_service.dart';

/// Texte minute + dernier fait de jeu pour bannière / écran verrouillé.
class LiveBannerFormat {
  LiveBannerFormat._();

  static String minuteLabel(LiveHubState hub) {
    if (hub.isFulltime || hub.isExtraFulltime) return 'Fin';
    if (hub.isHalftime || hub.isExtraHalftime) return 'Mi-temps';

    final seconds = _elapsedSeconds(hub);
    if (seconds > 0) {
      final m = seconds ~/ 60;
      if (hub.isExtraTimePlaying) return "Prol. $m'";
      return "$m'";
    }
    if (hub.isExtraTimePlaying) return 'Prol.';
    if (hub.minute > 0) return "${hub.minute}'";
    if (hub.chronoRunning) return "0'";
    return 'LIVE';
  }

  static int _elapsedSeconds(LiveHubState hub) {
    if (hub.chronoRunning && hub.chronoStartedAtMs > 0) {
      return hub.chronoBaseSeconds +
          (DateTime.now().millisecondsSinceEpoch - hub.chronoStartedAtMs) ~/
              1000;
    }
    if (hub.chronoBaseSeconds > 0) return hub.chronoBaseSeconds;
    if (hub.minute > 0) return hub.minute * 60;
    return 0;
  }

  /// Temps écoulé depuis les champs Firestore `live/current` (chrono fiable web/admin).
  static int elapsedSecondsFromMap(Map<String, dynamic> data) {
    final running = data['chronoRunning'] == true;
    final base = (data['chronoBaseSeconds'] as num?)?.toInt() ?? 0;
    final minute = (data['minute'] as num?)?.toInt() ?? 0;
    final startedAt = (data['chronoStartedAtMs'] as num?)?.toInt() ?? 0;
    if (running && startedAt > 0) {
      return base +
          (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
    }
    if (base > 0) return base;
    if (minute > 0) return minute * 60;
    return 0;
  }

  /// Affichage admin chrono `m:ss`.
  static String chronoMmSsFromMap(Map<String, dynamic> data) {
    final sec = elapsedSecondsFromMap(data);
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Dernier événement enregistré (but, carton, remplacement…).
  static String lastEventLine(LiveHubState hub) {
    if (hub.timelineEvents.isEmpty) return '';
    final e = hub.timelineEvents.last;
    return _formatEvent(e, hub);
  }

  /// Version courte pour Live Activity / notif verrouillée (évite le rognage).
  static String lockScreenEventLine(LiveHubState hub) {
    final line = lastEventLine(hub);
    if (line.isEmpty) return '';
    if (line.length <= 34) return line;
    return '${line.substring(0, 32)}…';
  }

  /// Côté Live Activity : domicile = gauche, extérieur = droite.
  static bool lastEventIsHome(LiveHubState hub) {
    if (hub.timelineEvents.isEmpty) return true;
    return MatchStatsSchema.isHomeTeamEvent(
      hub.timelineEvents.last,
      hub.matchTeam1,
      hub.matchTeam2,
    );
  }

  /// Score compact pour bannières iOS / push (ex. « 2 : 1 »).
  static String compactScore(LiveHubState hub) =>
      '${hub.scoreHome} : ${hub.scoreAway}';

  /// Bannière haut d’écran (Live Activity alert) — titre accrocheur, corps épuré.
  static LivePushBanner? topBanner(LiveHubState hub, LiveHubState before) {
    final phase = _phaseBanner(hub, before);
    if (phase != null) return phase;
    return _eventBanner(hub, before);
  }

  static LivePushBanner? _phaseBanner(
    LiveHubState hub,
    LiveHubState before,
  ) {
    final score = compactScore(hub);
    if (hub.isHalftime && !before.isHalftime) {
      return LivePushBanner('Mi-temps', score);
    }
    if (hub.isExtraHalftime && !before.isExtraHalftime) {
      return LivePushBanner('Mi-temps prolongations', score);
    }
    if (hub.isFulltime && !before.isFulltime) {
      return LivePushBanner('Fin du match', score);
    }
    if (hub.isExtraFulltime && !before.isExtraFulltime) {
      return LivePushBanner('Fin des prolongations', score);
    }
    if (hub.isExtraTimePlaying && !before.isExtraTimePlaying) {
      return LivePushBanner('Prolongations', score);
    }
    return null;
  }

  static LivePushBanner? _eventBanner(
    LiveHubState hub,
    LiveHubState before,
  ) {
    final prev = lockScreenEventLine(before);
    final curr = lockScreenEventLine(hub);
    if (curr.isEmpty || curr == prev || hub.timelineEvents.isEmpty) {
      return null;
    }
    final e = hub.timelineEvents.last;
    final type = (e['type'] ?? '').toString();
    if (!_isDisplayableEvent(type)) return null;

    final score = compactScore(hub);
    final player = _playerName(e);
    final minBit = _minuteBit(_eventMinute(e, hub));
    final detail = _joinParts([player, minBit]);

    switch (type) {
      case 'goal':
      case 'own_goal':
        return LivePushBanner('⚽ BUT · $score', detail);
      case 'yellow':
        return LivePushBanner('🟨 Carton jaune', _joinParts([detail, score]));
      case 'red':
        return LivePushBanner('🟥 Carton rouge', _joinParts([detail, score]));
      case 'substitution':
        final out = (e['playerOut'] ?? e['player'] ?? '?').toString().trim();
        final inn = (e['playerIn'] ?? '?').toString().trim();
        final line = (out.contains('⇄') || out.contains('→')) && inn == '?'
            ? out
            : '$out → $inn';
        return LivePushBanner(
          '🔄 Remplacement',
          _joinParts([line, minBit]),
        );
      case 'goal_cancelled':
        return LivePushBanner('But annulé · $score', _joinParts([detail]));
      case 'goal_disallowed':
        return LivePushBanner('But refusé · $score', _joinParts([detail]));
      case 'offside':
        return LivePushBanner('Hors-jeu · $score', _joinParts([detail]));
      default:
        return null;
    }
  }

  static String _minuteBit(int minute) => minute >= 0 ? "$minute'" : '';

  static String _joinParts(List<String> parts) =>
      parts.where((p) => p.trim().isNotEmpty).join(' · ');

  static String _formatEvent(Map<String, dynamic> e, LiveHubState hub) {
    final type = (e['type'] ?? '').toString();
    if (!_isDisplayableEvent(type)) return '';

    final minute = _eventMinute(e, hub);
    final minBit = minute >= 0 ? " $minute'" : '';
    final teamBit = _teamSuffix(e);

    switch (type) {
      case 'goal':
      case 'own_goal':
        final player = _playerName(e);
        return '⚽ $player$minBit$teamBit';
      case 'yellow':
        return '🟨 ${_playerName(e)}$minBit$teamBit';
      case 'red':
        return '🟥 ${_playerName(e)}$minBit$teamBit';
      case 'substitution':
        final out = (e['playerOut'] ?? e['player'] ?? '?').toString().trim();
        final inn = (e['playerIn'] ?? '?').toString().trim();
        final line = (out.contains('⇄') || out.contains('→')) &&
                (inn.isEmpty || inn == '?')
            ? out
            : '$out → $inn';
        return '🔄 $line$minBit';
      case 'goal_cancelled':
        return '⊘ But annulé$minBit$teamBit';
      case 'goal_disallowed':
        return '⊘ But refusé$minBit$teamBit';
      case 'offside':
        return '🚩 Hors-jeu$minBit$teamBit';
      default:
        return '';
    }
  }

  static bool _isDisplayableEvent(String type) {
    return type == 'goal' ||
        type == 'own_goal' ||
        type == 'yellow' ||
        type == 'red' ||
        type == 'substitution' ||
        type == 'goal_cancelled' ||
        type == 'goal_disallowed' ||
        type == 'offside';
  }

  static String _playerName(Map<String, dynamic> e) {
    final raw = (e['player'] ?? '').toString().trim();
    if (raw.isEmpty) return 'Inconnu';
    if (raw.length <= 22) return raw;
    return '${raw.substring(0, 20)}…';
  }

  static int _eventMinute(Map<String, dynamic> e, LiveHubState hub) {
    final m = e['minute'];
    if (m is num && m >= 0) return m.toInt();
    return hub.minute;
  }

  static String _teamSuffix(Map<String, dynamic> e) {
    final team = (e['team'] ?? '').toString().trim();
    if (team.isEmpty) return '';
    final short =
        team.length <= 14 ? team : '${team.substring(0, 12)}…';
    return ' · $short';
  }
}

/// Titre + corps pour bannière système (Dynamic Island / notification).
class LivePushBanner {
  final String title;
  final String body;

  const LivePushBanner(this.title, this.body);
}
