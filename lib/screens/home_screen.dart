import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/podcast_controller.dart';
import '../services/match_controller.dart';
import '../services/youtube_playlist_service.dart';
import 'native_video_screen.dart';
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
import '../widgets/donation_banner.dart';
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

  // Émission DVCR live
  bool _isEmissionLive = false;
  String? _emissionUrl;
  String _emissionTitle = '';
  int _emissionViewers = 0;
  StreamSubscription<DocumentSnapshot>? _emissionSub;

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
    _emissionSub = FirebaseFirestore.instance
        .collection('live')
        .doc('emission')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final exists = snap.exists;
      final data = exists ? snap.data() as Map<String, dynamic> : null;
      setState(() {
        _isEmissionLive   = exists;
        _emissionUrl      = data?['url'] as String?;
        _emissionTitle    = (data?['title'] as String?) ?? 'ÉMISSION DVCR';
        _emissionViewers  = (data?['viewers'] as int?) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _emissionSub?.cancel();
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
              leading: const Icon(Icons.sports_soccer_rounded, size: 16, color: Color(0xFFC8A436)),
              onSeeAll: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MatchesScreen())),
            ),
          ),
          SliverToBoxAdapter(child: _NextMatchCard()),

          // ── Podcast DVCR ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'PODCAST DVCR',
              leading: const Icon(Icons.headphones_rounded, size: 16, color: Color(0xFFC8A436)),
            ),
          ),
          const SliverToBoxAdapter(child: _PodcastSection()),

          // ── DVCR TV ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'DERNIÈRES VIDÉOS',
              leading: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFFC8A436)),
              onSeeAll: () => widget.onSwitchTab?.call(1),
            ),
          ),
          SliverToBoxAdapter(child: _DVCRTVRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Bannière don ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: DonationBanner(
              donationUrl: 'https://www.helloasso.com',
              photoAsset: 'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
              title: 'SOUTENEZ DVCR',
              subtitle: 'Chaque don nous aide à grandir',
            ),
          ),

          // ── Dernières actus ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeaderWidget(
              'DERNIÈRES ACTUS',
              leading: const Icon(Icons.article_outlined, size: 16, color: Color(0xFFC8A436)),
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
              leading: const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFC8A436)),
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
          backgroundColor: Colors.transparent,
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
                  color: user != null ? const Color(0xFFC8A436) : null,
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
          flexibleSpace: Stack(
            fit: StackFit.expand,
            children: [
              // Photo toujours visible (même quand collapsé)
              Image.asset(
                'assets/images/IMG_0842.JPG',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(140), Colors.black.withAlpha(200)],
                  ),
                ),
              ),
              FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: GestureDetector(
              onTap: () async {
                final url = _isLive ? _liveUrl : (_isEmissionLive ? _emissionUrl : null);
                if (url != null && url.isNotEmpty) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else if (!_isLive && !_isEmissionLive) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LiveScreen()));
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo — même image que DVCR TV
                  Image.asset(
                    _isLive
                        ? 'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg'
                        : _isEmissionLive
                            ? 'assets/images/IMG_0377.JPG'
                            : 'assets/images/IMG_0842.JPG',
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
                  // Badge EN DIRECT (si live match ou émission)
                  if (_isLive || _isEmissionLive)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 14,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) =>
                            _PulsingLiveBadge(pulse: _pulse.value),
                      ),
                    ),
                  // Bouton play (si rien en direct)
                  if (!_isLive && !_isEmissionLive)
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
                        if (!_isLive && !_isEmissionLive) ...[
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
                        if (_isEmissionLive && !_isLive) ...[
                          const SizedBox(height: 10),
                          Text(
                            _emissionTitle.toUpperCase(),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20, fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.white, letterSpacing: 0.5, height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
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
                                    const Icon(Icons.live_tv_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text('REGARDER L\'ÉMISSION',
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 13, fontWeight: FontWeight.w800,
                                          color: Colors.white, letterSpacing: 1,
                                        )),
                                  ],
                                ),
                              ),
                              if (_emissionViewers > 0) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.visibility_rounded, size: 11, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text('$_emissionViewers', style: GoogleFonts.barlow(fontSize: 12, color: Colors.white54)),
                              ],
                            ],
                          ),
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
                        ] else if (!_isEmissionLive)
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
              ],
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
            return GestureDetector(
              onTap: () => setState(() => _categoryIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFC8A436).withAlpha(20) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? const Color(0xFFC8A436) : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Text(
                  _categories[i],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: sel ? const Color(0xFFC8A436) : const Color(0xFF888888),
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

        return ListenableBuilder(
          listenable: MatchController.instance,
          builder: (context, _) {
            final ctrl = MatchController.instance;
            final match = ctrl.upcoming.isNotEmpty
                ? ctrl.upcoming.first
                : MatchModel.mockUpcoming.first;

            final now      = DateTime.now();
            final daysLeft = match.date.difference(now).inDays;
            final pronoOpen = !match.date.isBefore(now) && daysLeft < 7;
            final opensOn  = match.date.subtract(const Duration(days: 7));

            final pronoFooter = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pronoOpen
                  ? (isLogged
                      ? () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PronoScreen()))
                      : () => Navigator.pushNamed(context, '/login'))
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      pronoOpen ? Icons.sports_soccer_rounded : Icons.schedule_rounded,
                      size: 14,
                      color: pronoOpen ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pronoOpen
                          ? (isLogged ? 'PRONOSTIQUER CE MATCH' : 'CONNECTE-TOI POUR PRONOSTIQUER')
                          : 'PRONO DISPO LE ${_fmtDate(opensOn)}',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: pronoOpen ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            );

            return MatchCard(
              match: match,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
              ),
              showStats: true,
              footerOverride: pronoFooter,
            );
          },
        );
      },
    );
  }
}

