/// CTA billetterie sur la fiche match de l’accueil.
/// Firestore `app_config/match_ticketing`.
class MatchTicketing {
  static const String firestoreDocId = 'match_ticketing';

  final bool enabled;
  final String url;

  const MatchTicketing({
    this.enabled = false,
    this.url = '',
  });

  static const MatchTicketing defaults = MatchTicketing();

  /// Switch ON + URL http(s). Ne suffit pas seul : l’accueil exige aussi un match domicile.
  bool get showOnHome {
    if (!enabled) return false;
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  /// Accueil : config OK **et** CSSA / Sedan à domicile (`isSedanTeam(team1)`).
  bool visibleOnHome({required bool sedanIsHome}) =>
      showOnHome && sedanIsHome;

  Uri? get launchUri {
    if (!showOnHome) return null;
    return Uri.tryParse(url.trim());
  }

  factory MatchTicketing.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return MatchTicketing(
      enabled: data['enabled'] == true,
      url: (data['url'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'url': url.trim(),
      };
}
