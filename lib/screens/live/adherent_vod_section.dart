import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/adherent_vod.dart';
import '../../models/video_model.dart';
import '../../navigation/app_store_safe_mode.dart';
import '../../services/adherent_vod_service.dart';
import '../../services/helloasso_adhesion_service.dart';
import '../../services/youtube_playlist_service.dart';
import '../../utils/youtube_thumbnail.dart';
import 'live_helpers.dart';
import 'live_widgets.dart';
import 'theme/tv_theme.dart';
import 'theme/tv_type.dart';

/// Rubrique DVCR TV — VOD réservées aux adhérents HelloAsso.
class LiveAdherentVodSection extends StatefulWidget {
  final int refreshToken;

  const LiveAdherentVodSection({super.key, this.refreshToken = 0});

  @override
  State<LiveAdherentVodSection> createState() => _LiveAdherentVodSectionState();
}

class _LiveAdherentVodSectionState extends State<LiveAdherentVodSection> {
  final Map<String, Future<List<VideoModel>>> _playlists = {};

  @override
  void didUpdateWidget(covariant LiveAdherentVodSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      YoutubePlaylistService.clearPublicPlaylistCache();
      _playlists.clear();
    }
  }

  Future<List<VideoModel>> _ensurePlaylist(String playlistId) {
    return _playlists.putIfAbsent(
      playlistId,
      () => AdherentVodService.instance.loadPlaylist(playlistId),
    );
  }

  Future<void> _openAdhesion() async {
    final config = HelloAssoAdhesionService.instance.lastKnownConfig;
    final url = config.buildTrackedUrl(mediumOverride: 'vod_adherents');
    if (url.isEmpty) return;
    await HelloAssoAdhesionService.instance.logBannerClick(slot: 'vod_adherents');
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppStoreMonetizationGate(
      child: StreamBuilder<AdherentVodConfig>(
      stream: AdherentVodService.instance.watch(),
      initialData: AdherentVodService.instance.lastKnown,
      builder: (context, configSnap) {
        final config = configSnap.data ?? AdherentVodConfig.defaults;
        if (!config.showInApp) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: StreamBuilder<AdherentVodAccess>(
            stream: AdherentVodService.instance.watchAccess(),
            builder: (context, accessSnap) {
              final access = accessSnap.data ?? AdherentVodAccess.locked;
              final seasons = config.visibleSeasons;
              if (seasons.isEmpty) {
                return _AdherentVodMissingPlaylist(onAdhesion: _openAdhesion);
              }
              final anyLocked =
                  seasons.any((s) => !access.canWatch(s.id));
              final anyUnlocked =
                  seasons.any((s) => access.canWatch(s.id));
              final adhesion = HelloAssoAdhesionService
                  .instance.lastKnownConfig.canOpenHelloAsso;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdherentHeader(
                    unlocked: anyUnlocked,
                    showHint: anyLocked,
                  ),
                  for (var i = 0; i < seasons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _SeasonVodRail(
                      season: seasons[i],
                      unlocked: access.canWatch(seasons[i].id),
                      future: _ensurePlaylist(seasons[i].playlistId),
                      onRetry: () {
                        YoutubePlaylistService.clearPublicPlaylistCache();
                        setState(() => _playlists.remove(seasons[i].playlistId));
                      },
                    ),
                  ],
                  if (anyLocked && adhesion)
                    _AdhesionJoinButton(onTap: _openAdhesion),
                ],
              );
            },
          ),
        );
      },
    ),
    );
  }
}

class _AdherentVodMissingPlaylist extends StatelessWidget {
  final VoidCallback onAdhesion;

  const _AdherentVodMissingPlaylist({required this.onAdhesion});

  @override
  Widget build(BuildContext context) {
    final adhesion =
        HelloAssoAdhesionService.instance.lastKnownConfig.canOpenHelloAsso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AdherentHeader(unlocked: false, showHint: false),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _AdherentPaper(
            title: 'Playlist manquante',
            subtitle:
                'La rubrique est activée, mais aucune playlist YouTube n’est renseignée côté admin.',
          ),
        ),
        if (adhesion) _AdhesionJoinButton(onTap: onAdhesion),
      ],
    );
  }
}

class _SeasonVodRail extends StatelessWidget {
  final AdherentVodSeason season;
  final bool unlocked;
  final Future<List<VideoModel>> future;
  final VoidCallback onRetry;

