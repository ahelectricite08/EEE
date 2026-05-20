import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/dvcr_share_service.dart';

import '../models/article_model.dart';
import '../models/match_model.dart';
import '../models/video_model.dart';
import '../services/favorites_service.dart';
import '../utils/share_helper.dart';

/// Partage + favori pour un match (calendrier, alertes, recherche…).
class DvcrMatchShareFavoriteRow extends StatelessWidget {
  final MatchModel match;
  final Color mutedIconColor;
  final Color activeFavoriteColor;
  final double iconSize;
  /// Si false : uniquement favori (ex. partage déjà sur la barre verte de la carte).
  final bool showShare;

  const DvcrMatchShareFavoriteRow({
    super.key,
    required this.match,
    required this.mutedIconColor,
    this.activeFavoriteColor = const Color(0xFFC9A227),
    this.iconSize = 20,
    this.showShare = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showShare)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Partager',
            icon: Icon(Icons.ios_share_rounded, size: iconSize, color: mutedIconColor),
            onPressed: () => DvcrShare.share(ShareHelper.matchText(match)),
          ),
        if (FirebaseAuth.instance.currentUser?.uid != null)
          StreamBuilder<bool>(
            stream: FavoritesService.watchIsFavorite(FavoriteType.match, match.id),
            builder: (context, snap) {
              final isFav = snap.data ?? false;
              return IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: iconSize,
                  color: isFav ? activeFavoriteColor : mutedIconColor,
                ),
                onPressed: () => FavoritesService.toggle(
                  type: FavoriteType.match,
                  itemId: match.id,
                  title: '${match.team1} vs ${match.team2}',
                  subtitle: match.competition,
                  routeHint: 'match',
                  extra: {
                    'team1': match.team1,
                    'team2': match.team2,
                    'date': match.date.toIso8601String(),
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Partage + favori pour un article.
class DvcrArticleShareFavoriteRow extends StatelessWidget {
  final ArticleModel article;
  final Color mutedIconColor;
  final Color activeFavoriteColor;
  final double iconSize;

  const DvcrArticleShareFavoriteRow({
    super.key,
    required this.article,
    required this.mutedIconColor,
    this.activeFavoriteColor = const Color(0xFFC8A436),
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'Partager',
          icon: Icon(Icons.ios_share_rounded, size: iconSize, color: mutedIconColor),
          onPressed: () => DvcrShare.share(ShareHelper.articleText(article)),
        ),
        if (FirebaseAuth.instance.currentUser?.uid != null)
          StreamBuilder<bool>(
            stream: FavoritesService.watchIsFavorite(
              FavoriteType.article,
              article.id,
            ),
            builder: (context, snap) {
              final isFav = snap.data ?? false;
              return IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                icon: Icon(
                  isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: iconSize,
                  color: isFav ? activeFavoriteColor : mutedIconColor,
                ),
                onPressed: () => FavoritesService.toggle(
                  type: FavoriteType.article,
                  itemId: article.id,
                  title: article.title,
                  subtitle: article.categoryForShare,
                  imageUrl: article.imageUrl,
                  routeHint: 'article',
                  extra: {
                    'authorName': article.authorName,
                    'date': article.date.toIso8601String(),
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Partage + favori pour une vidéo replay.
class DvcrVideoShareFavoriteRow extends StatelessWidget {
  final VideoModel video;
  final Color mutedIconColor;
  final Color activeFavoriteColor;
  final double iconSize;

  const DvcrVideoShareFavoriteRow({
    super.key,
    required this.video,
    required this.mutedIconColor,
    this.activeFavoriteColor = const Color(0xFFC9A227),
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'Partager',
          icon: Icon(Icons.ios_share_rounded, size: iconSize, color: mutedIconColor),
          onPressed: () => DvcrShare.share(ShareHelper.videoText(video)),
        ),
        if (FirebaseAuth.instance.currentUser?.uid != null)
          StreamBuilder<bool>(
            stream: FavoritesService.watchIsFavorite(FavoriteType.video, video.id),
            builder: (context, snap) {
              final isFav = snap.data ?? false;
              return IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: isFav ? 'Retirer des favoris' : 'Favori',
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: iconSize,
                  color: isFav ? activeFavoriteColor : mutedIconColor,
                ),
                onPressed: () => FavoritesService.toggle(
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
