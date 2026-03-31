import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class NativeVideoScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const NativeVideoScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  State<NativeVideoScreen> createState() => _NativeVideoScreenState();
}

class _NativeVideoScreenState extends State<NativeVideoScreen> {
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  bool _loading = true;
  bool _useFallback = false; // WebView fallback si extraction échoue

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(widget.videoId);
      yt.close();

      if (manifest.muxed.isEmpty) throw Exception('no muxed streams');

      // On prend la meilleure qualité disponible (max 720p pour muxed)
      final stream = manifest.muxed.sortByVideoQuality().last;
      final url = stream.url.toString();

      _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpCtrl!.initialize();

      _chewieCtrl = ChewieController(
        videoPlayerController: _vpCtrl!,
        autoPlay: true,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: const ColoredBox(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFBA203C),
          handleColor: const Color(0xFFBA203C),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      );

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      // Fallback : WebView YouTube
      if (mounted) setState(() { _loading = false; _useFallback = true; });
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useFallback) return _WebFallback(videoId: widget.videoId, title: widget.title);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFBA203C)),
                  SizedBox(height: 16),
                  Text('Chargement...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          : Center(
              child: AspectRatio(
                aspectRatio: _vpCtrl!.value.aspectRatio,
                child: Chewie(controller: _chewieCtrl!),
              ),
            ),
    );
  }
}

// ── Fallback WebView si youtube_explode échoue ────────────────────────────────
class _WebFallback extends StatefulWidget {
  final String videoId;
  final String title;
  const _WebFallback({required this.videoId, required this.title});
  @override
  State<_WebFallback> createState() => _WebFallbackState();
}

class _WebFallbackState extends State<_WebFallback> {
  late final WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36')
      ..loadRequest(Uri.parse('https://m.youtube.com/watch?v=${widget.videoId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white54, size: 20),
            onPressed: () => launchUrl(
              Uri.parse('https://youtube.com/watch?v=${widget.videoId}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}
