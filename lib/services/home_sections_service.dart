import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_settings_service.dart';

/// Préférences d’affichage home (document `config/home_sections`).
class HomeLayoutHints {
  final bool hideDonationBannerWhenAnyLive;
  final bool hidePodcastBlockWhenAnyLive;
  final bool hideDvcrTvBlockWhenAnyLive;

  const HomeLayoutHints({
    required this.hideDonationBannerWhenAnyLive,
    required this.hidePodcastBlockWhenAnyLive,
    required this.hideDvcrTvBlockWhenAnyLive,
  });

  static const HomeLayoutHints defaults = HomeLayoutHints(
    hideDonationBannerWhenAnyLive: false,
    hidePodcastBlockWhenAnyLive: false,
    hideDvcrTvBlockWhenAnyLive: false,
  );

  factory HomeLayoutHints.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return defaults;
    return HomeLayoutHints(
      hideDonationBannerWhenAnyLive:
          data['hideDonationBannerWhenAnyLive'] == true,
      hidePodcastBlockWhenAnyLive:
          data['hidePodcastBlockWhenAnyLive'] == true,
      hideDvcrTvBlockWhenAnyLive: data['hideDvcrTvBlockWhenAnyLive'] == true,
    );
  }
}

class HomeSectionsService {
  static final DocumentReference<Map<String, dynamic>> _ref =
      AppSettingsService.configDoc('home_sections');

  static Stream<Map<String, dynamic>> stream() {
    return AppSettingsService.configStream('home_sections');
  }

  static Stream<HomeLayoutHints> layoutHintsStream() {
    return stream().map(HomeLayoutHints.fromMap);
  }

  static Future<void> saveLayoutHints(HomeLayoutHints hints) async {
    await _ref.set({
      'hideDonationBannerWhenAnyLive': hints.hideDonationBannerWhenAnyLive,
      'hidePodcastBlockWhenAnyLive': hints.hidePodcastBlockWhenAnyLive,
      'hideDvcrTvBlockWhenAnyLive': hints.hideDvcrTvBlockWhenAnyLive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setPodcastNextEvent(DateTime dateTime) async {
    await _ref.set({
      'podcastNextEventAt': Timestamp.fromDate(dateTime),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> clearPodcastNextEvent() async {
    await _ref.set({
      'podcastNextEventAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
