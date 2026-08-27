import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/remote_image_url.dart';

Future<void> warmDvcrCachedNetworkImage(String url) async {
  final t = url.trim();
  if (t.isEmpty || shouldSkipNetworkImageUrl(t)) return;
  final stream = NetworkImage(
    t,
    headers: kDvcrImageHttpHeaders,
  ).resolve(const ImageConfiguration());
  final done = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, __) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
    onError: (_, __) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  return done.future;
}

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
  Key? widgetKey,
}) {
  return Image.network(
    url,
    key: widgetKey,
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
