import 'package:flutter/material.dart';

import '../utils/remote_image_url.dart';
import 'dvcr_network_image_web.dart'
    if (dart.library.io) 'dvcr_network_image_io.dart' as impl;

/// Décodage à la taille affichée × DPR — pas la photo source pleine.
int dvcrImageCacheWidth(
  BuildContext context,
  double logicalPx, {
  int min = 64,
  int max = 1440,
}) {
  return (logicalPx * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(min, max);
}

int dvcrStadiumCacheWidth(BuildContext context) {
  return dvcrImageCacheWidth(
    context,
    MediaQuery.sizeOf(context).width,
    min: 160,
    max: 1440,
  );
}

int dvcrCrestCacheWidth(BuildContext context, double logicalSize) {
  return dvcrImageCacheWidth(context, logicalSize, min: 64, max: 256);
}

/// Image réseau unique : skip Canva, en-têtes CDN, [cacheWidth], cache disque.
///
/// Parent toujours borné ([SizedBox], [Positioned.fill], [SizedBox.expand]) —
/// jamais [IntrinsicHeight] + largeur infinie (Huawei).
class DvcrNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final bool gaplessPlayback;

  const DvcrNetworkImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.placeholder,
    this.width,
    this.height,
    this.gaplessPlayback = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || shouldSkipNetworkImageUrl(trimmed)) {
      return errorBuilder?.call(context, Exception('skipped'), null) ??
          const SizedBox.shrink();
    }

    return impl.buildDvcrCachedNetworkImage(
      url: trimmed,
      fit: fit,
      alignment: alignment,
      cacheWidth: _positive(cacheWidth),
      cacheHeight: _positive(cacheHeight),
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
      placeholder: placeholder,
      width: width,
      height: height,
      gaplessPlayback: gaplessPlayback,
      widgetKey: ValueKey(trimmed),
    );
  }

  static final Set<String> _warmed = <String>{};

  /// Télécharge en cache disque / mémoire sans afficher — à lancer dès que
  /// l’URL est connue (onglet Pronos monté, feed matchs, etc.).
  static Future<void> warm(String url) async {
    final t = url.trim();
    if (t.isEmpty || shouldSkipNetworkImageUrl(t)) return;
    if (!_warmed.add(t)) return;
    try {
      await impl.warmDvcrCachedNetworkImage(t);
    } catch (_) {
      _warmed.remove(t);
    }
  }

  static int? _positive(int? v) => (v != null && v > 0) ? v : null;
}
