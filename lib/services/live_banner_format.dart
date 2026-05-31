import 'live_state_service.dart';

/// Texte minute + dernier fait de jeu pour bannière / écran verrouillé.
class LiveBannerFormat {
  LiveBannerFormat._();

  static String minuteLabel(LiveHubState hub) {
    if (hub.isFulltime || hub.isExtraFulltime) return 'Fin';
    if (hub.isHalftime || hub.isExtraHalftime) return 'Mi-temps';
    if (hub.isExtraTimePlaying) return 'Prol.';

    final seconds = _elapsedSeconds(hub);
    if (seconds > 0) {
      final m = seconds ~/ 60;
      return "$m'";
    }
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
        return '🔄 $out → $inn$minBit';
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
