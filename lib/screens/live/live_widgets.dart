import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/video_model.dart';
import '../../navigation/main_shell_insets.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/favorites_service.dart';
import '../../services/youtube_playlist_service.dart';
import '../../utils/share_helper.dart';
import '../../utils/youtube_thumbnail.dart';
import '../native_video_screen.dart';
import 'live_helpers.dart';
import 'theme/tv_theme.dart';
import 'theme/tv_type.dart';

class LiveBrowseIntro extends StatelessWidget {
  const LiveBrowseIntro({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TvCover extends StatelessWidget {
  final VideoModel video;
  final int cacheWidth;
  final FilterQuality filterQuality;

  const _TvCover({
    required this.video,
    required this.cacheWidth,
    this.filterQuality = FilterQuality.low,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubeThumbCover(
      videoId: video.cleanId,
      storedUrl: video.thumbnailUrl,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
    );
  }
}

class _TvEmpty extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _TvEmpty({
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: TvTheme.paper(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TvType.title),
              const SizedBox(height: 6),
              Text(subtitle, style: TvType.caption),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    'Réessayer',
                    style: TvType.kicker.copyWith(color: TvTheme.greenBright),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TvOverlayActions extends StatelessWidget {
  final VideoModel video;

  const _TvOverlayActions({required this.video});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TvIconBtn(
          icon: Icons.ios_share_rounded,
          tooltip: 'Partager',
          onTap: () => DvcrShare.share(
            ShareHelper.videoText(video),
            context: context,
          ),
        ),
        const SizedBox(width: 6),
        if (FirebaseAuth.instance.currentUser == null)
          _TvIconBtn(
            icon: Icons.bookmark_border_rounded,
            tooltip: 'Favori',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connecte-toi pour enregistrer des favoris.'),
                ),
              );
            },
          )
        else
          StreamBuilder<bool>(
            stream: FavoritesService.watchIsFavorite(
              FavoriteType.video,
              video.id,
            ),
            builder: (context, snap) {
              final isFav = snap.data ?? false;
              return _TvIconBtn(
                icon: isFav
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: isFav ? 'Retiré des favoris' : 'Favori',
                onTap: () => FavoritesService.toggle(
                  type: FavoriteType.video,
                  itemId: video.id,
                  title: video.title,
                  subtitle: video.category,
                  imageUrl: video.youtubeThumbnail,
                  routeHint: 'video',
                  extra: {
                    'youtubeId': video.cleanId,
                    'duration': video.duration,
                    'date': video.date.toIso8601String(),
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _TvIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TvIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TvSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TvSectionHeader({
    required this.title,
    this.subtitle = '',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 22, height: 1, color: TvTheme.green),
                const SizedBox(height: 8),
                Text(title, style: TvType.section),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle.trim(), style: TvType.meta),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 8),
                child: Text(
                  actionLabel!,
                  style: TvType.kicker.copyWith(color: TvTheme.greenBright),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TvFeaturedCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onPlay;

  const _TvFeaturedCard({required this.video, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlay,
          child: Ink(
            decoration: TvTheme.paper(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _TvCover(
                          video: video,
                          cacheWidth: tvImageCacheWidth(
                            context,
                            MediaQuery.sizeOf(context).width - 32,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: TvTheme.greenDeep.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'À LA UNE',
                                style: TvType.kickerOnPhoto.copyWith(
                                  letterSpacing: 0.8,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _TvOverlayActions(video: video),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveVideoMeta(video),
                        style: TvType.meta,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TvType.headline,
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

class LivePosterTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final String categoryLabel;

  const LivePosterTile({
    super.key,
    required this.video,
    required this.onTap,
    this.categoryLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final pill = categoryLabel.trim().isEmpty
        ? liveCategoryPill(video.category)
        : categoryLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: TvTheme.paper(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TvTheme.paperRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: _TvCover(
                      video: video,
                      cacheWidth: tvImageCacheWidth(context, 176),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _TvOverlayActions(video: video),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: TvTheme.greenDeep.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            pill,
                            style: TvType.kickerOnPhoto.copyWith(
                              fontSize: 8,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (video.duration.trim().isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              video.duration,
                              style: TvType.kickerOnPhoto.copyWith(
                                fontSize: 9,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TvType.title.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                liveVideoMeta(video),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TvType.meta,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LiveShortTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const LiveShortTile({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: TvTheme.paper(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TvTheme.paperRadius),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cacheW = tvShortsImageCacheWidth(
                      context,
                      constraints.maxWidth,
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _TvCover(
                          video: video,
                          cacheWidth: cacheW,
                          filterQuality: FilterQuality.medium,
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: TvTheme.greenDeep.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                'SHORT',
                                style: TvType.kickerOnPhoto.copyWith(
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (video.duration.trim().isNotEmpty)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                child: Text(
                                  video.duration,
                                  style: TvType.kickerOnPhoto.copyWith(
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TvType.title.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class LiveSpotlight extends StatefulWidget {
  final int refreshToken;

  const LiveSpotlight({super.key, this.refreshToken = 0});

  @override
  State<LiveSpotlight> createState() => _LiveSpotlightState();
}

class _LiveSpotlightState extends State<LiveSpotlight> {
  late Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.getLatest();
  }

  @override
  void didUpdateWidget(covariant LiveSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = YoutubePlaylistService.getLatest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 210,
              child: DecoratedBox(
                decoration: BoxDecoration(color: TvTheme.surfaceMuted),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _TvEmpty(
            title: 'Impossible de charger la une',
            subtitle: 'Vérifie ta connexion puis réessaie.',
            onRetry: _reload,
          );
        }
        final videos = snapshot.data ?? const <VideoModel>[];
        if (videos.isEmpty) {
          return const _TvEmpty(
            title: 'Aucune vidéo disponible',
            subtitle: 'Les prochains contenus DVCR TV apparaîtront ici.',
          );
        }

        final video = videos.first;
        return _TvFeaturedCard(
          video: video,
          onPlay: () => openLiveVideo(context, video),
        );
      },
    );
  }
}

class LiveShortsRail extends StatefulWidget {
  final int refreshToken;

  const LiveShortsRail({super.key, this.refreshToken = 0});

  @override
  State<LiveShortsRail> createState() => _LiveShortsRailState();
}

class _LiveShortsRailState extends State<LiveShortsRail> {
  late Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.getShorts();
  }

  @override
  void didUpdateWidget(covariant LiveShortsRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = YoutubePlaylistService.getShorts();
    });
  }

  void _openAll(List<VideoModel> videos) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TvShortsPage(initial: videos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snapshot) {
        final videos = snapshot.data;

        Widget body;
        if (!snapshot.hasData && !snapshot.hasError) {
          body = SizedBox(
            height: 248,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              children: const [
                SizedBox(width: 124, child: ColoredBox(color: TvTheme.surfaceMuted)),
                SizedBox(width: 10),
                SizedBox(width: 124, child: ColoredBox(color: TvTheme.surfaceMuted)),
                SizedBox(width: 10),
                SizedBox(width: 124, child: ColoredBox(color: TvTheme.surfaceMuted)),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          body = _TvEmpty(
            title: 'Shorts indisponibles',
            subtitle: 'La liste courte n’a pas pu être chargée.',
            onRetry: _reload,
          );
        } else if (videos == null || videos.isEmpty) {
          body = const _TvEmpty(
            title: 'Pas encore de Shorts',
            subtitle: 'Ils arriveront dès la prochaine synchro de la chaîne.',
          );
        } else {
          body = SizedBox(
            height: 268,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 124,
                    child: LiveShortTile(
                      video: video,
                      onTap: () => openLiveVideo(context, video),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TvSectionHeader(
              title: 'En 60 secondes',
              subtitle: 'Tous les Shorts de la chaîne, à part.',
              actionLabel: (videos != null && videos.isNotEmpty)
                  ? 'TOUS'
                  : null,
              onAction: (videos != null && videos.isNotEmpty)
                  ? () => _openAll(videos)
                  : null,
            ),
            body,
          ],
        );
      },
    );
  }
}

class LiveVideoCarouselSection extends StatefulWidget {
  final String title;
  final String category;
  final String subtitle;
  final int refreshToken;

  const LiveVideoCarouselSection({
    super.key,
    required this.title,
    required this.category,
    required this.subtitle,
    this.refreshToken = 0,
  });

  @override
  State<LiveVideoCarouselSection> createState() =>
      _LiveVideoCarouselSectionState();
}

class _LiveVideoCarouselSectionState extends State<LiveVideoCarouselSection> {
  late Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.forCategory(widget.category);
  }

  @override
  void didUpdateWidget(covariant LiveVideoCarouselSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = YoutubePlaylistService.forCategory(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snapshot) {
        final videos = snapshot.data;

        Widget body;
        if (!snapshot.hasData && !snapshot.hasError) {
          body = SizedBox(
            height: 168,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              children: const [
                SizedBox(width: 176, child: ColoredBox(color: TvTheme.surfaceMuted)),
                SizedBox(width: 10),
                SizedBox(width: 176, child: ColoredBox(color: TvTheme.surfaceMuted)),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          body = _TvEmpty(
            title: 'Chargement indisponible',
            subtitle: 'Cette rubrique n’a pas pu être mise à jour.',
            onRetry: _reload,
          );
        } else if (videos == null || videos.isEmpty) {
          body = const _TvEmpty(
            title: 'Aucun contenu ici pour le moment',
            subtitle: 'La rubrique se remplira automatiquement.',
          );
        } else {
          body = SizedBox(
            height: 188,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 176,
                    child: LivePosterTile(
                      video: video,
                      categoryLabel: liveCategoryPill(widget.category),
                      onTap: () => openLiveVideo(context, video),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TvSectionHeader(
              title: widget.title,
              subtitle: widget.subtitle,
            ),
            body,
          ],
        );
      },
    );
  }
}

class LiveVideoTile extends StatelessWidget {
  final VideoModel video;
  final String label;
  final VoidCallback onTap;

  const LiveVideoTile({
    super.key,
    required this.video,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LivePosterTile(
      video: video,
      categoryLabel: label == 'DVCR TV' ? 'SÉLECTION' : label,
      onTap: onTap,
    );
  }
}

void openLiveVideo(BuildContext context, VideoModel video) {
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

/// Liste dédiée — tous les Shorts, hors catalogue long.
class TvShortsPage extends StatefulWidget {
  final List<VideoModel> initial;

  const TvShortsPage({
    super.key,
    this.initial = const [],
  });

  @override
  State<TvShortsPage> createState() => _TvShortsPageState();
}

class _TvShortsPageState extends State<TvShortsPage> {
  late Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty) {
      _future = YoutubePlaylistService.getShorts(preferComplete: true);
    } else {
      _future = YoutubePlaylistService.getShorts(preferComplete: true)
          .then((all) => all.isNotEmpty ? all : widget.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvTheme.scaffold,
      appBar: AppBar(
        backgroundColor: TvTheme.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: TvTheme.text,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EN 60 SECONDES', style: TvType.kicker),
            Text('Shorts DVCR', style: TvType.section),
          ],
        ),
      ),
      body: FutureBuilder<List<VideoModel>>(
        future: _future,
        builder: (context, snap) {
          final videos = snap.data ?? widget.initial;
          if (!snap.hasData && widget.initial.isEmpty && !snap.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: TvTheme.greenBright),
            );
          }
          if (videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: TvTheme.paper(),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Aucun Short pour le moment. Tire pour actualiser l’onglet TV.',
                    style: TvType.caption,
                  ),
                ),
              ),
            );
          }
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MainShellInsets.tabScrollTail(context),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.46,
            ),
            itemCount: videos.length,
            itemBuilder: (context, i) {
              final video = videos[i];
              return LiveShortTile(
                video: video,
                onTap: () => openLiveVideo(context, video),
              );
            },
          );
        },
      ),
    );
  }
}
