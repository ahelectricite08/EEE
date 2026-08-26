import 'package:flutter/material.dart';

import '../utils/remote_image_url.dart';

/// Web : cache HTTP du navigateur + decode [cacheWidth].
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
  return Image.network(
    url,
    fit: fit,
    alignment: alignment,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: filterQuality,
    headers: kDvcrImageHttpHeaders,
    gaplessPlayback: gaplessPlayback,
    loadingBuilder: placeholder == null
        ? null
        : (context, child, progress) =>
            progress == null ? child : placeholder,
    errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink(),
  );
}