  const _SeasonVodRail({
    required this.season,
    required this.unlocked,
    required this.future,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'SAISON ${season.label}',
                  style: TvType.kicker.copyWith(
                    color: TvTheme.greenBright,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 16,
                color: unlocked ? TvTheme.greenBright : TvTheme.goldDeep,
              ),
            ],
          ),
        ),
        FutureBuilder<List<VideoModel>>(
          future: future,
          builder: (context, videoSnap) {
            return _AdherentVodBody(
              unlocked: unlocked,
              seasonId: season.id,
              loading: !videoSnap.hasData && !videoSnap.hasError,
              error: videoSnap.hasError,
              videos: videoSnap.data ?? const [],
              onRetry: onRetry,
            );
          },
        ),
      ],
    );
  }
}

class _AdherentVodBody extends StatelessWidget {
  final bool unlocked;
  final String seasonId;
  final bool loading;
  final bool error;
  final List<VideoModel> videos;
  final VoidCallback onRetry;

  const _AdherentVodBody({
    required this.unlocked,
    required this.seasonId,
    required this.loading,
    required this.error,
    required this.videos,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
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
    }
    if (error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _AdherentPaper(
          title: 'VOD indisponibles',
          subtitle: 'Cette playlist n’a pas pu être chargée.',
          actionLabel: 'Réessayer',
          onAction: onRetry,
        ),
      );
    }
    if (videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _AdherentPaper(
          title: 'Aucune VOD pour le moment',
          subtitle:
              'Aucune vidéo lisible sur cette playlist. Vérifie l’ID, que le '
              'switch est ON, et que la playlist (et les vidéos) sont '
              'Publiques ou Non répertoriées — pas Privées.',
        ),
      );
    }
    return SizedBox(
      height: unlocked ? 188 : 196,
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
              child: unlocked
                  ? LivePosterTile(
                      video: video,
                      categoryLabel: seasonId,
                      onTap: () => openLiveVideo(context, video),
                    )
                  : _LockedVodPoster(
                      video: video,
                      seasonId: seasonId,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Réservé aux adhérents $seasonId. '
                              'Connecte-toi avec l’email de ton adhésion.',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _AdherentHeader extends StatelessWidget {
  final bool unlocked;
  final bool showHint;

  const _AdherentHeader({
    required this.unlocked,
    required this.showHint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 22, height: 1, color: TvTheme.green),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOD ADHÉRENTS', style: TvType.section),
                    const SizedBox(height: 2),
                    Text(
                      'Association DVCR',
                      style: TvType.section.copyWith(
                        fontSize: 15,
                        letterSpacing: 0.4,
                        color: TvTheme.greenBright,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18,
                color: unlocked ? TvTheme.greenBright : TvTheme.goldDeep,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            unlocked
                ? 'Les replays par saison d’adhésion'
                : 'Une playlist par saison — seulement si tu as cotisé cette année-là',
            style: TvType.meta,
          ),
          if (showHint) ...[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: TvTheme.surface,
                borderRadius: BorderRadius.circular(TvTheme.paperRadius),
                border: Border.all(color: TvTheme.gold.withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: TvTheme.goldDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pour débloquer, connecte-toi avec la même adresse email que pour ton adhésion.',
                        style: TvType.caption.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdhesionJoinButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AdhesionJoinButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TvTheme.green,
            borderRadius: BorderRadius.circular(TvTheme.paperRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Center(
              child: Text(
                'J’ADHÈRE À L’ASSOCIATION',
                textAlign: TextAlign.center,
                style: TvType.section.copyWith(
                  fontSize: 16,
                  letterSpacing: 1.1,
                  color: TvTheme.surface,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdherentPaper extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AdherentPaper({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: TvTheme.paper(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TvType.title),
            const SizedBox(height: 6),
            Text(subtitle, style: TvType.caption),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: TvType.kicker.copyWith(color: TvTheme.greenBright),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedVodPoster extends StatelessWidget {
  final VideoModel video;
  final String seasonId;
  final VoidCallback onTap;

  const _LockedVodPoster({
    required this.video,
    required this.seasonId,
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
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                      child: YoutubeThumbCover(
                        videoId: video.cleanId,
                        storedUrl: video.thumbnailUrl,
                        cacheWidth: tvImageCacheWidth(context, 176),
                      ),
                    ),
                    ColoredBox(
                      color: TvTheme.greenDeep.withValues(alpha: 0.38),
                    ),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: TvTheme.greenDeep.withValues(alpha: 0.82),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.lock_rounded,
                            color: TvTheme.gold,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
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
                            seasonId,
                            style: TvType.kickerOnPhoto.copyWith(
                              fontSize: 8,
                              letterSpacing: 0.4,
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
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TvType.title.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
