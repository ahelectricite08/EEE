import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/video_model.dart';
import '../../services/youtube_playlist_service.dart';
import '../../widgets/dvcr_reveal.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/dvcr_share_favorite_controls.dart';
import '../../widgets/empty_state_panel.dart';
import '../native_video_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0D0D0D);
const _kCard    = Color(0xFF161616);
const _kBorder  = Color(0xFF252525);
const _kGold    = Color(0xFFC8A436);
const _kText    = Color(0xFFF0EDE8);
const _kMuted   = Color(0xFF777777);
const _kRed     = Color(0xFFBA203C);
const _kGreen   = Color(0xFF1D7A56);
const _kPurple  = Color(0xFF7C3AED);

// ── Catégories ────────────────────────────────────────────────────────────────
const _kCats = ['all', 'matchday', 'resume', 'podcast'];

String _catLabel(String c) {
  switch (c) {
    case 'resume':   return 'Résumés';
    case 'podcast':  return 'Podcasts';
    case 'matchday': return 'Jour de match';
    default:         return 'Tout';
  }
}

Color _catColor(String? c) {
  switch (c) {
    case 'resume':   return _kRed;
    case 'podcast':  return _kPurple;
    case 'matchday': return _kGreen;
    default:         return _kGold;
  }
}

String _catBadge(String? c) {
  switch (c) {
    case 'resume':   return 'RÉSUMÉ';
    case 'podcast':  return 'PODCAST';
    case 'matchday': return 'MATCHDAY';
    default:         return 'VIDÉO';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _relDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
  if (diff.inDays > 0)  return '${diff.inDays}j';
  if (diff.inHours > 0) return '${diff.inHours}h';
  return 'Maintenant';
}

// ─────────────────────────────────────────────────────────────────────────────
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});
  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  String _selectedCat = 'all';
  final Map<String, Future<List<VideoModel>>> _futures = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    // Premier visiteur après le cooldown → déclenche la sync YouTube silencieusement
    YoutubePlaylistService.maybeRequestSync();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // On garde le Future pour la première charge (cache local rapide)
  Future<List<VideoModel>> _futureFor(String cat) =>
      _futures.putIfAbsent(cat, () => YoutubePlaylistService.forCategory(cat));

  void _reload() => setState(() {
        _futures[_selectedCat] =
            YoutubePlaylistService.refreshCategory(_selectedCat);
      });

  // Stream Firestore en direct — partagé, 1 seul socket WebSocket
  Stream<List<VideoModel>> _streamFor(String cat) =>
      YoutubePlaylistService.liveStream(category: cat);

  void _open(BuildContext ctx, VideoModel v) => Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => NativeVideoScreen(
              title: v.title, videoId: v.cleanId, video: v),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Header (intact) ───────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            pinned: true,
            expandedHeight: 182,
            flexibleSpace: FlexibleSpaceBar(
              background: _DVCRTVHeroHeader(fade: _fade),
            ),
          ),

          // ── Barre catégories ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: _kCats.map((cat) {
                  final sel = _selectedCat == cat;
                  final col = _catColor(cat);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCat = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? col : _kCard,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: sel ? col : _kBorder,
                        ),
                      ),
                      child: Text(
                        _catLabel(cat),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _kMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 4)),

          // ── Contenu ───────────────────────────────────────────────────────
          if (_selectedCat == 'all')
            _AllSections(streamFor: _streamFor, futureFor: _futureFor, fade: _fade, onTap: _open)
          else
            _SingleCategoryList(
              stream: _streamFor(_selectedCat),
              future: _futureFor(_selectedCat),
              fade: _fade,
              onTap: _open,
              onReload: _reload,
            ),
        ],
      ),
    );
  }
}

// ── Vue "Tout" : sections horizontales par catégorie ─────────────────────────
class _AllSections extends StatelessWidget {
  final Stream<List<VideoModel>> Function(String) streamFor;
  final Future<List<VideoModel>> Function(String) futureFor;
  final Animation<double> fade;
  final void Function(BuildContext, VideoModel) onTap;

  const _AllSections(
      {required this.streamFor, required this.futureFor, required this.fade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const sectionCats = ['matchday', 'resume', 'podcast'];
    return SliverList(
      delegate: SliverChildListDelegate([
        ...sectionCats.map((cat) => _HorizontalSection(
              cat: cat,
              stream: streamFor(cat),
              future: futureFor(cat),
              fade: fade,
              onTap: (v) => onTap(context, v),
            )),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ── Section horizontale (scroll) ─────────────────────────────────────────────
class _HorizontalSection extends StatelessWidget {
  final String cat;
  final Stream<List<VideoModel>> stream;
  final Future<List<VideoModel>> future;
  final Animation<double> fade;
  final void Function(VideoModel) onTap;

  const _HorizontalSection(
      {required this.cat,
      required this.stream,
      required this.future,
      required this.fade,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(cat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre section ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _catLabel(cat).toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _kText,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // ── Scroll horizontal ─────────────────────────────────────────────
        SizedBox(
          height: 230,
          // StreamBuilder : affiche les données du cache local immédiatement
          // (via initialData du Future), puis se met à jour en live depuis Firestore
          child: StreamBuilder<List<VideoModel>>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return FutureBuilder<List<VideoModel>>(
                  future: future,
                  builder: (context, fsnap) {
                    if (!fsnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: _HorizSkeleton(),
                      );
                    }
                    return _buildHorizList(fsnap.data!);
                  },
                );
              }
              return _buildHorizList(snap.data!);
            },
          ),
        ),
      ],
    );
  }
  Widget _buildHorizList(List<VideoModel> videos) {
    final items = videos.take(6).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _HorizCard(video: items[i], onTap: () => onTap(items[i])),
      ),
    );
  }
}

