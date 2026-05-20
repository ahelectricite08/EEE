import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/video_model.dart';
import '../services/user_service.dart';
import 'video_web_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF141414);
const _kRed    = Color(0xFFBA203C);
const _kGrey   = Color(0xFF666666);
const _kBorder = Color(0xFF1E1E1E);

// ── Mock data ─────────────────────────────────────────────────────────────────
final _mockResumes = [
  VideoModel(id:'r1', title:'LE MATCH : CSSA 3-1 Romans SC',          youtubeId:'dQw4w9WgXcQ', duration:'05:14', date:DateTime.now().subtract(const Duration(days:4)),  category:'resume',   views:3560),
  VideoModel(id:'r2', title:'LE RÉSUMÉ : Grenoble B 0-2 CSSA',        youtubeId:'dQw4w9WgXcQ', duration:'04:47', date:DateTime.now().subtract(const Duration(days:11)), category:'resume',   views:2100),
  VideoModel(id:'r3', title:'LES TEMPS FORTS : CSSA 1-1 Étoile',      youtubeId:'dQw4w9WgXcQ', duration:'06:22', date:DateTime.now().subtract(const Duration(days:18)), category:'resume',   views:1840),
  VideoModel(id:'r4', title:'LE MATCH : CSSA 2-0 Oyonnax FC',         youtubeId:'dQw4w9WgXcQ', duration:'05:55', date:DateTime.now().subtract(const Duration(days:25)), category:'resume',   views:2600),
];
final _mockPodcasts = [
  VideoModel(id:'p1', title:'ÉMISSION #12 — Analyse de la saison',    youtubeId:'dQw4w9WgXcQ', duration:'42:18', date:DateTime.now().subtract(const Duration(days:3)),  category:'podcast',  views:890),
  VideoModel(id:'p2', title:'INTERVIEW — Le capitaine se confie',      youtubeId:'dQw4w9WgXcQ', duration:'28:45', date:DateTime.now().subtract(const Duration(days:8)),  category:'podcast',  views:1240),
  VideoModel(id:'p3', title:'ÉMISSION #11 — Mercato & objectifs',      youtubeId:'dQw4w9WgXcQ', duration:'38:07', date:DateTime.now().subtract(const Duration(days:14)), category:'podcast',  views:760),
  VideoModel(id:'p4', title:'TALK DVCR — Le derby régional',           youtubeId:'dQw4w9WgXcQ', duration:'51:33', date:DateTime.now().subtract(const Duration(days:21)), category:'podcast',  views:1580),
];
final _mockMatchday = [
  VideoModel(id:'m1', title:'JOUR DE MATCH — CSSA vs Romans SC',       youtubeId:'dQw4w9WgXcQ', duration:'18:42', date:DateTime.now().subtract(const Duration(days:4)),  category:'matchday', views:2340),
  VideoModel(id:'m2', title:'DANS LE VESTIAIRE avant le coup d\'envoi',youtubeId:'dQw4w9WgXcQ', duration:'12:07', date:DateTime.now().subtract(const Duration(days:11)), category:'matchday', views:1870),
  VideoModel(id:'m3', title:'ÉCHAUFFEMENT & AMBIANCE — Grenoble',      youtubeId:'dQw4w9WgXcQ', duration:'09:55', date:DateTime.now().subtract(const Duration(days:18)), category:'matchday', views:1420),
  VideoModel(id:'m4', title:'AFTER MATCH — Réactions des joueurs',     youtubeId:'dQw4w9WgXcQ', duration:'14:33', date:DateTime.now().subtract(const Duration(days:25)), category:'matchday', views:1950),
];
List<VideoModel> get _mockLatest {
  final all = [..._mockResumes, ..._mockPodcasts, ..._mockMatchday];
  all.sort((a, b) => b.date.compareTo(a.date));
  return all.take(6).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar + Hero intégrés — photo depuis le tout haut
          SliverAppBar(
            pinned: true,
            expandedHeight: 290,
            backgroundColor: _kBg,
            elevation: 0,
            titleSpacing: 0,
            toolbarHeight: 52,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('DVCR', style: GoogleFonts.barlowCondensed(
                    fontSize: 26, fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: _kRed, letterSpacing: 1)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kRed, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('CONTENU', style: GoogleFonts.barlowCondensed(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: _kRed, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
            flexibleSpace: const FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroPhoto(),
            ),
          ),

          // ── Sections vidéos ──────────────────────────────────────────────
          SliverToBoxAdapter(child: _Section(
            title: 'DERNIÈRES VIDÉOS',
            category: 'all',
            mock: _mockLatest,
            subLabel: '',
          )),
          SliverToBoxAdapter(child: _Section(
            title: 'RÉSUMÉS DE MATCHS',
            category: 'resume',
            mock: _mockResumes,
            subLabel: 'Régional 1 · 2024/25',
          )),
          SliverToBoxAdapter(child: _Section(
            title: 'ÉMISSIONS & PODCASTS',
            category: 'podcast',
            mock: _mockPodcasts,
            subLabel: 'DVCR Média',
          )),
          SliverToBoxAdapter(child: _Section(
            title: 'JOUR DE MATCH',
            category: 'matchday',
            mock: _mockMatchday,
            subLabel: 'Coulisses',
          )),

          const SliverToBoxAdapter(child: _PartenaireSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Hero photo pleine largeur — depuis le haut de l'écran ────────────────────
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/JOURDEMATCH.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF111111),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer_rounded,
                      size: 48, color: _kRed.withAlpha(80)),
                  const SizedBox(height: 8),
                  Text('CSSA', style: GoogleFonts.barlowCondensed(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Colors.white38, letterSpacing: 4)),
                ],
              ),
            ),
          ),
        ),
        // Gradient haut — status bar + toolbar lisibles
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.center,
                colors: [Colors.black.withAlpha(160), Colors.transparent],
              ),
            ),
          ),
        ),
        // Gradient bas fort — couvre toute la partie basse
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withAlpha(240), Colors.transparent],
                stops: const [0.0, 0.65],
              ),
            ),
          ),
        ),
        // Contenu bannière overlayé en bas de la photo
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DVCR', style: GoogleFonts.barlowCondensed(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 2)),
                    const SizedBox(height: 3),
                    Text('Le média 100% CSSA · sans engagement',
                      style: GoogleFonts.barlow(
                        fontSize: 12, color: Colors.white60, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Soutenir', style: GoogleFonts.barlowCondensed(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bannière support DVCR (style OLPLAY) ─────────────────────────────────────
class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border.symmetric(
          horizontal: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DVCR', style: GoogleFonts.barlowCondensed(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 3),
                Text('Le média 100% CSSA\nsans engagement',
                  style: GoogleFonts.barlow(
                    fontSize: 12, color: _kGrey, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Bouton sport — carré avec border, pas de pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Soutenir', style: GoogleFonts.barlowCondensed(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section titre + scroll horizontal ────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final String category;
  final List<VideoModel> mock;
  final String subLabel;

  const _Section({
    required this.title,
    required this.category,
    required this.mock,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre section — grand, centré, blanc
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1.5)),
          ),
          // Underline rouge court
          Container(width: 28, height: 2,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _kRed, borderRadius: BorderRadius.circular(1))),
          // Vidéos
          StreamBuilder<QuerySnapshot>(
            stream: category == 'all'
                ? FirebaseFirestore.instance
                    .collection('videos')
                    .orderBy('created_at', descending: true)
                    .limit(8)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('videos')
                    .where('category', isEqualTo: category)
                    .orderBy('created_at', descending: true)
                    .limit(8)
                    .snapshots(),
            builder: (context, snap) {
              final vids = snap.hasData && snap.data!.docs.isNotEmpty
                  ? snap.data!.docs.map(VideoModel.fromFirestore).toList()
                  : mock;
              return _buildRow(context, vids);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<VideoModel> videos) {
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
            child: _VideoCard(
              video: videos[i],
              subLabel: subLabel.isEmpty ? _defaultLabel(videos[i].category) : subLabel,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VideoWebScreen(video: videos[i]))),
            ),
          ),
        ),
      ),
    );
  }

  String _defaultLabel(String cat) {
    switch (cat) {
      case 'resume':   return 'Régional 1 · 2024/25';
      case 'podcast':  return 'DVCR Média';
      case 'matchday': return 'Coulisses';
      default: return '';
    }
  }
}

