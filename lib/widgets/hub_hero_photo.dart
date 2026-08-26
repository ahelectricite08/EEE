import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';

/// Photo hero d’un onglet principal, pilotée par `app_config/hub_heroes`.
/// Champ admin vide → [fallbackNetworkUrl] puis [fallbackAsset].
/// Canva / URL `exp` périmée : pas de [NetworkImage] (évite les 403).
class HubHeroPhoto extends StatelessWidget {
  final HubHeroSlot slot;
  final Alignment alignment;
  final BoxFit fit;
  final String? fallbackNetworkUrl;
  final String? fallbackAsset;
  final Widget? fallback;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  const HubHeroPhoto({
    super.key,
    required this.slot,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.fallbackNetworkUrl,
    this.fallbackAsset,
    this.fallback,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HubHeroBannersSettings>(
      stream: AppSettingsService.hubHeroBannersStream(),
      builder: (context, snap) {
        final banners = snap.data ?? HubHeroBannersSettings.defaults;
        final hubUrl = banners.urlForSlot(slot).trim();
        final url = hubUrl.isNotEmpty
            ? hubUrl
            : (fallbackNetworkUrl ?? '').trim();
        if (url.isNotEmpty && !shouldSkipNetworkImageUrl(url)) {
          return Image.network(
            cacheBustedImageUrl(url, banners.revisionMillis),
            fit: fit,
            alignment: alignment,
            gaplessPlayback: true,
            headers: kDvcrImageHttpHeaders,
            cacheWidth: cacheWidth,
            filterQuality: filterQuality,
            errorBuilder: (_, __, ___) => _fallbackImage(),
          );
        }
        return _fallbackImage();
      },
    );
  }

  Widget _fallbackImage() {
    final asset = (fallbackAsset ?? '').trim();
    if (asset.isNotEmpty) {
      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            fallback ?? const ColoredBox(color: Color(0xFF151515)),
      );
    }
    return fallback ?? const ColoredBox(color: Color(0xFF151515));
  }
}
