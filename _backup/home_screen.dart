import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/match_model.dart';
import '../models/article_model.dart';
import '../models/video_model.dart';
import '../services/user_service.dart';
import '../services/match_service.dart';
import '../services/article_service.dart';
import '../widgets/match_card.dart';
import '../widgets/section_header.dart';
import 'chat_screen.dart' show AuthLockScreen;
import 'profile_screen.dart';
import 'live_screen.dart' show LiveScreen;
import 'video_web_screen.dart';
import 'replay_screen.dart';
import 'articles_screen.dart';
import 'matches_screen.dart';
import 'match_detail_screen.dart';
import 'prono_screen.dart' show PronoScreen;

// ── Palette identique à live_screen ───────────────────────────────────────────
const _kRed    = Color(0xFFBA203C);
const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF141414);
const _kBorder = Color(0xFF1E1E1E);
const _kGrey   = Color(0xFF666666);

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':   return const Color(0xFF4CAF50);
    case 'AVANT-MATCH': return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':   return const Color(0xFF2196F3);
    case 'ANALYSE':     return const Color(0xFF9C27B0);
    case 'COULISSES':   return const Color(0xFFFF9800);
    default:            return _kRed;
  }
}

class HomeScreen extends StatefulWidget {
  final void Function(int)? onSwitchTab;
  const HomeScreen({super.key, this.onSwitchTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  UserRole? _userRole;
  int _categoryIndex = 0;

  // Live data (subscrit dans initState pour éviter StreamBuilder dans slivers)
  bool _isLive = false;
  String? _liveUrl;
  int _liveViewers = 0;
  int _scoreHome = 0;
  int _scoreAway = 0;
  String _liveTeam1 = '';
  String _liveTeam2 = '';
  StreamSubscription<DocumentSnapshot>? _liveSub;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _categories = [
    'TOUT', 'RÉSULTATS', 'AVANT-MATCH', 'CHRONIQUES SEDANAISES', 'COULISSES', 'ANALYSE'
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _loadRole();
    _liveSub = FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final exists = snap.exists;
      final data = exists ? snap.data() as Map<String, dynamic> : null;
      setState(() {
        _isLive  = exists;
        _liveUrl = data?['url'] as String?;
        _liveViewers = (data?['live_viewers'] as int?) ?? 0;
        _scoreHome  = (data?['scoreHome'] as int?) ?? 0;
        _scoreAway  = (data?['scoreAway'] as int?) ?? 0;
        _liveTeam1  = (data?['team1'] as String?) ?? '';
        _liveTeam2  = (data?['team2'] as String?) ?? '';
      });
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final r = await UserService.getCurrentRole();
    if (mounted) setState(() => _userRole = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar + Hero intégrés (photo du tout haut) ───────────────
          _buildAppBarWithHero(),

          // ── Prochain match ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'PROCHAIN MATCH',
              onSeeAll: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MatchesScreen())),
            ),
          ),
          SliverToBoxAdapter(child: _NextMatchCard()),

