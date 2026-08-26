import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/match_model.dart';
import '../../models/video_model.dart';
import '../../services/article_service.dart';
import '../../services/favorites_service.dart';
import '../articles/articles_screen.dart'
    show ArticleDetailScreen, ArticlesScreen;
import '../match_detail_screen.dart';
import '../video_web_screen.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';
import 'profile_type.dart';

/// Liste des favoris (articles, matchs, vidéos) — même source que [FavoritesService].
class ProfileFavoritesScreen extends StatelessWidget {
  /// Depuis l’accueil : bascule l’onglet principal (ex. Actus) sans empiler un 2ᵉ [ArticlesScreen].
  final void Function(int tabIndex, {int? matchesSubTab})? onSwitchMainTab;

  const ProfileFavoritesScreen({super.key, this.onSwitchMainTab});

  Future<void> _openEntry(BuildContext context, FavoriteEntry e) async {
    switch (e.type) {
      case FavoriteType.article:
        final article = await ArticleService.byId(e.itemId);
        if (!context.mounted) return;
        if (article != null) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        }
        return;
      case FavoriteType.match:
        final snap = await FirebaseFirestore.instance
            .collection('matches')
            .doc(e.itemId)
            .get();
        if (!context.mounted) return;
        if (snap.exists) {
          final m = MatchModel.fromFirestore(snap);
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MatchDetailScreen(match: m),
            ),
          );
        }
        return;
      case FavoriteType.video:
        final raw = Map<String, dynamic>.from(e.data);
        raw['id'] = e.itemId;
        final rd = raw['date'] ?? raw['created_at'];
        if (rd is Timestamp) {
          raw['date'] = rd.toDate().toIso8601String();
        } else {
          raw['date'] ??= DateTime.now().toIso8601String();
        }
        final v = VideoModel.fromJson(raw);
        if (!context.mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => VideoWebScreen(video: v),
          ),
        );
        return;
    }
  }

  Color _accent(FavoriteType t) {
    switch (t) {
      case FavoriteType.article:
        return profileGreen;
      case FavoriteType.match:
        return profileGreenBright;
      case FavoriteType.video:
        return profileRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(
        context,
        'Mes favoris',
        accentColor: profileGreen,
      ),
      body: StreamBuilder<List<FavoriteEntry>>(
        stream: FavoritesService.watchAll(),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
              children: [
                ProfileEmptyHint(
                  icon: Icons.bookmark_border_rounded,
                  accent: profileGreen,
                  title: 'Aucun favori pour le moment',
                  body:
                      'Ajoute des contenus depuis l’accueil, les actus ou le calendrier : l’icône marque-page les enregistre ici.',
                  action: OutlinedButton(
                    onPressed: () {
                      final go = onSwitchMainTab;
                      if (go != null) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          go(3);
                        });
                        return;
                      }
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ArticlesScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: profileGreen,
                      side: const BorderSide(color: profileGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(profilePaperRadius),
                      ),
                    ),
                    child: Text(
                      'Parcourir les actus',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              final accent = _accent(e.type);
              final icon = switch (e.type) {
                FavoriteType.article => Icons.article_outlined,
                FavoriteType.match => Icons.sports_soccer_rounded,
                FavoriteType.video => Icons.play_circle_outline_rounded,
              };
              return Dismissible(
                key: ValueKey('fav_${e.docId}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: profileRed.withValues(alpha: 0.10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete_outline_rounded, color: profileRed),
                      const SizedBox(width: 6),
                      Text(
                        'Retirer',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: profileRed,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  HapticFeedback.mediumImpact();
                  FavoritesService.removeByDocId(e.docId);
                },
                child: ProfileListRow(
                  accentStripe: accent,
                  photoUrl: e.imageUrl,
                  onTap: () => _openEntry(context, e),
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: ColoredBox(
                      color: profileSurfaceMuted,
                      child: Icon(icon, color: accent, size: 24),
                    ),
                  ),
                  middle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileType.label,
                      ),
                      if (e.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileType.caption,
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: profileMutedText,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
