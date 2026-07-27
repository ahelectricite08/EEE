import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/home_layout_hints.dart';
import '../../domain/entities/home_sections_config.dart';

HomeLayoutHints homeLayoutHintsFromMap(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return HomeLayoutHints.defaults;
  return HomeLayoutHints(
    hideDonationBannerWhenAnyLive:
        data['hideDonationBannerWhenAnyLive'] == true,
    hidePodcastBlockWhenAnyLive: data['hidePodcastBlockWhenAnyLive'] == true,
    hideDvcrTvBlockWhenAnyLive: data['hideDvcrTvBlockWhenAnyLive'] == true,
  );
}

HomeSectionsConfig homeSectionsConfigFromMap(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return HomeSectionsConfig.defaults;
  DateTime? podcastNextEventAt;
  final raw = data['podcastNextEventAt'];
  if (raw is Timestamp) {
    podcastNextEventAt = raw.toDate();
  }
  return HomeSectionsConfig(
    podcastNextEventAt: podcastNextEventAt,
    layoutHints: homeLayoutHintsFromMap(data),
  );
}
