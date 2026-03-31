import 'package:flutter/material.dart';
import '../theme/dvcr_theme.dart';
import '../widgets/dvcr_card.dart';
import '../models/video_model.dart';
import '../services/youtube_playlist_service.dart';
import 'native_video_screen.dart';

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
  final List<String> _categories = [
    'all',
    'resume',
    'podcast',
    'matchday',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: DVCRTheme.darkGradient,
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'REPLAYS',
                            style: DVCRTheme.displayLarge.copyWith(
                              color: DVCRTheme.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Retrouvez tous nos moments forts',
                            style: DVCRTheme.bodyLarge.copyWith(
                              color: DVCRTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filtres par catégorie
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected 
                                ? LinearGradient(
                                    colors: [
                                      _getCategoryColor(category),
                                      _getCategoryColor(category).withOpacity(0.7),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : DVCRTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.transparent 
                                  : _getCategoryColor(category).withOpacity(0.3),
                              width: 1,
                            ),
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
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Liste des vidéos
          FutureBuilder<List<VideoModel>>(
            future: YoutubePlaylistService.forCategory(_selectedCategory),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: DVCRTheme.primaryGreen)),
                );
              }
              final videos = snapshot.data!;
              if (videos.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined, size: 80, color: DVCRTheme.textMuted),
                        const SizedBox(height: 20),
                        Text('Aucun replay disponible',
                            style: DVCRTheme.titleLarge.copyWith(color: DVCRTheme.textSecondary)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = videos[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ReplayCard(
                          video: video,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => NativeVideoScreen(title: video.title, videoId: video.youtubeId),
                          )),
                        ),
                      );
                    },
                    childCount: videos.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ReplayCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const ReplayCard({
    super.key,
    required this.video,
    required this.onTap,
  });

  String _getCategoryDisplayName(String? category) {
    switch (category) {
      case 'resume':   return 'RÉSUMÉ';
      case 'podcast':  return 'PODCAST';
      case 'matchday': return 'JOUR DE MATCH';
      default:         return 'VIDÉO';
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
            _getCategoryColor(category).withOpacity(0.3),
            _getCategoryColor(category).withOpacity(0.1),
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
                      errorBuilder: (_, __, ___) => _buildThumbPlaceholder(category),
                    ),
                  ),

                  // Badge de catégorie
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      child: Icon(Icons.play_circle_filled,
                          size: 52, color: Colors.white70),
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
                    
                    Row(
                      children: [
Icon(
                          Icons.schedule,
                          color: DVCRTheme.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(video.date),
                          style: DVCRTheme.bodyMedium.copyWith(
                            color: DVCRTheme.textSecondary,
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

