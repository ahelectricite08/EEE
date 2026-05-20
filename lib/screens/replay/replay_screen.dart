import 'package:flutter/material.dart';
import '../../theme/dvcr_theme.dart';
import '../../widgets/dvcr_card.dart';
import '../../models/video_model.dart';
import '../../services/youtube_playlist_service.dart';
import '../../widgets/dvcr_share_favorite_controls.dart';
import '../../widgets/dvcr_reveal.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/empty_state_panel.dart';
import '../../widgets/section_header.dart';
import '../native_video_screen.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedCategory = 'all';
  final List<String> _categories = ['all', 'matchday', 'podcast', 'resume'];
  final Map<String, Future<List<VideoModel>>> _categoryFutures = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<VideoModel>> _futureFor(String category) {
    return _categoryFutures.putIfAbsent(
      category,
      () => YoutubePlaylistService.forCategory(category),
    );
  }

  void _reloadSelectedCategory() {
    setState(() {
      _categoryFutures[_selectedCategory] =
          YoutubePlaylistService.refreshCategory(_selectedCategory);
    });
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'resume':
        return 'RÉSUMÉS';
      case 'podcast':
        return 'PODCASTS';
      case 'matchday':
        return 'JOUR DE MATCH';
      case 'all':
      default:
        return 'TOUT';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'resume':
        return DVCRTheme.primaryRed;
      case 'podcast':
        return const Color(0xFF9C27B0);
      case 'matchday':
        return DVCRTheme.primaryGreen;
      case 'all':
      default:
        return DVCRTheme.textSecondary;
    }
  }

  String _getCategorySummary(String category) {
    switch (category) {
      case 'resume':
        return 'Les temps forts et resumes a relancer rapidement.';
      case 'podcast':
        return 'Debats, plateaux et formats a ecouter ou revoir.';
      case 'matchday':
        return 'Les coulisses, l ambiance et les rendez-vous terrain.';
      case 'all':
      default:
        return 'La selection complete DVCR TV, classee pour etre retrouvee vite.';
    }
  }

  Widget _buildCategorySummaryCard() {
    final accent = _getCategoryColor(_selectedCategory);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.26)),
              ),
              child: Text(
                'EXPLORER LE FORMAT',
                style: DVCRTheme.labelLarge.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _getCategoryDisplayName(_selectedCategory),
              style: DVCRTheme.titleLarge.copyWith(
                color: DVCRTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCategorySummary(_selectedCategory),
              style: DVCRTheme.bodyMedium.copyWith(
                color: DVCRTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DVCRTheme.darkBackground,
      body: CustomScrollView(
        slivers: [
          // Header Replay
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            pinned: true,
            expandedHeight: 182,
            flexibleSpace: FlexibleSpaceBar(
              background: _DVCRTVHeroHeader(fadeAnimation: _fadeAnimation),
            ),
          ),

          // Filtres par catégorie
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF242424)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECHERCHER PAR FORMAT',
                      style: DVCRTheme.labelLarge.copyWith(
                        color: const Color(0xFFC8A436),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choisis une entree pour aller plus vite vers le bon contenu.',
                      style: DVCRTheme.bodyMedium.copyWith(
                        color: DVCRTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _selectedCategory == category;

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFFE1C15A),
                                            _getCategoryColor(
                                              category,
                                            ).withValues(alpha: 0.88),
                                          ],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : const Color(0xFF151515),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(
                                            0xFFE6C866,
                                          ).withValues(alpha: 0.65)
                                        : _getCategoryColor(
                                            category,
                                          ).withValues(alpha: 0.28),
                                    width: 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _getCategoryColor(
                                              category,
                                            ).withValues(alpha: 0.22),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _getCategoryDisplayName(category),
                                  style: DVCRTheme.titleMedium.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : _getCategoryColor(category),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: _buildCategorySummaryCard()),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Liste des vidéos
          FutureBuilder<List<VideoModel>>(
            future: _futureFor(_selectedCategory),
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(const [
                      DVCRCardSkeleton(),
                      DVCRCardSkeleton(),
                      DVCRCardSkeleton(),
                    ]),
                  ),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: EmptyStatePanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chargement indisponible',
                    subtitle:
                        'Les replays n ont pas pu etre recuperes pour le moment.',
                    actionLabel: 'REESSAYER',
                    onAction: _reloadSelectedCategory,
                  ),
                );
              }
              final videos = snapshot.data ?? const <VideoModel>[];
              if (videos.isEmpty) {
                return SliverFillRemaining(
                  child: const EmptyStatePanel(
                    icon: Icons.video_library_outlined,
                    title: 'Aucun replay disponible',
                    subtitle:
                        'Les prochaines vidéos DVCR apparaîtront ici une fois publiées.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final video = videos[index];
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: DVCRReveal(
                        delay: Duration(milliseconds: 45 * index),
                        child: ReplayCard(
                          video: video,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NativeVideoScreen(
                                title: video.title,
                                videoId: video.cleanId,
                                video: video,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: videos.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DVCRTVHeroHeader extends StatelessWidget {
  final Animation<double> fadeAnimation;

  const _DVCRTVHeroHeader({required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF171717), Color(0xFF0A0A0A)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC8A436).withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            left: -28,
            bottom: -52,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DVCRTheme.primaryRed.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFFC8A436,
                          ).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'REPLAYS • PODCASTS • MATCHDAY',
                        style: DVCRTheme.labelLarge.copyWith(
                          color: const Color(0xFFC8A436),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionHeaderWidget(
                      'CONTENU DVCR',
                      subtitle:
                          'Chroniques, replays, debats et moments forts de la maison',
                      leading: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFFC8A436),
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

class ReplayCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const ReplayCard({super.key, required this.video, required this.onTap});

  String _getCategoryDisplayName(String? category) {
    switch (category) {
      case 'resume':
        return 'RÉSUMÉ';
      case 'podcast':
        return 'PODCAST';
      case 'matchday':
        return 'JOUR DE MATCH';
      default:
        return 'VIDÉO';
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'resume':
        return DVCRTheme.primaryRed;
      case 'podcast':
        return const Color(0xFF9C27B0);
      case 'matchday':
        return DVCRTheme.primaryGreen;
      default:
        return DVCRTheme.textSecondary;
    }
  }

  Widget _buildThumbPlaceholder(String? category) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCategoryColor(category).withValues(alpha: 0.30),
            _getCategoryColor(category).withValues(alpha: 0.10),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final category = video.category;
    final thumbUrl = video.youtubeThumbnail;
    final accent = _getCategoryColor(category);
    final hasDuration = video.duration.isNotEmpty && video.duration != '0:00';
    final hasViews = video.views > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: DVCRCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail avec durée
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      thumbUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildThumbPlaceholder(category),
                    ),
                  ),

                  // Badge de catégorie
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getCategoryDisplayName(category),
                        style: DVCRTheme.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // Bouton play overlay
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 52,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: DvcrVideoShareFavoriteRow(
                          video: video,
                          mutedIconColor:
                              Colors.white.withValues(alpha: 0.92),
                          activeFavoriteColor: const Color(0xFFC8A436),
                          iconSize: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Informations
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DVCRTheme.titleLarge.copyWith(
                        color: DVCRTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _ReplayMetaChip(
                          icon: Icons.schedule_rounded,
                          label: _formatDate(video.date),
                        ),
                        if (hasDuration)
                          _ReplayMetaChip(
                            icon: Icons.timer_outlined,
                            label: video.duration,
                          ),
                        if (hasViews)
                          _ReplayMetaChip(
                            icon: Icons.visibility_outlined,
                            label: video.views >= 1000000
                                ? '${(video.views / 1000000).toStringAsFixed(1)}M vues'
                                : video.views >= 1000
                                ? '${(video.views / 1000).toStringAsFixed(1)}k vues'
                                : '${video.views} vues',
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Regarder maintenant',
                            style: DVCRTheme.labelLarge.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
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

class _ReplayMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReplayMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DVCRTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: DVCRTheme.bodyMedium.copyWith(
              color: DVCRTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
