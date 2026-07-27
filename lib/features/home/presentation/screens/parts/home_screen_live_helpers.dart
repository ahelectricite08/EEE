part of '../home_screen.dart';

mixin _HomeScreenLiveHelpersMixin on _HomeScreenController {
  int _computeChronoSeconds() {
    if (!_chronoRunning || _chronoStartedAtMs == 0) return _chronoBaseSeconds;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _chronoStartedAtMs;
    return _chronoBaseSeconds + (elapsed ~/ 1000);
  }

  void _updateChronoTimer() {
    _chronoDisplayTimer?.cancel();
    _chronoDisplayTimer = null;
    if (_chronoRunning) {
      _chronoDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _chronoDisplaySeconds = _computeChronoSeconds());
        }
      });
    }
  }

  String get _chronoDisplay {
    final s = _chronoDisplaySeconds;
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$m:$sec";
  }

  void _showLiveStats(BuildContext context) => showLiveStatsBottomSheet(context);

  Future<void> _loadRole() async {
    final roles = await UserService.getCurrentRoles();
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _userRole = UserService.primaryRole(roles);
    });
  }

  static bool _teamsMatchName(String a, String b) {
    final x = a.trim().toUpperCase();
    final y = b.trim().toUpperCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    const minPrefix = 6;
    if (x.length >= minPrefix &&
        y.length >= minPrefix &&
        x.substring(0, minPrefix) == y.substring(0, minPrefix)) {
      return true;
    }
    return x.startsWith(y) || y.startsWith(x);
  }

  bool _isHomeLiveEvent(Map<String, dynamic> event) {
    final direct = event['isHome'];
    if (direct is bool) return direct;

    final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
        .toString()
        .trim()
        .toLowerCase();
    if (side == 'home' || side == 'left' || side == 'dom') return true;
    if (side == 'away' || side == 'right' || side == 'ext') return false;

    final teamIndex = event['teamIndex'];
    if (teamIndex is num) return teamIndex.toInt() == 0;

    final rawTeam = (event['team'] ?? event['teamName'] ?? '').toString();
    if (rawTeam.isNotEmpty) {
      if (_teamsMatchName(rawTeam, _liveTeam1)) return true;
      if (_teamsMatchName(rawTeam, _liveTeam2)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _heroPreviewEvents() {
    final events = _liveTimelineEvents
        .where((event) {
          final type = (event['type'] as String? ?? '').trim().toLowerCase();
          return type == 'goal' ||
              type == 'yellow' ||
              type == 'red' ||
              type == 'substitution';
        })
        .map(
          (event) => {
            ...event,
            'isHomeSide': _isHomeLiveEvent(event),
            'minuteValue': (event['minute'] is num)
                ? (event['minute'] as num).toInt()
                : int.tryParse('${event['minute'] ?? 0}') ?? 0,
          },
        )
        .toList();

    events.sort(
      (a, b) => (b['minuteValue'] as int).compareTo(a['minuteValue'] as int),
    );

    // Max 2 événements par équipe (on garde les plus récents)
    final homeEvents = events.where((e) => e['isHomeSide'] == true).take(2).toList();
    final awayEvents = events.where((e) => e['isHomeSide'] != true).take(2).toList();
    return [...homeEvents, ...awayEvents];
  }
}
