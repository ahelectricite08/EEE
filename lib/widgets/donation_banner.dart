import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/app_store_safe_mode.dart';
import '../services/app_settings_service.dart';
import '../services/partner_banners_service.dart';
import '../utils/remote_image_url.dart';
import 'dvcr_network_image.dart';

/// Bandeau partenaire — cadre **3:1** fixe (1200×400).
///
/// Source 1 : catalogue admin Storage (`app_config/partner_banners`).
/// Source 2 : URL Wix collée dans Soutenez, seulement si le slot n’a
/// aucun encart actif. Tap → lien encart, sinon CTA Soutenez / HelloAsso.
class DonationBanner extends StatelessWidget {
  /// Ratio canonique — identique à [PartnerBanner.aspectRatio].
  static const double aspectRatio = PartnerBanner.aspectRatio;

  /// Marge latérale — identique au padding TV.
  static const double horizontalInset = 16.0;

  final SoutenezDvcrBannerSlot slot;

  /// Aperçu admin Soutenez : ignore le catalogue et Firestore live.
  final SoutenezDvcrBannerSlotConfig? preview;
  final int previewRevisionMillis;
  final String? previewSupportUrlFallback;

  const DonationBanner({
    super.key,
    required this.slot,
    this.preview,
    this.previewRevisionMillis = 0,
    this.previewSupportUrlFallback,
  });

  static bool _shouldRender(SoutenezDvcrBannerSlotConfig config) {
    return config.enabled && config.imageUrl.trim().isNotEmpty;
  }

  static Future<void> _openLink(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (preview != null) {
      final config = preview!.resolvedFor(slot);
      if (!_shouldRender(config)) return const SizedBox.shrink();
      return _DonationBannerBody(
        imageUrl: config.imageUrl.trim(),
        ctaUrl: config.ctaUrl.trim().isNotEmpty
            ? config.ctaUrl.trim()
            : (previewSupportUrlFallback ?? '').trim(),
        revisionMillis: previewRevisionMillis,
      );
    }

    return AppStoreMonetizationGate(
      child: StreamBuilder<PartnerBannerCatalog>(
        stream: PartnerBannersService.instance.watchCatalog(),
        initialData: PartnerBannersService.lastKnown,
        builder: (context, catalogSnap) {
          final catalog =
              catalogSnap.data ?? PartnerBannersService.lastKnown;
          final fromCatalog = catalog.activeForSlot(slot.name);

          return StreamBuilder<SoutenezDvcrBannersSettings>(
            stream: AppSettingsService.soutenezDvcrBannersStream(),
            initialData: AppSettingsService.lastKnownSoutenezBanners,
            builder: (context, bannerSnap) {
              final banners = bannerSnap.data ??
                  AppSettingsService.lastKnownSoutenezBanners;
              final fallback = banners.resolved(slot);

              final imageUrl = fromCatalog != null
                  ? fromCatalog.imageUrl.trim()
                  : (DonationBanner._shouldRender(fallback)
                      ? fallback.imageUrl.trim()
                      : '');
              if (imageUrl.isEmpty) return const SizedBox.shrink();

              return StreamBuilder<SupportSettings>(
                stream: AppSettingsService.supportStream(),
                builder: (context, supportSnap) {
                  final supportUrl = supportSnap.data?.supportUrl ?? '';
                  final catalogLink = (fromCatalog?.linkUrl ?? '').trim();
                  final ctaUrl = catalogLink.isNotEmpty
                      ? catalogLink
                      : (fallback.ctaUrl.trim().isNotEmpty
                          ? fallback.ctaUrl.trim()
                          : supportUrl.trim());
                  return _DonationBannerBody(
                    imageUrl: imageUrl,
                    ctaUrl: ctaUrl,
                    revisionMillis: fromCatalog != null
                        ? catalog.revisionMillis
                        : banners.revisionMillis,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DonationBannerBody extends StatelessWidget {
  static const _paper = Color(0xFFFFFDF8);
  static const _hair = Color(0xFFE6E0D1);
  static const _well = Color(0xFFEDE7D9);

  final String imageUrl;
  final String ctaUrl;
  final int revisionMillis;

  const _DonationBannerBody({
    required this.imageUrl,
    required this.ctaUrl,
    required this.revisionMillis,
  });

  int _cacheWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width -
        (DonationBanner.horizontalInset * 2);
    return (w * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1440);
  }

  @override
  Widget build(BuildContext context) {
    final tappable = ctaUrl.trim().isNotEmpty;
    final cacheW = _cacheWidth(context);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonationBanner.horizontalInset,
      ),
      child: AspectRatio(
        aspectRatio: DonationBanner.aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _hair, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ColoredBox(
              color: _well,
              child: _PartnerBannerImage(
                imageUrl: imageUrl.trim(),
                revisionMillis: revisionMillis,
                cacheWidth: cacheW,
              ),
            ),
          ),
        ),
      ),
    );

    if (!tappable) return content;
    return GestureDetector(
      onTap: () => DonationBanner._openLink(ctaUrl),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _PartnerBannerImage extends StatelessWidget {
  final String imageUrl;
  final int revisionMillis;
  final int cacheWidth;

  const _PartnerBannerImage({
    required this.imageUrl,
    required this.revisionMillis,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final displayUrl = upgradeWixStaticMediaUrl(imageUrl);
    if (displayUrl.isNotEmpty && !shouldSkipNetworkImageUrl(displayUrl)) {
      final busted = cacheBustedImageUrl(displayUrl, revisionMillis);
      return DvcrNetworkImage(
        busted,
        key: ValueKey('${displayUrl}_$revisionMillis'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.low,
        gaplessPlayback: false,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: _DonationBannerBody._well,
        ),
      );
    }
    return const ColoredBox(color: _DonationBannerBody._well);
  }
}
