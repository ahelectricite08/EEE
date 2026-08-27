import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';
import 'dvcr_network_image.dart';

/// Photo hero d’un onglet principal, pilotée par `app_config/hub_heroes`.
/// Champ admin vide → [fallbackNetworkUrl] puis [fallbackAsset].
/// Canva / URL `exp` périmée : pas de [NetworkImage] (évite les 403).
///
/// Une instance par [slot] : pas de [gaplessPlayback] inter-onglets (ça
/// garderait l’ancienne photo le temps du décodage).
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
    if (!AppSettingsService.firebaseReady) {
      return KeyedSubtree(
        key: ValueKey('hub-hero-${slot.name}'),
        child: _resolve(AppSettingsService.lastKnownHubHeroBanners),
      );
    }
    return KeyedSubtree(
      key: ValueKey('hub-hero-${slot.name}'),
      child: StreamBuilder<HubHeroBannersSettings>(
        stream: AppSettingsService.hubHeroBannersStream(),
        initialData: AppSettingsService.lastKnownHubHeroBanners,
        builder: (context, snap) {
          return _resolve(
            snap.data ?? AppSettingsService.lastKnownHubHeroBanners,
          );
        },
      ),
    );
  }

  Widget _resolve(HubHeroBannersSettings banners) {
    final hubUrl = banners.urlForSlot(slot).trim();
    final url = hubUrl.isNotEmpty
        ? hubUrl
        : (fallbackNetworkUrl ?? '').trim();
    if (url.isNotEmpty && !shouldSkipNetworkImageUrl(url)) {
      final busted = cacheBustedImageUrl(url, banners.revisionMillis);
      return DvcrNetworkImage(
        busted,
        key: ValueKey('hub-hero-${slot.name}-$busted'),
        fit: fit,
        alignment: alignment,
        gaplessPlayback: false,
        cacheWidth: cacheWidth,
        filterQuality: filterQuality,
        placeholder: fallback ?? const ColoredBox(color: Color(0xFF151515)),
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
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
