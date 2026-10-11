import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/partner_banners.dart';

void main() {
  test('ids Storage / Firestore et spec 1200×400 3:1', () {
    expect(PartnerBanner.firestoreDocId, 'partner_banners');
    expect(PartnerBanner.storageFolder, 'partner_banners');
    expect(PartnerBanner.pixelWidth, 1200);
    expect(PartnerBanner.pixelHeight, 400);
    expect(PartnerBanner.aspectRatio, 3);
    expect(PartnerBanner.maxFileBytes, 800 * 1024);
    expect(
      PartnerBanner.specCopy,
      'Bandeau 1200×400 px (ratio 3:1), PNG / JPG / WebP, 800 Ko max.',
    );
    expect(PartnerBanner.slots, ['home', 'profile', 'live', 'articles', 'prono']);
  });

  test('ratio 3:1 accepté, 16:9 et carré trop loin', () {
    expect(PartnerBanner.isWildlyOffRatio(1200, 400), isFalse);
    expect(PartnerBanner.isWildlyOffRatio(1600, 640), isFalse);
    expect(PartnerBanner.isWildlyOffRatio(1920, 1080), isTrue);
    expect(PartnerBanner.isWildlyOffRatio(800, 800), isTrue);
    expect(PartnerBanner.isWildlyOffRatio(0, 400), isTrue);
  });

  test('catalogue lit banners[] et prend le premier actif du slot', () {
    final c = PartnerBannerCatalog.fromMap({
      'updatedAtMillis': 99,
      'banners': [
        {
          'id': 'b2',
          'imageUrl': ' https://x.test/home2.jpg ',
          'slot': 'home',
          'sort': 20,
          'active': true,
          'createdAtMillis': 2,
        },
        {
          'id': 'b1',
          'imageUrl': 'https://x.test/home1.jpg',
          'slot': 'home',
          'sort': 10,
          'active': true,
          'createdAtMillis': 1,
        },
        {
          'id': 'off',
          'imageUrl': 'https://x.test/off.jpg',
          'slot': 'home',
          'sort': 0,
          'active': false,
        },
        {
          'id': 'live',
          'imageUrl': 'https://x.test/live.jpg',
          'slot': 'live',
          'sort': 0,
          'active': true,
        },
        {'id': 'skip', 'imageUrl': '  '},
      ],
    });
    expect(c.items.length, 4);
    expect(c.revisionMillis, 99);
    expect(c.activeForSlot('home')?.id, 'b1');
    expect(c.activeForSlot('live')?.id, 'live');
    expect(c.activeForSlot('articles'), isNull);
    expect(c.byId('off')?.active, isFalse);
  });

  test('slot inconnu → home, labels FR', () {
    expect(PartnerBanner.normalizeSlot('nope'), 'home');
    expect(PartnerBanner.slotLabel('home'), 'Accueil');
    expect(PartnerBanner.slotLabel('articles'), 'Actus');
  });
}