          // ── DVCR TV ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'DVCR CONTENU',
              leading: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                    color: _kRed, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 12),
              ),
              onSeeAll: () => widget.onSwitchTab?.call(1),
            ),
          ),
          SliverToBoxAdapter(child: _DVCRTVRow()),

          // ── Dernières actus ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'DERNIÈRES ACTUS',
              onSeeAll: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ArticlesScreen())),
            ),
          ),
          SliverToBoxAdapter(child: _buildCategoryFilter()),
          SliverToBoxAdapter(child: _ArticlesFeed(
            category: _categories[_categoryIndex],
          )),

          // ── Derniers résultats ───────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'DERNIERS RÉSULTATS',
              onSeeAll: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MatchesScreen())),
            ),
          ),
          SliverToBoxAdapter(child: _ResultsFeed()),

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  // ── AppBar + Hero intégrés — photo depuis le tout haut de l'écran ────────
  SliverAppBar _buildAppBarWithHero() {
    final user = FirebaseAuth.instance.currentUser;

        return SliverAppBar(
          pinned: true,
          expandedHeight: 290,
          backgroundColor: _kBg,
          elevation: 0,
          titleSpacing: 0,
          toolbarHeight: 52,
          // ── Titre compact visible quand la photo est scrollée ──────────
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Spacer(),
                if (_userRole != null && _userRole != UserRole.supporter)
                  _RolePill(role: _userRole!.displayName),
                const SizedBox(width: 4),
                _IconBtn(icon: Icons.search_rounded, onTap: () {}),
                _IconBtn(
                  icon: user == null
                      ? Icons.person_outline_rounded
                      : Icons.person_rounded,
                  color: user != null ? _kRed : null,
                  onTap: () async {
                    if (user == null) {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AuthLockScreen()));
                    } else {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    }
                    _loadRole();
                  },
                ),
              ],
            ),
          ),
          // ── Photo pleine largeur depuis le haut ───────────────────────
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: GestureDetector(
              onTap: () async {
                if (_isLive && _liveUrl != null && _liveUrl!.isNotEmpty) {
                  await launchUrl(Uri.parse(_liveUrl!), mode: LaunchMode.externalApplication);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LiveScreen()));
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo — même image que DVCR TV
                  Image.asset(
                    'assets/images/dvcrlive.JPG',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-1.0, 0.6),
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF111111),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_soccer_rounded,
                                size: 48, color: _kRed.withAlpha(80)),
                            const SizedBox(height: 8),
                            Text('DVCR',
                                style: GoogleFonts.barlowCondensed(
                                    fontSize: 28, fontWeight: FontWeight.w900,
                                    color: Colors.white38, letterSpacing: 4)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Gradient haut (status bar + toolbar lisibles)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Colors.black.withAlpha(160), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Gradient bas fort
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withAlpha(230), Colors.transparent],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  // Badge EN DIRECT (si live) — top-left sous le toolbar
                  if (_isLive)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 14,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) =>
                            _PulsingLiveBadge(pulse: _pulse.value),
                      ),
                    ),
                  // Bouton play (si pas live)
                  if (!_isLive)
                    Center(
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: _kRed,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 14)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  // Titre + sous-titre en bas
                  Positioned(
                    bottom: 16,
                    left: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLive) ...[
                          Text(
                            'DVCR — DRAPEAU VERT CARTON ROUGE',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 22, fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.white, letterSpacing: 0.5, height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                        ],
                        if (_isLive) ...[
                          const SizedBox(height: 10),
                          // Score si équipes renseignées
                          if (_liveTeam1.isNotEmpty && _liveTeam2.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(160),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _liveTeam1.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 13, fontWeight: FontWeight.w800,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$_scoreHome - $_scoreAway',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 22, fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _liveTeam2.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 13, fontWeight: FontWeight.w800,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _kRed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text('REGARDER EN DIRECT',
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 13, fontWeight: FontWeight.w800,
                                          color: Colors.white, letterSpacing: 1,
                                        )),
                                  ],
                                ),
                              ),
                              if (_liveViewers > 0) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.visibility_rounded,
                                    size: 11, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text('$_liveViewers',
                                    style: GoogleFonts.barlow(
                                        fontSize: 12, color: Colors.white54)),
                              ],
                            ],
                          ),
                        ] else
                          Text('Appuie pour voir les replays',
                              style: GoogleFonts.barlow(
                                  fontSize: 12, color: Colors.white38)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  // ── Filtres catégories — angulaires style sport ───────────────────────────
  Widget _buildCategoryFilter() {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final sel = _categoryIndex == i;
            final color = _catColor(_categories[i]);
            return GestureDetector(
              onTap: () => setState(() => _categoryIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: sel ? color : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Text(
                  _categories[i],
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: sel ? Colors.white : _kGrey,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Prochain match ─────────────────────────────────────────────────────────────
class _NextMatchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final isLogged = authSnap.data != null;

        return StreamBuilder<List<MatchModel>>(
          stream: MatchService.upcoming(),
          builder: (context, snap) {
            final match = (snap.hasData && snap.data!.isNotEmpty)
                ? snap.data!.first
                : MatchModel.mockUpcoming.first;

            return Column(
              children: [
                MatchCard(
                  match: match,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: GestureDetector(
                    onTap: isLogged
                        ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const PronoScreen()))
                        : () => Navigator.pushNamed(context, '/login'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLogged ? Icons.sports_soccer_rounded : Icons.lock_rounded,
                          size: 12,
                          color: isLogged ? Colors.white38 : Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLogged ? 'Pronostiquer ce match →' : 'Connecte-toi pour pronostiquer',
                          style: GoogleFonts.barlow(
                            fontSize: 12,
                            color: isLogged ? Colors.white54 : Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── DVCR TV — style _VideoCard de live_screen ─────────────────────────────────
class _DVCRTVRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .orderBy('created_at', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snap) {
        final List<VideoModel> videos;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          videos = snap.data!.docs.map(VideoModel.fromFirestore).toList();
        } else {
          videos = VideoModel.mock;
        }

        final cardW = MediaQuery.of(context).size.width * 0.465;
        final totalH = cardW * (9 / 16) + 68;

        return SizedBox(
          height: totalH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 14, right: 4),
            itemCount: videos.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: cardW,
                child: _HomeTVCard(
                  video: videos[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VideoWebScreen(video: videos[i])),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeTVCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;
  const _HomeTVCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = video.youtubeThumbnail;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _kCard,
                      child: Center(
                        child: Icon(Icons.sports_soccer_rounded,
                            color: _kRed.withAlpha(60), size: 32),
                      ),
                    ),
                  ),
                  // Gradient bas
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(160),
                            Colors.transparent
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                  // Bouton play rouge circulaire
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  // Durée badge
                  if (video.duration.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Titre + catégorie
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _catLabel(video.category),
                  style: GoogleFonts.barlow(fontSize: 10, color: _kGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  video.title,
                  style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _catLabel(String c) {
    switch (c) {
      case 'resume':   return 'Régional 1 · 2024/25';
      case 'podcast':  return 'DVCR Média';
      case 'matchday': return 'Coulisses';
      default:         return c.toUpperCase();
    }
  }
}

// ── Articles feed — style articles_screen ─────────────────────────────────────
class _ArticlesFeed extends StatelessWidget {
  final String category;
  const _ArticlesFeed({required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArticleModel>>(
      stream: ArticleService.all(
        category: category == 'TOUT' ? null : category,
        limit: 5,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final articles = snap.data!;
        if (articles.isEmpty) return const SizedBox();

        return Column(
          children: articles.asMap().entries.map((e) {
            final article = e.value;
            final isLast = e.key == articles.length - 1;
            final color = _catColor(article.category);

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(article: article)),
              ),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Barre colorée catégorie
                        Container(
                          width: 3,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    article.category.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text('  ·  ',
                                      style: GoogleFonts.barlow(
                                          fontSize: 11,
                                          color: const Color(0xFF3A3A3A))),
                                  Text(
                                    _relDate(article.date),
                                    style: GoogleFonts.barlow(
                                        fontSize: 11, color: _kGrey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                article.title,
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Thumbnail
                        Container(
                          width: 80,
                          height: 54,
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _kBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: article.imageUrl != null
                              ? Image.network(article.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.article_outlined,
                                      size: 20,
                                      color: color.withAlpha(80)))
                              : Icon(Icons.article_outlined,
                                  size: 20, color: color.withAlpha(80)),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1,
                        color: _kBorder,
                        indent: 16,
                        endIndent: 16),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Résultats feed ─────────────────────────────────────────────────────────────
class _ResultsFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.results(),
      builder: (context, snap) {
        final matches = (snap.hasData && snap.data!.isNotEmpty)
            ? snap.data!.take(3).toList()
            : MatchModel.mockResults;

        return Column(
          children: matches
              .map((m) => MatchCard(
                    match: m,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MatchDetailScreen(match: m)),
                    ),
                    onReplay: m.replayVideoId != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReplayScreen()),
                            )
                        : null,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _PulsingLiveBadge extends StatelessWidget {
  final double pulse;
  const _PulsingLiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kRed,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: _kRed.withAlpha((50 + (pulse * 100).round())),
            blurRadius: 4 + pulse * 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DVCRBadgeSmall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'DVCR TV',
        style: GoogleFonts.barlowCondensed(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kRed.withAlpha(38),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kRed.withAlpha(100)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kRed,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: color ?? Colors.white),
      ),
    );
  }
}

String _relDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  final months = ['jan','fév','mar','avr','mai','juin',
      'juil','aoû','sep','oct','nov','déc'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