// ── Section Partenaires ───────────────────────────────────────────────────────
class _PartenaireSection extends StatefulWidget {
  const _PartenaireSection();
  @override
  State<_PartenaireSection> createState() => _PartenaireSectionState();
}

class _PartenaireSectionState extends State<_PartenaireSection> {
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    UserService.getCurrentRole().then((role) {
      if (mounted) setState(() {
        _hasAccess = role == UserRole.admin ||
            role == UserRole.partenaire;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardW = MediaQuery.of(context).size.width * 0.465;
    final totalH = cardW * (9 / 16) + 68;

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre avec badge cadenas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ESPACE PARTENAIRES',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 1.5)),
                if (!_hasAccess) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_rounded, color: Color(0xFFFF9100), size: 20),
                ],
              ],
            ),
          ),
          Container(width: 28, height: 2,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9100), borderRadius: BorderRadius.circular(1))),
          if (!_hasAccess)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF333333)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Contenu exclusif · Réservé aux partenaires',
                  style: GoogleFonts.barlow(
                    fontSize: 11, color: const Color(0xFF888888),
                    fontWeight: FontWeight.w600)),
              ),
            ),
          // Vidéos
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .where('category', isEqualTo: 'partenaire')
                .orderBy('created_at', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snap) {
              final vids = snap.hasData && snap.data!.docs.isNotEmpty
                  ? snap.data!.docs.map(VideoModel.fromFirestore).toList()
                  : <VideoModel>[];
              if (vids.isEmpty) return const SizedBox();
              return SizedBox(
                height: totalH,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  itemCount: vids.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: cardW,
                      child: _hasAccess
                          ? _VideoCard(
                              video: vids[i],
                              subLabel: 'Partenaires',
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => VideoWebScreen(video: vids[i]))),
                            )
                          : _LockedVideoCard(video: vids[i]),
                    ),
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

