import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/services/app_settings_service.dart';

void main() {
  group('SoutenezDvcrBannersSettings.resolved', () {
    test('does not copy Accueil image onto other slots', () {
      const settings = SoutenezDvcrBannersSettings(
        home: SoutenezDvcrBannerSlotConfig(
          imageUrl: 'https://example.com/home.jpg',
        ),
        live: SoutenezDvcrBannerSlotConfig(
          imageUrl: 'https://example.com/tv.jpg',
        ),
      );

      expect(
        settings.resolved(SoutenezDvcrBannerSlot.home).imageUrl,
        'https://example.com/home.jpg',
      );
      expect(
        settings.resolved(SoutenezDvcrBannerSlot.live).imageUrl,
        'https://example.com/tv.jpg',
      );
      expect(
        settings.resolved(SoutenezDvcrBannerSlot.articles).imageUrl,
        isEmpty,
      );
      expect(
        settings.resolved(SoutenezDvcrBannerSlot.prono).imageUrl,
        isEmpty,
      );
      expect(
        settings.resolved(SoutenezDvcrBannerSlot.profile).imageUrl,
        isEmpty,
      );
    });

    test('empty slot stays empty even when Accueil has an image', () {
      const settings = SoutenezDvcrBannersSettings(
        home: SoutenezDvcrBannerSlotConfig(
          enabled: true,
          imageUrl: 'https://example.com/home.jpg',
        ),
        articles: SoutenezDvcrBannerSlotConfig(enabled: true, imageUrl: ''),
      );
      final articles = settings.resolved(SoutenezDvcrBannerSlot.articles);
      expect(articles.enabled, isTrue);
      expect(articles.imageUrl, isEmpty);
    });
  });
}
