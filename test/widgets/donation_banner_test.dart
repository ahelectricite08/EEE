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

  testWidgets('slot with URL keeps 3:1 aspect in a fixed frame', (tester) async {
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
    final size = tester.getSize(find.byType(DonationBanner));
    final innerW = size.width - (DonationBanner.horizontalInset * 2);
    expect(size.height, closeTo(innerW / DonationBanner.aspectRatio, 0.6));
    expect(DonationBanner.aspectRatio, 3);
  });
}