// ── Carte vidéo verrouillée ───────────────────────────────────────────────────
class _LockedVideoCard extends StatelessWidget {
  final VideoModel video;
  const _LockedVideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    final thumb = video.youtubeThumbnail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail visible
                Image.network(thumb, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: _kCard)),
                // Flou par-dessus
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: Colors.black.withAlpha(100),
                  ),
                ),
                // Overlay cadenas centré
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9100),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFFF9100).withAlpha(100),
                            blurRadius: 14, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 5),
                      Text('PARTENAIRES',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Espace identique aux cartes normales pour aligner les hauteurs
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('', style: GoogleFonts.barlowCondensed(fontSize: 13, height: 1.2),
            maxLines: 2),
        ),
      ],
    );
  }
}

// ── Carte vidéo ───────────────────────────────────────────────────────────────
class _VideoCard extends StatelessWidget {
  final VideoModel video;
  final String subLabel;
  final VoidCallback onTap;
  const _VideoCard({required this.video, required this.subLabel, required this.onTap});

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
                  Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _kCard,
                      child: Center(child: Icon(Icons.sports_soccer_rounded,
                          color: _kRed.withAlpha(60), size: 32)),
                    ),
                  ),
                  // Gradient bas
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withAlpha(160), Colors.transparent],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                  // Play button
                  Center(
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kRed, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: Colors.black.withAlpha(120), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  // Durée
                  if (video.duration.isNotEmpty)
                    Positioned(bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(video.duration,
                          style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Texte
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subLabel.isNotEmpty)
                  Text(subLabel, style: GoogleFonts.barlow(
                      fontSize: 10, color: _kGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(video.title, style: GoogleFonts.barlowCondensed(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


