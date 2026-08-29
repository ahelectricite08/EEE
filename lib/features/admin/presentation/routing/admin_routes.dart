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
    'rappel-match': AdminTabIndex.matchReminder,
    'users': AdminTabIndex.users,
    'communaute': AdminTabIndex.communaute,
    'chat': AdminTabIndex.communaute,
    'stades': AdminTabIndex.stades,
    'equipes-stades': AdminTabIndex.stades,
    'xp': AdminTabIndex.xp,
    'settings': AdminTabIndex.settings,
    'android-tv': AdminTabIndex.tv,
    'tv': AdminTabIndex.tv,
    'logs': AdminTabIndex.logs,
    'benevoles': AdminTabIndex.benevoles,
    'adherents': AdminTabIndex.adherents,
    'adhesion': AdminTabIndex.adherents,
    'pronos': AdminTabIndex.pronos,
    'prono': AdminTabIndex.pronos,
    'jeux': AdminTabIndex.pronos,
    'staff': AdminTabIndex.staff,
    'permissions': AdminTabIndex.staff,
    'badges': AdminTabIndex.badges,
    'visuels': AdminTabIndex.visuels,
    'photos': AdminTabIndex.visuels,
    'heroes': AdminTabIndex.visuels,
    'reseaux': AdminTabIndex.visuels,
    'association': AdminTabIndex.adherents,
    'helloasso': AdminTabIndex.adherents,
    'partenaires': AdminTabIndex.adherents,
    'reward': AdminTabIndex.reward,
    'tombola': AdminTabIndex.reward,
    'quiz': AdminTabIndex.reward,
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
