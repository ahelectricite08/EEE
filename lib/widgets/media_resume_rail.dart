import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/home/presentation/widgets/home_theme.dart';
import '../features/home/presentation/widgets/home_type.dart';
import '../models/media_resume.dart';
import '../screens/live/theme/tv_theme.dart';
import '../screens/live/theme/tv_type.dart';
import '../screens/native_video_screen.dart';
import '../services/media_resume_store.dart';
import '../services/podcast_controller.dart';
import '../utils/youtube_thumbnail.dart';
import 'dvcr_network_image.dart';
import 'media_resume_progress_bar.dart';

enum MediaResumeRailTone { home, tv }

class MediaResumeRail extends StatefulWidget {
  final MediaResumeRailTone tone;

  const MediaResumeRail({super.key, required this.tone});

  @override
  State<MediaResumeRail> createState() => _MediaResumeRailState();
}

class _MediaResumeRailState extends State<MediaResumeRail> {
  @override
  void initState() {
    super.initState();
    unawaited(MediaResumeStore.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MediaResumeStore.instance,
      builder: (context, _) {
        final items = MediaResumeStore.instance.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final tv = widget.tone == MediaResumeRailTone.tv;
        return Padding(
          padding: EdgeInsets.only(top: tv ? 22 : 0, bottom: tv ? 0 : 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tv)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _HomeRule(),
                ),
              tv ? const _TvHeader() : const _HomeHeader(),
              SizedBox(
                height: 188,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 176,
                        child: _ResumeCard(
                          item: item,
                          tv: tv,
                          onTap: () => openMediaResume(context, item),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void openMediaResume(BuildContext context, MediaResumeItem item) {
  if (item.isPodcast) {
    unawaited(PodcastController.instance.playResume(item));
    return;
  }
  final video = item.asVideo;
  if (video == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NativeVideoScreen(
        videoId: video.cleanId,
        title: video.title,
        video: video,
      ),
    ),
  );
}

class _HomeRule extends StatelessWidget {
  const _HomeRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: HomeTheme.hairline),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeTheme.gutter,
        0,
        HomeTheme.gutter,
        HomeTheme.headerToBody,
      ),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: HomeTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REPRENDRE', style: HomeType.section),
                const SizedBox(height: 4),
                Text(
                  'Là où tu t’étais arrêté',
                  style: HomeType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  const _TvHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 22, height: 1, color: TvTheme.green),
          const SizedBox(height: 8),
          Text('Reprendre', style: TvType.section),
          const SizedBox(height: 4),
          Text(
            'Là où tu t’étais arrêté — VOD et podcast',
            style: TvType.meta,
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final MediaResumeItem item;
  final bool tv;
  final VoidCallback onTap;

  const _ResumeCard({
    required this.item,
    required this.tv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = tv
        ? TvType.title.copyWith(fontSize: 16)
        : HomeType.title.copyWith(fontSize: 16);
    final metaStyle = tv ? TvType.meta : HomeType.meta;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: tv ? TvTheme.paper() : HomeTheme.paper(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ResumeCover(item: item),
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x73000000),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xE0062921),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            item.isPodcast ? 'PODCAST' : 'VOD',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MediaResumeProgressBar(fraction: item.fraction),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 2),
          Text(
            MediaResumeLabels.remaining(item.positionMs, item.durationMs),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
        ],
      ),
    );
  }
}

class _ResumeCover extends StatelessWidget {
  final MediaResumeItem item;

  const _ResumeCover({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl?.trim() ?? '';
    if (item.isVideo && (url.isNotEmpty || item.id.isNotEmpty)) {
      final thumb = url.isNotEmpty
          ? url
          : bestYoutubeThumbnailUrl(item.id);
      return DvcrNetworkImage(
        thumb,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: dvcrImageCacheWidth(context, 220),
        errorBuilder: (_, __, ___) => const _PodcastFallback(),
      );
    }
    return const _PodcastFallback();
  }
}

class _PodcastFallback extends StatelessWidget {
  const _PodcastFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0A4438),
      child: Center(
        child: Icon(Icons.headphones_rounded, color: Colors.white70, size: 32),
      ),
    );
  }
}
