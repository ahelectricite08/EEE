import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dvcr_share_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/video_model.dart';
import '../services/favorites_service.dart';
import '../utils/share_helper.dart';
import 'native_video_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kBorder = Color(0xFF1E1E1E);

class VideoWebScreen extends StatelessWidget {
  final VideoModel video;
  final bool isLive;

  const VideoWebScreen({super.key, required this.video, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    if (!isLive) {
      return NativeVideoScreen(
        videoId: video.cleanId,
        title: video.title,
        video: video,
      );
    }
    // Live stream → WebView
    return _LiveWebScreen(video: video);
  }
}

class _LiveWebScreen extends StatefulWidget {
  final VideoModel video;
  const _LiveWebScreen({required this.video});
  @override
  State<_LiveWebScreen> createState() => _LiveWebScreenState();
}

class _LiveWebScreenState extends State<_LiveWebScreen> {
  late final WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36')
      ..loadRequest(Uri.parse('https://m.youtube.com/watch?v=${widget.video.cleanId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.video.title,
          style: GoogleFonts.oswald(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white70),
            onPressed: () =>
                DvcrShare.share(ShareHelper.videoText(widget.video)),
          ),
          if (FirebaseAuth.instance.currentUser?.uid != null)
            StreamBuilder<bool>(
              stream: FavoritesService.watchIsFavorite(
                FavoriteType.video,
                widget.video.id,
              ),
              builder: (context, snap) {
                final isFav = snap.data ?? false;
                return IconButton(
                  tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? const Color(0xFFC9A227) : Colors.white54,
                  ),
                  onPressed: () => FavoritesService.toggle(
                    type: FavoriteType.video,
                    itemId: widget.video.id,
                    title: widget.video.title,
                    subtitle: widget.video.category,
                    imageUrl: widget.video.youtubeThumbnail,
                    routeHint: 'video',
                    extra: {
                      'youtubeId': widget.video.cleanId,
                      'duration': widget.video.duration,
                      'date': widget.video.date.toIso8601String(),
                    },
                  ),
                );
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder)),
      ),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}
