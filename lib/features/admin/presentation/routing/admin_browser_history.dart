import 'package:flutter/foundation.dart';

import 'admin_browser_history_stub.dart'
    if (dart.library.html) 'admin_browser_history_web.dart' as impl;

/// Met à jour l’URL du navigateur (web) sans recharger — ex. `#/admin/logs`.
void syncAdminBrowserPath(String path) {
  if (!kIsWeb || path.isEmpty) return;
  impl.adminBrowserReplacePath(path);
}
