import 'package:cloud_firestore/cloud_firestore.dart';

/// Pilotage « fin de saison » / reprise (`app_config/season_lifecycle`).
class SeasonLifecycleConfig {
  final bool betweenSeasons;
  final String homeHeadline;
  final String homeSubline;
  final String upcomingWaitTitle;
  final String upcomingWaitSubtitle;

  const SeasonLifecycleConfig({
    required this.betweenSeasons,
    required this.homeHeadline,
    required this.homeSubline,
    required this.upcomingWaitTitle,
    required this.upcomingWaitSubtitle,
  });

  static const SeasonLifecycleConfig defaults = SeasonLifecycleConfig(
    betweenSeasons: false,
    homeHeadline: 'La saison va bientôt démarrer',
    homeSubline:
        'Le club se prépare — le stade Louis-Dugauguez te attend pour la suite.',
    upcomingWaitTitle: 'Patiente un peu…',
    upcomingWaitSubtitle: 'La saison va reprendre. Les résultats et le '
        'classement restent disponibles dans l’onglet Calendrier.',
  );

  static const String firestoreDocId = 'season_lifecycle';

  factory SeasonLifecycleConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null || d.isEmpty) return defaults;
    bool b(String key, bool def) {
      final v = d[key];
      if (v is bool) return v;
      return def;
    }

    String s(String key, String def) {
      final v = d[key]?.toString().trim();
      return (v == null || v.isEmpty) ? def : v;
    }

    return SeasonLifecycleConfig(
      betweenSeasons: b('betweenSeasons', defaults.betweenSeasons),
      homeHeadline: s('homeHeadline', defaults.homeHeadline),
      homeSubline: s('homeSubline', defaults.homeSubline),
      upcomingWaitTitle: s('upcomingWaitTitle', defaults.upcomingWaitTitle),
      upcomingWaitSubtitle:
          s('upcomingWaitSubtitle', defaults.upcomingWaitSubtitle),
    );
  }

  factory SeasonLifecycleConfig.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return SeasonLifecycleConfig.fromMap(snap.data());
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'betweenSeasons': betweenSeasons,
      'homeHeadline': homeHeadline,
      'homeSubline': homeSubline,
      'upcomingWaitTitle': upcomingWaitTitle,
      'upcomingWaitSubtitle': upcomingWaitSubtitle,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
