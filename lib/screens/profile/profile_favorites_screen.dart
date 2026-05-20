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
        return profileGold;
      case FavoriteType.match:
        return profileGreen;
      case FavoriteType.video:
        return profileRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, 'Mes favoris'),
      body: StreamBuilder<List<FavoriteEntry>>(
        stream: FavoritesService.watchAll(),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 24 + bottom),
              children: [
                const ProfileSectionHeader(
                  title: 'Tout ce que tu sauvegardes',
                  subtitle:
                      'Articles, matchs et replays DVCR — glisse vers la gauche pour retirer un favori.',
                  icon: Icons.bookmark_added_rounded,
                  accent: profileGold,
                ),
                const SizedBox(height: 20),
                ProfileEmptyHint(
                  icon: Icons.bookmark_border_rounded,
                  accent: profileGold,
                  title: 'Aucun favori pour le moment',
                  body:
                      'Ajoute des contenus depuis l’accueil, les actus ou le calendrier : l’icône marque-page les enregistre ici.',
                  action: FilledButton.tonal(
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
                    style: FilledButton.styleFrom(
                      backgroundColor: profileGreen.withValues(alpha: 0.12),
                      foregroundColor: profileGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 24 + bottom),
            itemCount: list.length + 1,
            separatorBuilder: (_, i) => i == 0
                ? const SizedBox(height: 14)
                : const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const ProfileSectionHeader(
                  title: 'Tes favoris',
                  subtitle: 'Glisse une ligne vers la gauche pour la retirer.',
                  icon: Icons.bookmark_added_rounded,
                  accent: profileGold,
                );
              }
              final e = list[i - 1];
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
                  decoration: BoxDecoration(
                    color: profileRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                  stripeColor: accent,
                  cardBorderColor: accent.withValues(alpha: 0.22),
                  onTap: () => _openEntry(context, e),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 6, 10),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  middle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: profileText,
                        ),
                      ),
                      if (e.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: profileMutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: profileGreen.withValues(alpha: 0.35),
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
