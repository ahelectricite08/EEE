import 'package:flutter/material.dart';

import 'remote_image_url.dart';

const _kYoutubeThumbFiles = <String>[
  'maxresdefault.jpg',
  'sddefault.jpg',
  'hq720.jpg',
  'hqdefault.jpg',
];

bool _isYoutubeThumbHost(String host) {
  final h = host.toLowerCase();
  return h.contains('ytimg.com') ||
      h == 'img.youtube.com' ||
      h == 'i.ytimg.com' ||
      h.endsWith('.ytimg.com');
}

/// Thumbs YouTube HD, du plus net au plus sûr.
///
/// Une URL stockée hors YouTube (cover custom) reste en tête.
/// Les `default` / `mqdefault` / `hqdefault` YouTube sont ignorées au profit
/// de maxresdefault → sddefault → hq720 → hqdefault.
List<String> youtubeThumbCandidates(String videoId, {String? stored}) {
  final id = videoId.trim();
  final built = id.isEmpty
      ? const <String>[]
      : [
          for (final file in _kYoutubeThumbFiles)
            'https://i.ytimg.com/vi/$id/$file',
        ];

  final storedUrl = stored?.trim() ?? '';
  if (storedUrl.isEmpty) return built;

  final uri = Uri.tryParse(storedUrl);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return built;
  }
  if (!_isYoutubeThumbHost(uri.host)) {
    return <String>{storedUrl, ...built}.toList();
  }
  return built.isNotEmpty ? built : <String>[storedUrl];
}

String bestYoutubeThumbnailUrl(String videoId, {String? stored}) {
  final candidates = youtubeThumbCandidates(videoId, stored: stored);
  if (candidates.isNotEmpty) return candidates.first;
  return stored?.trim() ?? '';
}

/// Cover réseau avec repli YouTube (maxres 404 / placeholder 120×90).
class YoutubeThumbCover extends StatefulWidget {
  final String videoId;
  final String? storedUrl;
  final int cacheWidth;
  final FilterQuality filterQuality;
  final BoxFit fit;
  final Alignment alignment;

  const YoutubeThumbCover({
    super.key,
    required this.videoId,
    this.storedUrl,
    required this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  State<YoutubeThumbCover> createState() => _YoutubeThumbCoverState();
}

class _YoutubeThumbCoverState extends State<YoutubeThumbCover> {
  late List<String> _urls;
  int _index = 0;
  ImageStream? _probe;
  ImageStreamListener? _probeListener;

  @override
  void initState() {
    super.initState();
    _urls = _resolveUrls();
  }

  @override
  void didUpdateWidget(covariant YoutubeThumbCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.storedUrl != widget.storedUrl) {
      _unbindProbe();
      _urls = _resolveUrls();
      _index = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _probeCurrent();
  }

  @override
  void dispose() {
    _unbindProbe();
    super.dispose();
  }

  List<String> _resolveUrls() {
    final list = youtubeThumbCandidates(
      widget.videoId,
      stored: widget.storedUrl,
    );
    return list.where((u) => u.trim().isNotEmpty).toList();
  }

  void _unbindProbe() {
    if (_probe != null && _probeListener != null) {
      _probe!.removeListener(_probeListener!);
    }
    _probe = null;
    _probeListener = null;
  }

  void _probeCurrent() {
    _unbindProbe();
    if (!mounted || _urls.isEmpty) return;
    final url = _urls[_index];
    if (!url.contains('maxresdefault')) return;

    final provider = NetworkImage(url, headers: kDvcrImageHttpHeaders);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        if (info.image.width <= 160 || info.image.height <= 120) {
          _advanceFrom(url);
        }
      },
      onError: (_, __) {
        if (mounted) _advanceFrom(url);
      },
    );
    _probe = stream;
    _probeListener = listener;
    stream.addListener(listener);
  }

  void _advanceFrom(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _index >= _urls.length - 1) return;
      if (_urls[_index] != url) return;
      setState(() => _index += 1);
      _probeCurrent();
    });
  }

  int get _safeCacheWidth {
    final w = widget.cacheWidth;
    if (w <= 0) return 480;
    return w.clamp(160, 1280);
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return const ColoredBox(color: Color(0xFF151515));
    }
    return Image.network(
      _urls[_index],
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      filterQuality: widget.filterQuality,
      cacheWidth: _safeCacheWidth,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (_, __, ___) {
        _advanceFrom(_urls[_index]);
        return const ColoredBox(color: Color(0xFF151515));
      },
    );
  }
}
