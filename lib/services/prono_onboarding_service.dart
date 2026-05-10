import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding prono D1 : une équipe favorite, persistante entre saisons (local).
class PronoOnboardingService {
  PronoOnboardingService._();

  static const _kDone = 'prono_onboarding_d1_done_v1';
  static const _kTeam = 'prono_favorite_team_v1';

  static Future<bool> isD1Done() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kDone) ?? false;
  }

  static Future<void> markD1Done() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
  }

  static Future<String?> favoriteTeam() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kTeam);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setFavoriteTeam(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTeam, name.trim());
  }
}
