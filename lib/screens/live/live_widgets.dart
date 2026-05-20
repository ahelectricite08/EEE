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

String _liveEyebrowForCategory(String category) {
  switch (category) {
    case 'resume':
      return 'A REVOIR';
    case 'podcast':
      return 'A ECOUTER';
    case 'matchday':
      return 'SUR LE TERRAIN';
    case 'all':
    default:
      return 'SELECTION DVCR';
  }
}

IconData _liveSectionIcon(String category) {
  switch (category) {
    case 'resume':
      return Icons.sports_soccer_rounded;
    case 'podcast':
      return Icons.headphones_rounded;
    case 'matchday':
      return Icons.stadium_rounded;
    case 'all':
    default:
      return Icons.play_circle_fill_rounded;
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
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: DVCRCardSkeleton(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: EmptyStatePanel(
              icon: Icons.live_tv_rounded,
              title: 'Aucune vidéo disponible',
              subtitle: 'Les prochains contenus DVCR TV apparaîtront ici.',
            ),
          );
        }

        final video = videos.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openVideo(context, video),
              child: Ink(
                decoration: BoxDecoration(
                  color: kLiveCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kLiveBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(21),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              video.youtubeThumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: kLiveGreenDeep),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(30),
                                    Colors.transparent,
                                    Colors.black.withAlpha(200),
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kLiveGold,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(60),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'À LA UNE',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const Center(child: _PlayBubble(size: 56)),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  28,
                                  14,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.05,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      liveVideoMeta(video),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withAlpha(220),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          if (video.duration.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: kLiveIvory,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kLiveBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: kLiveMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    video.duration,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: kLiveText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (video.duration.trim().isNotEmpty)
                            const SizedBox(width: 10),
                          const Spacer(),
                          _PrimaryVideoButton(
                            label: 'Lecture',
                            gold: true,
                            onTap: () => _openVideo(context, video),
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
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveSectionHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            accent: accent,
            eyebrow: _liveEyebrowForCategory(widget.category),
            icon: _liveSectionIcon(widget.category),
          ),
          FutureBuilder<List<VideoModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return SizedBox(
                  height: 248,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                    children: const [
                      SizedBox(width: 220, child: DVCRCardSkeleton()),
                      SizedBox(width: 10),
                      SizedBox(width: 220, child: DVCRCardSkeleton()),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: EmptyStatePanel(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Chargement indisponible',
                    subtitle:
                        'Cette section video n a pas pu etre mise a jour.',
                    actionLabel: 'REESSAYER',
                    onAction: _reload,
                  ),
                );
              }

              final videos = snapshot.data ?? const <VideoModel>[];
              if (videos.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: EmptyStatePanel(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Aucun contenu ici pour le moment',
                    subtitle: 'La section se remplira automatiquement.',
                  ),
                );
              }

              return SizedBox(
                height: 332,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 228,
                        child: LiveVideoTile(
                          video: video,
                          label: liveCategoryPill(widget.category),
                          accent: accent,
                          onTap: () => _openVideo(context, video),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
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

/// Boutons partage / favori sous la vignette (onglet DVCR TV).
class _LiveVideoActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _LiveVideoActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kLiveText.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final categoryLabel = label == 'DVCR TV' ? 'SELECTION' : label;
    return Material(
      color: Colors.transparent,
        child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: kLiveCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLiveBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        video.youtubeThumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: kLiveGreenDeep),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(90),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Center(child: _PlayBubble()),
                      if (video.duration.trim().isNotEmpty)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              video.duration,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withAlpha(60)),
                      ),
                      child: Text(
                        categoryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      video.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kLiveText,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      liveVideoMeta(video),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kLiveMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kLiveGreenDeep.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kLiveBorder.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _LiveVideoActionButton(
                              icon: Icons.ios_share_rounded,
                              label: 'Partager',
                              iconColor: accent,
                              onTap: () =>
                                  DvcrShare.share(ShareHelper.videoText(video)),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: kLiveBorder.withValues(alpha: 0.75),
                          ),
                          Expanded(
                            child: FirebaseAuth.instance.currentUser == null
                                ? _LiveVideoActionButton(
                                    icon: Icons.star_outline_rounded,
                                    label: 'Favori',
                                    iconColor: kLiveMuted,
                                    onTap: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Connecte-toi pour ajouter des favoris.',
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : StreamBuilder<bool>(
                                    stream: FavoritesService.watchIsFavorite(
                                      FavoriteType.video,
                                      video.id,
                                    ),
                                    builder: (context, snap) {
                                      final isFav = snap.data ?? false;
                                      return _LiveVideoActionButton(
                                        icon: isFav
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        label: isFav ? 'Enregistré' : 'Favori',
                                        iconColor: isFav ? kLiveGold : kLiveMuted,
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
                                            'date': video.date
                                                .toIso8601String(),
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 12,
                          color: kLiveMuted.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tape la carte pour lire',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: kLiveMuted.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

class _LiveSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String eyebrow;
  final Color accent;
  final IconData icon;

  const _LiveSectionHeader({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.icon,
    this.accent = kLiveGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withAlpha(70)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withAlpha(48)),
                  ),
                  child: Text(
                    eyebrow,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kLiveText,
                    letterSpacing: 0.4,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kLiveMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryVideoButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool gold;

  const _PrimaryVideoButton({
    required this.label,
    required this.onTap,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = gold ? kLiveGold : kLiveGreen;
    final fg = gold ? Colors.black : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: (gold ? kLiveGold : kLiveGreen).withAlpha(45),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 20, color: fg),
              const SizedBox(width: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayBubble extends StatelessWidget {
  final double size;

  const _PlayBubble({this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha(130),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
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
