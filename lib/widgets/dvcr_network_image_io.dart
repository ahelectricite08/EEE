import 'dart:async';
import 'dart:io';

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

final Map<String, File> dvcrReadyImageFiles = {};

Future<void> warmDvcrCachedNetworkImage(String url) async {
  final t = url.trim();
  if (t.isEmpty || shouldSkipNetworkImageUrl(t)) return;
  try {
    final info = await dvcrImageCacheManager.downloadFile(
      t,
      authHeaders: kDvcrImageHttpHeaders,
    );
    dvcrReadyImageFiles[t] = info.file;
  } catch (_) {}
}

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
  Key? widgetKey,
}) {
  return _DvcrCachedFileImage(
    key: widgetKey,
    url: url,
    fit: fit,
    alignment: alignment,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: filterQuality,
    errorBuilder: errorBuilder,
    placeholder: placeholder,
    width: width,
    height: height,
    gaplessPlayback: gaplessPlayback,
  );
}

class _DvcrCachedFileImage extends StatefulWidget {
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

  const _DvcrCachedFileImage({
    super.key,
    required this.url,
    required this.fit,
    required this.alignment,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.filterQuality,
    required this.errorBuilder,
    required this.placeholder,
    required this.width,
    required this.height,
    required this.gaplessPlayback,
  });

  @override
  State<_DvcrCachedFileImage> createState() => _DvcrCachedFileImageState();
}

class _DvcrCachedFileImageState extends State<_DvcrCachedFileImage> {
  File? _file;
  Object? _error;
  StackTrace? _stack;
  StreamSubscription<FileResponse>? _sub;

  @override
  void initState() {
    super.initState();
    _file = dvcrReadyImageFiles[widget.url];
    unawaited(_hydrateFromCache(widget.url));
    _bind(widget.url);
  }

  @override
  void didUpdateWidget(covariant _DvcrCachedFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _sub?.cancel();
      _error = null;
      _stack = null;
      _file = dvcrReadyImageFiles[widget.url];
      unawaited(_hydrateFromCache(widget.url));
      _bind(widget.url);
    }
  }

  Future<void> _hydrateFromCache(String url) async {
    try {
      final cached = await dvcrImageCacheManager.getFileFromCache(url);
      if (!mounted || widget.url != url) return;
      final file = cached?.file;
      if (file == null || !file.existsSync()) return;
      dvcrReadyImageFiles[url] = file;
      setState(() {
        _file = file;
        _error = null;
        _stack = null;
      });
    } catch (_) {}
  }

  void _bind(String url) {
    _sub = dvcrImageCacheManager
        .getFileStream(url, headers: kDvcrImageHttpHeaders)
        .listen(
      (event) {
        if (event is! FileInfo || !mounted) return;
        dvcrReadyImageFiles[url] = event.file;
        setState(() {
          _file = event.file;
          _error = null;
          _stack = null;
        });
      },
      onError: (Object e, StackTrace st) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _stack = st;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.placeholder ?? const SizedBox.shrink();
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!, _stack) ?? fallback;
    }
    final file = _file;
    if (file == null) return fallback;

    return Image.file(
      file,
      fit: widget.fit,
      alignment: widget.alignment,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      filterQuality: widget.filterQuality,
      gaplessPlayback: widget.gaplessPlayback,
      errorBuilder: widget.errorBuilder ?? (_, __, ___) => fallback,
    );
  }
}
