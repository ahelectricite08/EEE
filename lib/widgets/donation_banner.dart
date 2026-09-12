import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/app_store_safe_mode.dart';
import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';
import 'dvcr_network_image.dart';

/// Bandeau partenaire / Soutenez — image seule, tap HelloAsso.
///
/// Taille canonique = DVCR TV : [bandHeight] px, 16 px de marge latérale,
/// [BoxFit.cover] centré. Affiché seulement si le slot a sa propre URL
/// non vide **et** est activé — pas de photo club par défaut, pas de
/// repli sur Accueil.
class DonationBanner extends StatelessWidget {
  /// Hauteur du bandeau — identique à DVCR TV.
  static const double bandHeight = 144.0;

  /// Marge latérale — identique au padding TV.
  static const double horizontalInset = 16.0;

  final SoutenezDvcrBannerSlot slot;

  /// Aperçu admin : ignore Firestore et affiche [preview].
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
        config: config,
        supportUrlFallback: previewSupportUrlFallback ?? '',
        revisionMillis: previewRevisionMillis,
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
          if (!_shouldRender(config)) return const SizedBox.shrink();

          return StreamBuilder<SupportSettings>(
            stream: AppSettingsService.supportStream(),
            builder: (context, supportSnap) {
              final supportUrl = supportSnap.data?.supportUrl ?? '';
              return _DonationBannerBody(
                config: config,
                supportUrlFallback: supportUrl,
                revisionMillis: banners.revisionMillis,
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

  final SoutenezDvcrBannerSlotConfig config;
  final String supportUrlFallback;
  final int revisionMillis;

  const _DonationBannerBody({
    required this.config,
    required this.supportUrlFallback,
    required this.revisionMillis,
  });

  String get _effectiveCtaUrl {
    final slotUrl = config.ctaUrl.trim();
    if (slotUrl.isNotEmpty) return slotUrl;
    return supportUrlFallback.trim();
  }

  int _cacheWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width -
        (DonationBanner.horizontalInset * 2);
    return (w * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1440);
  }

  @override
  Widget build(BuildContext context) {
    final ctaUrl = _effectiveCtaUrl;
    final tappable = ctaUrl.isNotEmpty;
    final cacheW = _cacheWidth(context);

    final content = Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DonationBanner.horizontalInset,
      ),
      height: DonationBanner.bandHeight,
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
    final displayUrl = upgradeWixStaticMediaUrl(imageUrl);
    if (displayUrl.isNotEmpty && !shouldSkipNetworkImageUrl(displayUrl)) {
      final busted = cacheBustedImageUrl(displayUrl, revisionMillis);
      return DvcrNetworkImage(
        busted,
        key: ValueKey('${displayUrl}_$revisionMillis'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
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
