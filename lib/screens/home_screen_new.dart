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

const _kRed    = Color(0xFFBA203C);
const _kGreen  = Color(0xFF0A4438);
const _kBg     = Color(0xFFF2EDE4);
const _kCard   = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFDDD8CF);
const _kGrey   = Color(0xFF888888);
const _kText   = Color(0xFF0A4438);
const _kTextSub = Color(0xFF556B62);

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':   return const Color(0xFF4CAF50);
    case 'AVANT-MATCH': return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':   return const Color(0xFF2196F3);
    case 'ANALYSE':     return const Color(0xFF9C27B0);
    case 'COULISSES':   return const Color(0xFFFF9800);
    default:            return _kGrey;
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
          // ── NETFLIX-STYLE HERO SECTION ───────────────────────────────
          _buildHeroSection(),

          // ── Featured Next Match Card ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
              child: _buildFeaturedNextMatch(),
            ),
          ),

          // ── DVCR TV Carousel ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SectionHeaderWidget(
                'DVCR TV',
                titleColor: _kText,
                leading: const Icon(Icons.play_circle_rounded, color: _kRed, size: 20),
                onSeeAll: () => widget.onSwitchTab?.call(1),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _DVCRTVRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Articles Grid Section ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SectionHeaderWidget(
                'ARTICLES',
                titleColor: _kText,
                leading: const Icon(Icons.article_rounded, color: _kRed, size: 20),
                onSeeAll: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ArticlesScreen())),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildCategoryFilter()),
          SliverToBoxAdapter(child: _ArticlesFeed(
            category: _categories[_categoryIndex],
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── Match Results Section ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SectionHeaderWidget(
                'RÉSULTATS RÉCENTS',
                titleColor: _kText,
                leading: const Icon(Icons.sports_score_rounded, color: _kGreen, size: 20),
                onSeeAll: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MatchesScreen())),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ResultsFeed()),

          // ── Quick Standings Widget ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: _buildStandingsWidget(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  // ── NETFLIX-STYLE HERO SECTION ─────────────────────────────────────
  SliverAppBar _buildHeroSection() {
    final user = FirebaseAuth.instance.currentUser;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 320,
      backgroundColor: _kGreen,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 52,
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
              color: user != null ? Colors.white : null,
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
          child: StreamBuilder<List<MatchModel>>(
            stream: MatchService.upcomingEnriched(),
            builder: (context, snap) {
              final match = (snap.hasData && snap.data!.isNotEmpty)
                  ? snap.data!.first
                  : MatchModel.mockUpcoming.first;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background image with parallax
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
                                style: GoogleFonts.permanentMarker(
                                    fontSize: 28,
                                    color: _kGrey)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Gradient top (status bar protection)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Colors.black.withAlpha(100), Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // Gradient bottom (strong cinematic effect)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(180),
                            Colors.black.withAlpha(100),
                            Colors.transparent
                          ],
                          stops: const [0.0, 0.4, 0.7],
                        ),
                      ),
                    ),
                  ),

                  // EN DIRECT badge (pulsing)
                  if (_isLive)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 16,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) =>
                            _PulsingLiveBadge(pulse: _pulse.value),
                      ),
                    ),

                  // Play button (if not live)
                  if (!_isLive)
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white60, width: 2),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 16)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),

                  // Content section - centered match info
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Team logos and names (central)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    match.teamHome.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [BoxShadow(
                                          color: Colors.black.withAlpha(80),
                                          blurRadius: 8)],
                                    ),
                                    child: Icon(Icons.sports_soccer_rounded,
                                        color: _kGreen, size: 28),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // VS center
                            if (_isLive || match.score != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isLive && _liveTeam1.isNotEmpty
                                      ? '$_scoreHome - $_scoreAway'
                                      : '${match.score?.home ?? 0} - ${match.score?.away ?? 0}',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: _kGreen,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'VS',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    match.teamAway.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [BoxShadow(
                                          color: Colors.black.withAlpha(80),
                                          blurRadius: 8)],
                                    ),
                                    child: Icon(Icons.sports_soccer_rounded,
                                        color: _kRed, size: 28),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Match status or countdown
                        if (_isLive)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.circle, size: 8, color: _kRed),
                              const SizedBox(width: 8),
                              Text('EN DIRECT',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  )),
                              if (_liveViewers > 0) ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.visibility_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('$_liveViewers spectateurs',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    )),
                              ],
                            ],
                          )
                        else
                          Text(
                            _formatMatchCountdown(match.date),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom overlay button bar
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (_isLive && _liveUrl != null && _liveUrl!.isNotEmpty) {
                                await launchUrl(Uri.parse(_liveUrl!),
                                    mode: LaunchMode.externalApplication);
                              } else {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => LiveScreen()));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _kRed,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(
                                    color: _kRed.withAlpha(100),
                                    blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isLive ? Icons.live_tv_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isLive ? 'EN DIRECT' : 'REGARDER',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── FEATURED NEXT MATCH CARD ───────────────────────────────────────
  Widget _buildFeaturedNextMatch() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final isLogged = authSnap.data != null;

        return StreamBuilder<List<MatchModel>>(
          stream: MatchService.upcomingEnriched(),
          builder: (context, snap) {
            final match = (snap.hasData && snap.data!.isNotEmpty)
                ? snap.data!.first
                : MatchModel.mockUpcoming.first;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _kBorder, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: _kCard,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with accent stripe
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [_kGreen, _kRed],
                          stops: [0, 1],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PROCHAIN MATCH',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            _formatMatchCountdown(match.date),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Match info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Teams and logos
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _kGreen.withAlpha(20),
                                        border: Border.all(color: _kGreen, width: 2),
                                      ),
                                      child: Icon(Icons.sports_soccer_rounded,
                                          color: _kGreen, size: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      match.teamHome.toUpperCase(),
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _kText,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Form indicators (W/L/D)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'FORME',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextSub,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _FormeBadge('W', _kGreen),
                                      const SizedBox(width: 4),
                                      _FormeBadge('D', _kGrey),
                                      const SizedBox(width: 4),
                                      _FormeBadge('L', _kRed),
                                    ],
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'VS',
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: _kGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Form indicators (W/L/D)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'FORME',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextSub,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _FormeBadge('L', _kRed),
                                      const SizedBox(width: 4),
                                      _FormeBadge('W', _kGreen),
                                      const SizedBox(width: 4),
                                      _FormeBadge('D', _kGrey),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _kRed.withAlpha(20),
                                        border: Border.all(color: _kRed, width: 2),
                                      ),
                                      child: Icon(Icons.sports_soccer_rounded,
                                          color: _kRed, size: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      match.teamAway.toUpperCase(),
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _kText,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Divider
                          Container(
                            height: 1,
                            color: _kBorder,
                          ),
                          const SizedBox(height: 16),
                          // Standing/Ranking
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '3ème',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _kGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'au classement',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: _kTextSub,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 24,
                                color: _kBorder,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '45 pts',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _kGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'points accumulés',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: _kTextSub,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 24,
                                color: _kBorder,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '2.1',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _kRed,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'cote prono',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: _kTextSub,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // PRONOSTIQUER button
                          GestureDetector(
                            onTap: isLogged
                                ? () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const PronoScreen()))
                                : () => Navigator.pushNamed(context, '/login'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_kGreen, _kGreen.withAlpha(220)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kGreen.withAlpha(80),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isLogged ? Icons.sports_soccer_rounded : Icons.lock_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isLogged ? 'PRONOSTIQUER' : 'CONNECTE-TOI POUR PRONOSTIQUER',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── QUICK STANDINGS WIDGET ─────────────────────────────────────────
  Widget _buildStandingsWidget() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: _kCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'CLASSEMENT',
              style: GoogleFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kText,
                letterSpacing: 1,
              ),
            ),
          ),
          Divider(color: _kBorder, height: 1, indent: 16, endIndent: 16),
          ..._buildStandingRows(),
        ],
      ),
    );
  }

  List<Widget> _buildStandingRows() {
    final teams = [
      {'rank': 1, 'name': 'SEDAN', 'points': 48, 'color': _kGreen},
      {'rank': 2, 'name': 'REIMS', 'points': 46, 'color': _kRed},
      {'rank': 3, 'name': 'NICE', 'points': 45, 'color': _kGrey},
    ];

    return teams.map((team) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (team['color'] as Color).withAlpha(30),
                border: Border.all(color: team['color'] as Color, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${team['rank']}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: team['color'] as Color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Team name
            Expanded(
              child: Text(
                team['name'] as String,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (team['color'] as Color).withAlpha(40),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${team['points']} pts',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: team['color'] as Color,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Category filter ────────────────────────────────────────────────
  Widget _buildCategoryFilter() {
    return Container(
      color: _kBg,
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
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? color : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? color : _kBorder,
                    width: sel ? 0 : 1.5,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: color.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Text(
                  _categories[i],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: sel ? Colors.white : _kGrey,
                  ),
                ),
              );
            );
          },
        ),
      ),
    );
  }

  String _formatMatchCountdown(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.isNegative) {
      return 'Terminé';
    } else if (diff.inDays > 0) {
      return 'Match dans ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'Match dans ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'Match dans ${diff.inMinutes}m';
    } else {
      return 'Commence maintenant';
    }
  }
}

// ── DVCR TV — Enhanced carousel with premium cards ──────────────────
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
                  // Gradient bottom
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
                  // Play button
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
                  // Duration badge
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
          // Title + category
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
                      color: _kText,
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

// ── Articles feed ──────────────────────────────────────────────────────
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
                                  color: _kText,
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

// ── Results feed ───────────────────────────────────────────────────────
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

// ── Small widgets ──────────────────────────────────────────────────────

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
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _FormeBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(30),
        border: Border.all(color: color, width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.barlowCondensed(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
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
        color: _kGreen.withAlpha(38),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kGreen.withAlpha(100)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kGreen,
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
