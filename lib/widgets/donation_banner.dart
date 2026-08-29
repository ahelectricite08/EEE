import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/app_store_safe_mode.dart';
import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';
import 'dvcr_network_image.dart';

/// Bandeau partenaire / Soutenez — image seule, tap HelloAsso.
///
/// Distinct de [AdhesionBanner] (éditoriale photo + ivoire + CTA).
/// Image : `imageUrl` admin, sinon photo locale par défaut (comme avant).
class DonationBanner extends StatelessWidget {
  final SoutenezDvcrBannerSlot slot;
  final bool compact;

  /// Aperçu admin : ignore Firestore et affiche [preview].
  final SoutenezDvcrBannerSlotConfig? preview;
  final int previewRevisionMillis;
  final String? previewSupportUrlFallback;

  const DonationBanner({
    super.key,
    required this.slot,
    this.compact = false,
    this.preview,
    this.previewRevisionMillis = 0,
    this.previewSupportUrlFallback,
  });

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
      return _DonationBannerBody(
        config: preview!.resolvedFor(slot),
        supportUrlFallback: previewSupportUrlFallback ?? '',
        revisionMillis: previewRevisionMillis,
        compact: compact,
      );
    }

    return AppStoreMonetizationGate(
      child: StreamBuilder<SoutenezDvcrBannersSettings>(
      stream: AppSettingsService.soutenezDvcrBannersStream(),
      initialData: AppSettingsService.lastKnownSoutenezBanners,
      builder: (context, bannerSnap) {
        final banners =
            bannerSnap.data ?? AppSettingsService.lastKnownSoutenezBanners;
        final config = banners.resolved(slot);
        if (!config.enabled) return const SizedBox.shrink();

        return StreamBuilder<SupportSettings>(
          stream: AppSettingsService.supportStream(),
          builder: (context, supportSnap) {
            final supportUrl = supportSnap.data?.supportUrl ?? '';
            return _DonationBannerBody(
              config: config,
              supportUrlFallback: supportUrl,
              revisionMillis: banners.revisionMillis,
              compact: compact,
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

  /// Bandeau pub — assez haut pour un créatif entreprise. TV un peu moins.
  static const _bannerH = 172.0;
  static const _bannerHCompact = 144.0;

  final SoutenezDvcrBannerSlotConfig config;
  final String supportUrlFallback;
  final int revisionMillis;
  final bool compact;

  const _DonationBannerBody({
    required this.config,
    required this.supportUrlFallback,
    required this.revisionMillis,
    required this.compact,
  });

  String get _effectiveCtaUrl {
    final slotUrl = config.ctaUrl.trim();
    if (slotUrl.isNotEmpty) return slotUrl;
    return supportUrlFallback.trim();
  }

  int _cacheWidth(BuildContext context) {
    final inset = compact ? 32.0 : 40.0;
    final w = MediaQuery.sizeOf(context).width - inset;
    return (w * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1440);
  }

  @override
  Widget build(BuildContext context) {
    final ctaUrl = _effectiveCtaUrl;
    final tappable = ctaUrl.isNotEmpty;
    final bannerH = compact ? _bannerHCompact : _bannerH;
    final cacheW = _cacheWidth(context);

    final content = Container(
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 8, 20, 8),
      height: bannerH,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _hair, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: _PartnerBannerImage(
        imageUrl: config.imageUrl.trim(),
        revisionMillis: revisionMillis,
        cacheWidth: cacheW,
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
    if (imageUrl.isNotEmpty && !shouldSkipNetworkImageUrl(imageUrl)) {
      final busted = cacheBustedImageUrl(imageUrl, revisionMillis);
      return DvcrNetworkImage(
        busted,
        key: ValueKey('${imageUrl}_$revisionMillis'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.low,
        gaplessPlayback: false,
        errorBuilder: (_, __, ___) => _assetBanner(),
      );
    }
    return _assetBanner();
  }

  Widget _assetBanner() {
    return Image.asset(
      SoutenezDvcrBannerSlotConfig.defaultPhotoAsset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: _DonationBannerBody._well,
      ),
    );
  }
}
