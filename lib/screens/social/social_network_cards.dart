import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/video_model.dart';
import '../../services/youtube_playlist_service.dart';
import '../../utils/youtube_thumbnail.dart';
import 'social_brand_mark.dart';
import 'social_links_catalog.dart';

const _kPaper = Color(0xFFFFFDF8);
const _kBorder = Color(0xFFD8D2C4);
const _kText = Color(0xFF173C31);
const _kMuted = Color(0xFF5C6560);
const _kGreen = Color(0xFF0A4438);

int _cacheWidth(BuildContext context, double logicalPx) {
  return (logicalPx * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

class SocialSectionLabel extends StatelessWidget {
  final String label;
  const SocialSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.35,
          color: _kGreen,
        ),
      ),
    );
  }
}

class SocialNetworkCard extends StatelessWidget {
  final SocialNetworkSpec spec;
  final int index;

  const SocialNetworkCard({
    super.key,
    required this.spec,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final child = spec.kind == SocialCardKind.feature
        ? _FeatureCard(spec: spec)
        : _SheetCard(spec: spec);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SheetCard extends StatelessWidget {
  final SocialNetworkSpec spec;
  const _SheetCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          SocialLinksActions.open(context, spec.url);
        },
        onLongPress: () => SocialLinksActions.copy(context, spec.url),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                SocialBrandMark(brand: spec.brand, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                          height: 1.0,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (spec.handle.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          spec.handle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        spec.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${spec.cta}  →',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final SocialNetworkSpec spec;
  const _FeatureCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;
    final coverH = (width * 9 / 16).clamp(148.0, 196.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          SocialLinksActions.open(context, spec.url);
        },
        onLongPress: () => SocialLinksActions.copy(context, spec.url),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: SizedBox(
                  height: coverH,
                  width: width,
                  child: _YoutubeCover(cacheWidth: _cacheWidth(context, width)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SocialBrandMark(brand: spec.brand, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec.title,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _kText,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spec.handle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spec.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _kMuted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${spec.cta}  →',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YoutubeCover extends StatefulWidget {
  final int cacheWidth;
  const _YoutubeCover({required this.cacheWidth});

  @override
  State<_YoutubeCover> createState() => _YoutubeCoverState();
}

class _YoutubeCoverState extends State<_YoutubeCover> {
  late final Future<List<VideoModel>> _latest;

  @override
  void initState() {
    super.initState();
    _latest = YoutubePlaylistService.getLatest();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _latest,
      builder: (context, snap) {
        VideoModel? video;
        final list = snap.data;
        if (list != null) {
          for (final v in list) {
            if (!v.hidden && v.cleanId.isNotEmpty) {
              video = v;
              break;
            }
          }
        }
        if (video == null) {
          return const ColoredBox(
            color: Color(0xFF151515),
            child: Center(
              child: SocialBrandMark(brand: SocialBrand.youtube, size: 52),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            YoutubeThumbCover(
              videoId: video.cleanId,
              storedUrl: video.thumbnailUrl,
              cacheWidth: widget.cacheWidth,
              filterQuality: FilterQuality.low,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x66000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              right: 12,
              child: Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
