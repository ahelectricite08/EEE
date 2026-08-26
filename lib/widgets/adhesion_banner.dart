import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/helloasso_adhesion_service.dart';
import '../utils/remote_image_url.dart';

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
  static const _ivory = Color(0xFFF4F0E6);
  static const _paper = Color(0xFFFFFDF8);
  static const _hair = Color(0xFFE6E0D1);
  static const _ink = Color(0xFF0A1C18);
  static const _green = Color(0xFF0A4438);
  static const _muted = Color(0xFF5E6662);
  static const _photoH = 148.0;

  final HelloAssoAdhesionConfig config;
  final VoidCallback onTap;

  const _AdhesionBannerBody({
    required this.config,
    required this.onTap,
  });

  int _cacheWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 40;
    return (w * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(160, 1440);
  }

  @override
  Widget build(BuildContext context) {
    final title = config.title.trim();
    final subtitle = config.subtitle.trim();
    final cta = config.ctaLabel.trim();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _hair, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _photoH,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildBackground(context),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.35, 1.0],
                            colors: [
                              Color(0x140A1C18),
                              Color(0x990A1C18),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 12,
                        child: Text(
                          'ASSOCIATION',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.02,
                            letterSpacing: -0.2,
                            color: _ink,
                          ),
                        ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: _muted,
                          ),
                        ),
                      ],
                      if (cta.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              cta.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: _green,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: _green,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: _green,
                child: SizedBox(width: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final url = config.backgroundUrl.trim();
    final cacheW = _cacheWidth(context);
    if (config.useCustomBackground &&
        url.isNotEmpty &&
        !shouldSkipNetworkImageUrl(url)) {
      return Image.network(
        cacheBustedImageUrl(url, 0),
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.15),
        headers: kDvcrImageHttpHeaders,
        cacheWidth: cacheW,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _assetBackground(context),
      );
    }
    return _assetBackground(context);
  }

  Widget _assetBackground(BuildContext context) {
    return Image.asset(
      HelloAssoAdhesionConfig.defaultBackgroundAsset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, 0.15),
      cacheWidth: _cacheWidth(context),
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const ColoredBox(color: _ivory),
    );
  }
}
