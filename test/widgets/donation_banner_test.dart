import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/services/app_settings_service.dart';
import 'package:dvcr/widgets/donation_banner.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('empty slot URL renders nothing', (tester) async {
    await tester.pumpWidget(
      _host(
        const DonationBanner(
          slot: SoutenezDvcrBannerSlot.home,
          preview: SoutenezDvcrBannerSlotConfig(
            enabled: true,
            imageUrl: '',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DonationBanner)), Size.zero);
  });

  testWidgets('disabled slot with URL renders nothing', (tester) async {
    await tester.pumpWidget(
      _host(
        const DonationBanner(
          slot: SoutenezDvcrBannerSlot.articles,
          preview: SoutenezDvcrBannerSlotConfig(
            enabled: false,
            imageUrl: 'https://example.com/banner.jpg',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DonationBanner)), Size.zero);
  });

  testWidgets('slot with URL uses TV band height', (tester) async {
    await tester.pumpWidget(
      _host(
        const DonationBanner(
          slot: SoutenezDvcrBannerSlot.live,
          preview: SoutenezDvcrBannerSlotConfig(
            enabled: true,
            imageUrl: 'https://example.com/tv.jpg',
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(DonationBanner)).height,
      DonationBanner.bandHeight,
    );
  });
}