// ── DVCR TV — style _VideoCard de live_screen ─────────────────────────────────
class _DVCRTVRow extends StatefulWidget {
  @override
  State<_DVCRTVRow> createState() => _DVCRTVRowState();
}

class _DVCRTVRowState extends State<_DVCRTVRow> {
  late final Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.getAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snap) {
        final List<VideoModel> videos = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : VideoModel.mock;

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
                    MaterialPageRoute(builder: (_) => NativeVideoScreen(
                      videoId: videos[i].cleanId,
                      title: videos[i].title,
                    )),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 22),
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
      case 'podcast':  return 'Émission DVCR';
      case 'matchday': return 'Jour de match';
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
    return ListenableBuilder(
      listenable: MatchController.instance,
      builder: (context, _) {
        final matches = MatchController.instance.results.isNotEmpty
            ? MatchController.instance.results.take(3).toList()
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
                        ? () {
                            final video = VideoModel(
                              id: m.id,
                              title: '${m.team1} - ${m.team2}',
                              youtubeId: m.replayVideoId!,
                              duration: '',
                              date: m.date,
                              category: 'resume',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => VideoWebScreen(video: video)),
                            );
                          }
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

// ── Bannière émission DVCR en direct ─────────────────────────────────────────
class _EmissionLiveBanner extends StatelessWidget {
  final String title;
  final String? url;
  final int viewers;
  final Animation<double> pulse;
  const _EmissionLiveBanner({
    required this.title,
    required this.url,
    required this.viewers,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: url != null && url!.isNotEmpty
          ? () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication)
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kRed.withAlpha(120)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Fond image légère
              Positioned.fill(
                child: Image.asset(
                  'assets/images/IMG_0842.JPG',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withAlpha(220),
                        Colors.black.withAlpha(120),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Badge EN DIRECT pulsant
                    AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kRed.withAlpha(
                              (180 + (pulse.value * 75)).toInt()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text('EN DIRECT',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1.2,
                              )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Titre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (viewers > 0)
                            Row(
                              children: [
                                const Icon(Icons.visibility_rounded,
                                    size: 10, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text('$viewers spectateurs',
                                    style: GoogleFonts.barlow(
                                        fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Bouton play
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('REGARDER',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 0.8,
                            )),
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

// ── Podcast DVCR — RSS SoundCloud ─────────────────────────────────────────────
const _kGold = Color(0xFFC8A436);

class _PodcastSection extends StatelessWidget {
  const _PodcastSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        if (ctrl.isLoading) {
          return const SizedBox(
            height: 110,
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kGold))),
          );
        }
        if (ctrl.episodes.isEmpty) return const SizedBox();

        return SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ctrl.episodes.length,
            itemBuilder: (context, i) {
              final ep = ctrl.episodes[i];
              final isActive = ctrl.currentIndex == i;
              return GestureDetector(
                onTap: () => ctrl.togglePlay(i),
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF1A1600) : _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? _kGold : _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.headphones_rounded, size: 14, color: _kGold),
                          const SizedBox(width: 6),
                          const Text('PODCAST', style: TextStyle(fontSize: 10, color: _kGold, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const Spacer(),
                          Icon(
                            isActive && ctrl.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 20,
                            color: isActive ? _kGold : _kGrey,
                          ),
                        ],
                      ),
                      Text(
                        ep.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: _kGrey),
                          const SizedBox(width: 4),
                          Text(ep.duration, style: const TextStyle(fontSize: 10, color: _kGrey)),
                          const Spacer(),
                          Text(_relDate(ep.pubDate), style: const TextStyle(fontSize: 10, color: _kGrey)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String _fmtDate(DateTime d) {
  const months = ['jan','fév','mar','avr','mai','juin',
      'juil','aoû','sep','oct','nov','déc'];
  return '${d.day} ${months[d.month - 1]}';
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
