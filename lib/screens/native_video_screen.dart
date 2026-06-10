import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dvcr_share_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/video_model.dart';
import '../services/favorites_service.dart';
import '../utils/share_helper.dart';

class NativeVideoScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final VideoModel? video;

  const NativeVideoScreen({
    super.key,
    required this.videoId,
    required this.title,
    this.video,
  });

  @override
  State<NativeVideoScreen> createState() => _NativeVideoScreenState();
}

class _NativeVideoScreenState extends State<NativeVideoScreen> {
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  bool _loading = true;
  bool _useFallback = false;

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
    if (_useFallback) {
      return _WebFallback(
        videoId: widget.videoId,
        title: widget.title,
        video: widget.video,
      );
    }

    final v = widget.video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context, v),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFC8A436)),
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

  AppBar _buildAppBar(BuildContext context, VideoModel? v) {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFF222222)),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.title,
        style: GoogleFonts.barlowCondensed(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (v != null) ...[
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white60, size: 20),
            onPressed: () => DvcrShare.share(ShareHelper.videoText(v), context: context),
          ),
          if (FirebaseAuth.instance.currentUser?.uid != null)
            StreamBuilder<bool>(
              stream: FavoritesService.watchIsFavorite(FavoriteType.video, v.id),
              builder: (context, snap) {
                final isFav = snap.data ?? false;
                return IconButton(
                  tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                  icon: Icon(
                    isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isFav ? const Color(0xFFC8A436) : Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => FavoritesService.toggle(
                    type: FavoriteType.video,
                    itemId: v.id,
                    title: v.title,
                    subtitle: v.category,
                    imageUrl: v.youtubeThumbnail,
                    routeHint: 'video',
                    extra: {
                      'youtubeId': v.cleanId,
                      'duration': v.duration,
                      'date': v.date.toIso8601String(),
                    },
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

// ── Fallback WebView ──────────────────────────────────────────────────────────
class _WebFallback extends StatefulWidget {
  final String videoId;
  final String title;
  final VideoModel? video;

  const _WebFallback({required this.videoId, required this.title, this.video});

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
    final v = widget.video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF222222)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.barlowCondensed(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (v != null) ...[
            IconButton(
              tooltip: 'Partager',
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white60, size: 20),
              onPressed: () => DvcrShare.share(ShareHelper.videoText(v), context: context),
            ),
            if (FirebaseAuth.instance.currentUser?.uid != null)
              StreamBuilder<bool>(
                stream: FavoritesService.watchIsFavorite(FavoriteType.video, v.id),
                builder: (context, snap) {
                  final isFav = snap.data ?? false;
                  return IconButton(
                    tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                    icon: Icon(
                      isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isFav ? const Color(0xFFC8A436) : Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => FavoritesService.toggle(
                      type: FavoriteType.video,
                      itemId: v.id,
                      title: v.title,
                      subtitle: v.category,
                      imageUrl: v.youtubeThumbnail,
                      routeHint: 'video',
                      extra: {
                        'youtubeId': v.cleanId,
                        'duration': v.duration,
                        'date': v.date.toIso8601String(),
                      },
                    ),
                  );
                },
              ),
          ],
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
