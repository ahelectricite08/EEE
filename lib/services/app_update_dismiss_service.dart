import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise le « Plus tard » sur une bannière de mise à jour optionnelle.
class AppUpdateDismissService {
  AppUpdateDismissService._();

  static String _key() {
    if (kIsWeb) return 'app_update_dismissed_build_web';
    return Platform.isIOS
        ? 'app_update_dismissed_build_ios'
        : 'app_update_dismissed_build_android';
  }

  static Future<int?> getDismissedBuild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key());
  }

  /// Ne plus afficher la bannière tant que [latestBuild] reste ≤ ce numéro.
  static Future<void> dismissUntilNewerThan(int latestBuild) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(), latestBuild);
  }
}
