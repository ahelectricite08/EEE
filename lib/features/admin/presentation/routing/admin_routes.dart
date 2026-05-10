import '../../../../screens/admin/admin_nav_model.dart';

/// Segments URL canoniques (web) : `/#/admin/<segment>` ou chemin `/admin/<segment>`.
abstract final class AdminRoutes {
  static const String basePath = '/admin';

  static const Map<String, int> segmentToTab = {
    'dashboard': AdminTabIndex.dashboard,
    'direct': AdminTabIndex.direct,
    'articles': AdminTabIndex.articles,
    'matchs': AdminTabIndex.matchs,
    'stats': AdminTabIndex.stats,
    'notifs': AdminTabIndex.notifs,
    'users': AdminTabIndex.users,
    'communaute': AdminTabIndex.communaute,
    'stades': AdminTabIndex.stades,
    'xp': AdminTabIndex.xp,
    'settings': AdminTabIndex.settings,
    'logs': AdminTabIndex.logs,
    'tournoi': AdminTabIndex.tournament,
  };

  static String? segmentForTab(int tab) {
    for (final e in segmentToTab.entries) {
      if (e.value == tab) return e.key;
    }
    return null;
  }

  /// Parse `location` (path ou hash), ex. `/admin/logs`, `#/admin/settings`.
  static int? tabIndexFromLocation(String location) {
    final normalized = location.trim();
    if (normalized.isEmpty) return null;
    var path = normalized;
    final hashIdx = path.indexOf('#');
    if (hashIdx >= 0) {
      path = path.substring(hashIdx + 1);
    }
    if (path.startsWith('/')) path = path.substring(1);
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts.first == 'admin' && parts.length >= 2) {
      return segmentToTab[parts[1].toLowerCase()];
    }
    return segmentToTab[parts.last.toLowerCase()];
  }
}
