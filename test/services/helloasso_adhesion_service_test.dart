import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/services/helloasso_adhesion_service.dart';

void main() {
  group('HelloAssoAdhesionService.isAdherentActive', () {
    test('guests and logged-in non-members are not active', () {
      expect(HelloAssoAdhesionService.isAdherentActive(null), isFalse);
      expect(HelloAssoAdhesionService.isAdherentActive({}), isFalse);
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'role': 'admin',
          'helloAsso': {'isAdherentActive': false},
        }),
        isFalse,
      );
    });

    test('active flag hides splash/banner even for admin/CM', () {
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'role': 'admin',
          'helloAsso': {'isAdherentActive': true},
        }),
        isTrue,
      );
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'roles': ['community_manager'],
          'helloAsso': {'isAdherentActive': true},
        }),
        isTrue,
      );
    });

    test('expired adherentExpiresAt is not active', () {
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'helloAsso': {
            'isAdherentActive': true,
            'adherentExpiresAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
          },
        }),
        isFalse,
      );
    });

    test('future adherentExpiresAt stays active', () {
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'helloAsso': {
            'isAdherentActive': true,
            'adherentExpiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 30)),
            ),
          },
        }),
        isTrue,
      );
    });
  });

  group('adhesion campaign vs adherent expiry', () {
    final campaignEnd = DateTime(2026, 12, 31, 23, 59, 59);
    final futureExpiry = DateTime(2027, 7, 31, 23, 59, 59);

    HelloAssoAdhesionConfig cfg({
      bool splash = true,
      bool banner = true,
      String url = 'https://helloasso.com/adhesion',
      String support = 'https://helloasso.com/soutien',
      DateTime? campaign,
    }) {
      return HelloAssoAdhesionConfig(
        adherentExpiresAt: futureExpiry,
        adhesionCampaignEndsAt: campaign ?? campaignEnd,
        splashEnabled: splash,
        bannerEnabled: banner,
        helloAssoUrl: url,
        helloAssoSupportUrl: support,
      );
    }

    test('default campaign end is 31 Dec of current season', () {
      expect(
        HelloAssoAdhesionConfig.defaultCampaignEndsAt(now: DateTime(2026, 8, 28)),
        DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(
        HelloAssoAdhesionConfig.defaultCampaignEndsAt(now: DateTime(2027, 1, 15)),
        DateTime(2026, 12, 31, 23, 59, 59),
      );
    });

    test('missing adhesionCampaignEndsAt uses season default', () {
      final parsed = HelloAssoAdhesionConfig.fromMap({
        'adherentExpiresAt': Timestamp.fromDate(futureExpiry),
      });
      expect(parsed.adherentExpiresAt, futureExpiry);
      expect(
        parsed.adhesionCampaignEndsAt,
        HelloAssoAdhesionConfig.defaultCampaignEndsAt(),
      );
    });

    test('splash needs campaign open + switch + adhesion URL', () {
      expect(HelloAssoAdhesionConfig.defaults.shouldShowSplash(), isFalse);
      expect(
        cfg().shouldShowSplash(DateTime(2026, 12, 15)),
        isTrue,
      );
      expect(
        cfg().shouldShowSplash(DateTime(2027, 1, 1)),
        isFalse,
      );
      expect(
        cfg(splash: false).shouldShowSplash(DateTime(2026, 12, 15)),
        isFalse,
      );
      expect(
        cfg(url: '').shouldShowSplash(DateTime(2026, 12, 15)),
        isFalse,
      );
    });

    test('campaign closed does not affect isAdherentActive', () {
      expect(
        HelloAssoAdhesionService.isAdherentActive({
          'helloAsso': {
            'isAdherentActive': true,
            'adherentExpiresAt': Timestamp.fromDate(futureExpiry),
          },
        }),
        isTrue,
      );
    });

    test('home banner: adhesion while campaign open, support after', () {
      final open = DateTime(2026, 12, 15);
      final closed = DateTime(2027, 1, 1);
      expect(
        cfg().shouldShowHomeBanner(isAdherentActive: false, now: open),
        isTrue,
      );
      expect(
        cfg().shouldShowHomeBanner(isAdherentActive: true, now: open),
        isFalse,
      );
      expect(
        cfg().shouldShowHomeBanner(isAdherentActive: true, now: closed),
        isFalse,
      );
      expect(
        cfg().shouldShowHomeBanner(isAdherentActive: false, now: closed),
        isTrue,
      );
      expect(
        cfg(support: '').shouldShowHomeBanner(isAdherentActive: false, now: closed),
        isFalse,
      );
      expect(
        cfg(url: '').shouldShowHomeBanner(isAdherentActive: false, now: open),
        isFalse,
      );
    });

    test('banner copy and URL switch after campaign end', () {
      final openCfg = cfg();
      expect(openCfg.isAdhesionCampaignOpen(DateTime(2026, 12, 31, 23, 59, 59)), isTrue);
      expect(
        openCfg.buildBannerTrackedUrl(now: DateTime(2026, 12, 15)),
        contains('helloasso.com/adhesion'),
      );
      expect(
        openCfg.buildBannerTrackedUrl(now: DateTime(2027, 1, 1)),
        contains('helloasso.com/soutien'),
      );
      expect(
        openCfg.buildBannerTrackedUrl(now: DateTime(2027, 1, 1)),
        contains('utm_medium=support_banner'),
      );
    });
  });

  group('HelloAssoAdhesionService imported amount label', () {
    test('numbers import at 0 is unknown, not 0 €', () {
      expect(
        HelloAssoAdhesionService.isImportedAmountUnknown({
          'amount': 0,
          'importSource': 'numbers_file_import',
          'paymentId': 'numbers_import_2026-2027_a@b.fr',
        }),
        isTrue,
      );
      expect(
        HelloAssoAdhesionService.adhesionAmountLabel(
          {
            'amount': 0,
            'metadata': {'source': 'numbers_file_import'},
          },
          formatMoney: (v) => '${v.toStringAsFixed(0)} €',
        ),
        'Import HelloAsso · montant inconnu',
      );
    });

    test('real HelloAsso amount is still formatted', () {
      expect(
        HelloAssoAdhesionService.isImportedAmountUnknown({
          'amount': 35,
          'source': 'helloasso',
        }),
        isFalse,
      );
      expect(
        HelloAssoAdhesionService.adhesionAmountLabel(
          {'amount': 35},
          formatMoney: (v) => '${v.toStringAsFixed(0)} €',
        ),
        '35 €',
      );
    });
  });
}