// ── Carte horizontale (scroll) ────────────────────────────────────────────────
class _HorizCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  const _HorizCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(video.category);
    final hasDur =
        video.duration.isNotEmpty && video.duration != '0:00';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.network(
                    video.youtubeThumbnail,
                    width: 200,
                    height: 112,
                    fit: BoxFit.cover,
                    errorBuilder: (context2, err, stack) => Container(
                      width: 200,
                      height: 112,
                      color: color.withAlpha(40),
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: color, size: 32),
                    ),
                  ),
                  // Gradient bas
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(140)
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Durée
                  if (hasDur)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duration,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  // Play
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_filled_rounded,
                          size: 36, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Titre
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _relDate(video.date),
              style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue catégorie spécifique : liste de cartes verticales ─────────────────────
class _SingleCategoryList extends StatelessWidget {
  final Stream<List<VideoModel>> stream;
  final Future<List<VideoModel>> future;
  final Animation<double> fade;
  final void Function(BuildContext, VideoModel) onTap;
  final VoidCallback onReload;

  const _SingleCategoryList(
      {required this.stream,
      required this.future,
      required this.fade,
      required this.onTap,
      required this.onReload});

  Widget _skeleton() => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildListDelegate(const [
            DVCRCardSkeleton(), SizedBox(height: 12),
            DVCRCardSkeleton(), SizedBox(height: 12),
            DVCRCardSkeleton(),
          ]),
        ),
      );

  Widget _list(BuildContext ctx, List<VideoModel> videos) =>
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx2, i) => DVCRReveal(
              delay: Duration(milliseconds: 40 * i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReplayCard(
                  video: videos[i],
                  onTap: () => onTap(ctx2, videos[i]),
                ),
              ),
            ),
            childCount: videos.length,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VideoModel>>(
      stream: stream,
      builder: (context, snap) {
        // Pas encore de données stream → on tente le cache local (Future)
        if (!snap.hasData) {
          return FutureBuilder<List<VideoModel>>(
            future: future,
            builder: (context, fsnap) {
              if (!fsnap.hasData && !fsnap.hasError) return _skeleton();
              if (fsnap.hasError) {
                return SliverFillRemaining(
                  child: EmptyStatePanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chargement indisponible',
                    subtitle: 'Les replays n\'ont pas pu être récupérés.',
                    actionLabel: 'RÉESSAYER',
                    onAction: onReload,
                  ),
                );
              }
              final videos = fsnap.data ?? [];
              if (videos.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyStatePanel(
                    icon: Icons.video_library_outlined,
                    title: 'Aucun replay disponible',
                    subtitle: 'Les prochaines vidéos DVCR apparaîtront ici.',
                  ),
                );
              }
              return _list(context, videos);
            },
          );
        }
        // Stream prêt → affichage en live
        final videos = snap.data!;
        if (videos.isEmpty) {
          return const SliverFillRemaining(
            child: EmptyStatePanel(
              icon: Icons.video_library_outlined,
              title: 'Aucun replay disponible',
              subtitle: 'Les prochaines vidéos DVCR apparaîtront ici.',
            ),
          );
        }
        return _list(context, videos);
      },
    );
  }
}

// ── Header DVCR TV (intact) ───────────────────────────────────────────────────
class _DVCRTVHeroHeader extends StatelessWidget {
  final Animation<double> fade;
  const _DVCRTVHeroHeader({required this.fade});

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
            top: -50, right: -40,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGold.withAlpha(25),
              ),
            ),
          ),
          Positioned(
            left: -28, bottom: -52,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kRed.withAlpha(20),
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
                    Colors.black.withAlpha(72),
                    Colors.black.withAlpha(158),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: fade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kGold.withAlpha(30),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _kGold.withAlpha(80)),
                      ),
                      child: Text(
                        'REPLAYS · PODCASTS · MATCHDAY',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _kGold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'DVCR TV',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chroniques, replays et moments forts du club.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(180),
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

// ── Carte vidéo (vue catégorie spécifique) ────────────────────────────────────
class ReplayCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  const ReplayCard({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color  = _catColor(video.category);
    final hasDur = video.duration.isNotEmpty && video.duration != '0:00';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: Stack(
                children: [
                  Image.network(
                    video.youtubeThumbnail,
                    width: 130,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context2, err, stack) => Container(
                      width: 130,
                      height: 90,
                      color: color.withAlpha(40),
                    ),
                  ),
                  // Play
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_filled_rounded,
                          size: 32, color: Colors.white70),
                    ),
                  ),
                  // Durée
                  if (hasDur)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(210),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.duration,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Infos ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withAlpha(28),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(
                            _catBadge(video.category),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _relDate(video.date),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _kMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Titre
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Partage / favori
                    Align(
                      alignment: Alignment.centerRight,
                      child: DvcrVideoShareFavoriteRow(
                        video: video,
                        mutedIconColor: _kMuted,
                        activeFavoriteColor: _kGold,
                        iconSize: 16,
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

// ── Skeleton horizontal ───────────────────────────────────────────────────────
class _HorizSkeleton extends StatelessWidget {
  const _HorizSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 112,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                  width: 160,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Container(
                  width: 80,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }
}
