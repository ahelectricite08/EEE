import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/remote_image_url.dart';

const _kGold = Color(0xFFC8A436);

/// Bannière « Soutenez DVCR » / sponsor — alimentée par
/// `app_config/soutenez_dvcr_banners` (slot) + fallback lien `app_config/support`.
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

    return StreamBuilder<SoutenezDvcrBannersSettings>(
      stream: AppSettingsService.soutenezDvcrBannersStream(),
      builder: (context, bannerSnap) {
        final banners = bannerSnap.data ?? SoutenezDvcrBannersSettings.defaults;
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
    );
  }
}

class _DonationBannerBody extends StatelessWidget {
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

  bool get _imageOnly =>
      config.badgeLabel.trim().isEmpty &&
      config.title.trim().isEmpty &&
      config.subtitle.trim().isEmpty &&
      config.ctaLabel.trim().isEmpty &&
      config.sponsorName.trim().isEmpty;

  String get _effectiveCtaUrl {
    final slotUrl = config.ctaUrl.trim();
    if (slotUrl.isNotEmpty) return slotUrl;
    return supportUrlFallback.trim();
  }

  @override
  Widget build(BuildContext context) {
    final height = compact ? 145.0 : 160.0;
    final ctaUrl = _effectiveCtaUrl;
    final tappable = ctaUrl.isNotEmpty;

    final content = Container(
      margin: EdgeInsets.fromLTRB(
        14,
        compact ? 0 : 8,
        14,
        compact ? 0 : 8,
      ),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColorsLight.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withAlpha(100), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (!_imageOnly) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColorsLight.scaffold.withAlpha(40),
                    AppColors.green.withAlpha(200),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColorsLight.textPrimary.withAlpha(140),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: compact ? 10 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (config.badgeLabel.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kGold.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _kGold.withAlpha(120)),
                          ),
                          child: Text(
                            config.badgeLabel.trim().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w800,
                              color: _kGold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      if (config.sponsorName.trim().isNotEmpty) ...[
                        if (config.badgeLabel.trim().isNotEmpty)
                          const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            config.sponsorName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (config.title.trim().isNotEmpty)
                        Text(
                          config.title.trim(),
                          style: GoogleFonts.permanentMarker(
                            fontSize: compact ? 16 : 20,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black45,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      if (config.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          config.subtitle.trim(),
                          style: GoogleFonts.inter(
                            fontSize: compact ? 11 : 12,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ],
                      if (config.ctaLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(230),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            config.ctaLabel.trim().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!tappable) return content;
    return GestureDetector(
      onTap: () => DonationBanner._openLink(ctaUrl),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildBackground() {
    final url = config.imageUrl.trim();
    if (url.isNotEmpty) {
      final displayUrl = cacheBustedImageUrl(url, revisionMillis);
      return Image.network(
        displayUrl,
        fit: BoxFit.cover,
        headers: kDvcrImageHttpHeaders,
        errorBuilder: (_, __, ___) => _assetBackground(),
      );
    }
    return _assetBackground();
  }

  Widget _assetBackground() {
    return Image.asset(
      SoutenezDvcrBannerSlotConfig.defaultPhotoAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppColors.green),
    );
  }
}
