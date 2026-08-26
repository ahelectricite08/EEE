import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/remote_image_url.dart';

final CacheManager dvcrImageCacheManager = CacheManager(
  Config(
    'dvcrImageCache',
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 220,
  ),
);

/// Mobile : fichier disque via [flutter_cache_manager], decode [cacheWidth].
Widget buildDvcrCachedNetworkImage({
  required String url,
  required BoxFit fit,
  required Alignment alignment,
  int? cacheWidth,
  int? cacheHeight,
  required FilterQuality filterQuality,
  ImageErrorWidgetBuilder? errorBuilder,
  Widget? placeholder,
  double? width,
  double? height,
  required bool gaplessPlayback,
}) {
  return StreamBuilder<FileResponse>(
    stream: dvcrImageCacheManager.getFileStream(
      url,
      headers: kDvcrImageHttpHeaders,
    ),
    builder: (context, snap) {
      if (snap.hasError) {
        return errorBuilder?.call(context, snap.error!, snap.stackTrace) ??
            const SizedBox.shrink();
      }
      final data = snap.data;
      if (data is FileInfo) {
        return Image.file(
          data.file,
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return placeholder ?? const SizedBox.shrink();
    },
  );
}
