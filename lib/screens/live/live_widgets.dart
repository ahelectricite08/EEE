import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dvcr_share_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/video_model.dart';
import '../../services/favorites_service.dart';
import '../../services/youtube_playlist_service.dart';
import '../../utils/share_helper.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/empty_state_panel.dart';
import '../native_video_screen.dart';
import 'live_helpers.dart';
import 'live_palette.dart';

Color _liveAccentForCategory(String category) {
  switch (category) {
    case 'resume':
      return kLiveGold;
    case 'podcast':
      return const Color(0xFF8A55D4);
    case 'matchday':
      return kLiveOrange;
    case 'all':
    default:
      return kLiveGreen;
  }
}

IconData _liveCategoryIcon(String category) {
  switch (category) {
    case 'resume':
      return Icons.sports_soccer_rounded;
    case 'podcast':
      return Icons.mic_rounded;
    case 'matchday':
      return Icons.stadium_rounded;
    case 'all':
    default:
      return Icons.local_fire_department_rounded;
  }
}

/// Intro sous la une DVCR TV — supprimée.
class LiveBrowseIntro extends StatelessWidget {
  const LiveBrowseIntro({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Partage + favori compacts sur la vignette (sans barre sous le titre).
class _LiveVideoOverlayActions extends StatelessWidget {
  final VideoModel video;
  final Color accent;

  const _LiveVideoOverlayActions({
    required this.video,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiveVideoGlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Partager',
          iconColor: Colors.white,
          onTap: () => DvcrShare.share(ShareHelper.videoText(video)),
        ),
        const SizedBox(width: 6),
        if (FirebaseAuth.instance.currentUser == null)
          _LiveVideoGlassIconButton(
            icon: Icons.star_outline_rounded,
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
              return _LiveVideoGlassIconButton(
                icon: isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                tooltip: isFav ? 'Retiré des favoris' : 'Favori',
                iconColor: isFav ? kLiveGold : Colors.white.withAlpha(245),
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

class _LiveVideoGlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const _LiveVideoGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(155),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: iconColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Ligne fixe sous la status bar (comme l’accueil) : pastille + lien chaîne.
class LiveHeroPinnedToolbar extends StatelessWidget {
  const LiveHeroPinnedToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kLiveGold.withAlpha(36),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(100)),
            ),
            child: Text(
              'CHAÎNE OFFICIELLE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse(
                  'https://www.youtube.com/@drapeauvertcartonrouge',
                ),
                mode: LaunchMode.externalApplication,
              ),
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'YOUTUBE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Image de fond pleine + [FlexibleSpaceBar] en parallax (même principe que l’accueil).
class LiveHeroFlexibleSpace extends StatelessWidget {
  const LiveHeroFlexibleSpace({super.key});

  static const _heroAsset = 'assets/images/JOURDEMATCH.jpg';

  @override
  Widget build(BuildContext context) {
    Widget heroImage() {
      return Image.asset(
        _heroAsset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.15),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF151515),
          alignment: Alignment.center,
          child: Icon(
            Icons.live_tv_rounded,
            size: 48,
            color: Colors.white.withAlpha(60),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: heroImage()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(130),
                  Colors.black.withAlpha(55),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
        ),
        FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: heroImage()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(230),
                        kLiveGreen.withAlpha(120),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.78],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DVCR TV',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Replays, émissions, podcasts et moments forts du club.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(230),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hero statique (hors Sliver), même look que la page TV.
class LiveHeroHeader extends StatelessWidget {
  const LiveHeroHeader({super.key});

  static const _asset = 'assets/images/JOURDEMATCH.jpg';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                _asset,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
                errorBuilder: (_, _, _) => Container(color: const Color(0xFF151515)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(100),
                      Colors.black.withAlpha(55),
                      kLiveGreen.withAlpha(200),
                      kLiveGreenDeep,
                    ],
                    stops: const [0.0, 0.35, 0.72, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LiveHeroPinnedToolbar(),
                    const Spacer(),
                    Text(
                      'DVCR TV',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Replays, émissions, podcasts et moments forts du club.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(230),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titre de rangée + sous-titre (carrousels DVCR TV).
class _LiveNetflixRowHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _LiveNetflixRowHeader({
    required this.title,
    required this.accent,
    this.subtitle = '',
    this.icon = Icons.play_circle_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withAlpha(38),
                  accent.withAlpha(12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(70)),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: kLiveText,
                    letterSpacing: 0.3,
                    height: 1,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle.trim(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: kLiveMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero « à la une » plein cadre, boutons Lecture / Détails.
class _LiveNetflixFeaturedHero extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onPlay;

  const _LiveNetflixFeaturedHero({
    required this.video,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kLiveCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kLiveBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: onPlay,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    video.youtubeThumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) =>
                        Container(color: kLiveGreenDeep),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(100),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kLiveGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'À LA UNE',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w900,
                          color: Colors.black, letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: _LiveVideoOverlayActions(video: video, accent: kLiveGold),
                  ),
                  Center(
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white60, width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Zone texte séparée ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: kLiveText, height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      liveVideoMeta(video),
                      style: GoogleFonts.inter(fontSize: 11, color: kLiveMuted, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: kLiveGreen,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              'Lecture',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Vignette carrousel : affiche cinéma + actions sur l’image.
class LiveNetflixPosterTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  final Color accent;
  final String categoryLabel;

  const LiveNetflixPosterTile({
    super.key,
    required this.video,
    required this.onTap,
    this.accent = kLiveGreen,
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(28),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Image.network(
                      video.youtubeThumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: kLiveGreenDeep),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(150),
                              Colors.transparent,
                              Colors.black.withAlpha(40),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 40,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _LiveVideoOverlayActions(
                      video: video,
                      accent: accent,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(220),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pill,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.35,
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(190),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kLiveText,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                liveVideoMeta(video),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: kLiveMuted,
                ),
              ),
            ],
          ),
        ),
      ],
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
            child: DVCRCardSkeleton(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmptyStatePanel(
              icon: Icons.live_tv_rounded,
              title: 'Impossible de charger la une',
              subtitle: 'Verifie ta connexion puis reessaie.',
              actionLabel: 'REESSAYER',
              onAction: _reload,
            ),
          );
        }
        final videos = snapshot.data ?? const <VideoModel>[];
        if (videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyStatePanel(
              icon: Icons.live_tv_rounded,
              title: 'Aucune vidéo disponible',
              subtitle: 'Les prochains contenus DVCR TV apparaîtront ici.',
            ),
          );
        }

        final video = videos.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _LiveNetflixFeaturedHero(
            video: video,
            onPlay: () => _openVideo(context, video),
          ),
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
    final accent = _liveAccentForCategory(widget.category);
    return Padding(
      padding: EdgeInsets.zero,
      child: FutureBuilder<List<VideoModel>>(
        future: _future,
        builder: (context, snapshot) {
          final videos = snapshot.data;

          Widget body;
          if (!snapshot.hasData && !snapshot.hasError) {
            body = SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                children: const [
                  SizedBox(width: 176, child: DVCRCardSkeleton()),
                  SizedBox(width: 10),
                  SizedBox(width: 176, child: DVCRCardSkeleton()),
                  SizedBox(width: 10),
                  SizedBox(width: 176, child: DVCRCardSkeleton()),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            body = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyStatePanel(
                icon: Icons.play_circle_outline_rounded,
                title: 'Chargement indisponible',
                subtitle: 'Cette section vidéo n’a pas pu être mise à jour.',
                actionLabel: 'REESSAYER',
                onAction: _reload,
              ),
            );
          } else if (videos == null || videos.isEmpty) {
            body = const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: EmptyStatePanel(
                icon: Icons.play_circle_outline_rounded,
                title: 'Aucun contenu ici pour le moment',
                subtitle: 'La section se remplira automatiquement.',
              ),
            );
          } else {
            body = SizedBox(
              height: 200,
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
                      child: LiveNetflixPosterTile(
                        video: video,
                        accent: accent,
                        categoryLabel: liveCategoryPill(widget.category),
                        onTap: () => _openVideo(context, video),
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
              _LiveNetflixRowHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                accent: accent,
                icon: _liveCategoryIcon(widget.category),
              ),
              body,
            ],
          );
        },
      ),
    );
  }
}

// ── Grille verticale par catégorie (utilisée dans les onglets) ───────────────
class LiveVideoGridSection extends StatefulWidget {
  final String category;
  final int refreshToken;

  const LiveVideoGridSection({
    super.key,
    required this.category,
    this.refreshToken = 0,
  });

  @override
  State<LiveVideoGridSection> createState() => _LiveVideoGridSectionState();
}

class _LiveVideoGridSectionState extends State<LiveVideoGridSection>
    with AutomaticKeepAliveClientMixin {
  late Future<List<VideoModel>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.forCategory(widget.category);
  }

  @override
  void didUpdateWidget(covariant LiveVideoGridSection oldWidget) {
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
    super.build(context);
    final accent = _liveAccentForCategory(widget.category);
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: EmptyStatePanel(
              icon: Icons.play_circle_outline_rounded,
              title: 'Impossible de charger les videos',
              subtitle: 'Reessaie dans quelques instants.',
              actionLabel: 'REESSAYER',
              onAction: _reload,
            ),
          );
        }
        final videos = snap.data!;
        if (videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: EmptyStatePanel(
              icon: Icons.play_circle_outline_rounded,
              title: 'Aucun contenu pour le moment',
              subtitle: 'Cette section se remplira automatiquement.',
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.64,
            ),
            itemCount: videos.length,
            itemBuilder: (context, i) => LiveVideoTile(
              video: videos[i],
              label: liveCategoryPill(widget.category),
              accent: accent,
              onTap: () => _openVideo(context, videos[i]),
            ),
          ),
        );
      },
    );
  }
}

/// Tuile grille (même look que les carrousels).
class LiveVideoTile extends StatelessWidget {
  final VideoModel video;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  const LiveVideoTile({
    super.key,
    required this.video,
    required this.label,
    required this.onTap,
    this.accent = kLiveGreen,
  });

  @override
  Widget build(BuildContext context) {
    return LiveNetflixPosterTile(
      video: video,
      accent: accent,
      categoryLabel: label == 'DVCR TV' ? 'SÉLECTION' : label,
      onTap: onTap,
    );
  }
}

void _openVideo(BuildContext context, VideoModel video) {
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
