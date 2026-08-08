import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/helloasso_adhesion_service.dart';
import '../theme/app_colors.dart';
import '../utils/remote_image_url.dart';

const _kGold = Color(0xFFC8A436);

/// Bandeau adhésion HelloAsso — entre hero et prochain match sur l'accueil.
class AdhesionBanner extends StatelessWidget {
  final String slot;

  /// Aperçu admin : ignore Firestore.
  final HelloAssoAdhesionConfig? preview;

  const AdhesionBanner({
    super.key,
    this.slot = 'home',
    this.preview,
  });

  Future<void> _openAdhesion(HelloAssoAdhesionConfig config) async {
    final url = config.buildTrackedUrl();
    if (url.isEmpty) return;
    await HelloAssoAdhesionService.instance.logBannerClick(slot: slot);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (preview != null) {
      if (!preview!.bannerEnabled) return const SizedBox.shrink();
      return _AdhesionBannerBody(
        config: preview!,
        onTap: () => _openAdhesion(preview!),
      );
    }

    return StreamBuilder<HelloAssoAdhesionConfig>(
      stream: HelloAssoAdhesionService.instance.configStream(),
      builder: (context, snap) {
        final config = snap.data ?? HelloAssoAdhesionConfig.defaults;
        if (!config.bannerEnabled) return const SizedBox.shrink();
        if (config.helloAssoUrl.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        return _AdhesionBannerBody(
          config: config,
          onTap: () => _openAdhesion(config),
        );
      },
    );
  }
}

class _AdhesionBannerBody extends StatelessWidget {
  final HelloAssoAdhesionConfig config;
  final VoidCallback onTap;

  const _AdhesionBannerBody({
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const height = 160.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      'ADHÉSION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _kGold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (config.title.trim().isNotEmpty)
                        Text(
                          config.title.trim(),
                          style: GoogleFonts.permanentMarker(
                            fontSize: 20,
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
                            fontSize: 12,
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
                              fontSize: 10,
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
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final url = config.backgroundUrl.trim();
    if (config.useCustomBackground && url.isNotEmpty) {
      return Image.network(
        cacheBustedImageUrl(url, 0),
        fit: BoxFit.cover,
        headers: kDvcrImageHttpHeaders,
        errorBuilder: (_, __, ___) => _assetBackground(),
      );
    }
    return _assetBackground();
  }

  Widget _assetBackground() {
    return Image.asset(
      HelloAssoAdhesionConfig.defaultBackgroundAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppColors.green),
    );
  }
}
