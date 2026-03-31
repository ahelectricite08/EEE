import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/video_model.dart';
import '../services/youtube_playlist_service.dart';
import 'native_video_screen.dart';
import '../services/user_service.dart';
import '../widgets/donation_banner.dart';
import 'video_web_screen.dart';

// ── Palette Option C — "Split" clair ─────────────────────────────────────────
const _kBg      = Color(0xFF0D0D0D);
const _kCard    = Color(0xFFFFFFFF);
const _kRed     = Color(0xFFBA203C);
const _kGrey    = Color(0xFF888888);
const _kBorder  = Color(0xFFDDD8CF);
const _kGreen   = Color(0xFF0A4438);
const _kText    = Color(0xFFFFFFFF);
const _kTextSub = Color(0xFF556B62);

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
          // AppBar — exactement comme ACTUS
          _buildAppBar(),

          // ── JOUR DE MATCH card ─────────────────────────────────────────
          const SliverToBoxAdapter(child: _JourDeMatchCard()),

          // ── Sections vidéos ──────────────────────────────────────────────
          SliverToBoxAdapter(child: _Section(
            title: 'DERNIÈRES VIDÉOS',
            category: 'all',
            mock: const [],
            subLabel: '',
          )),
          SliverToBoxAdapter(
            child: DonationBanner(
              donationUrl: 'https://www.helloasso.com',
              photoAsset: 'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
              title: 'SOUTENEZ DVCR',
              subtitle: 'Chaque don nous aide à grandir',
              compact: true,
            ),
          ),
          SliverToBoxAdapter(child: _Section(
            title: 'RÉSUMÉS DE MATCHS',
            category: 'resume',
            mock: const [],
            subLabel: 'Régional 1 · 2024/25',
          )),
          SliverToBoxAdapter(child: _Section(
            title: 'ÉMISSIONS & PODCASTS',
            category: 'podcast',
            mock: const [],
            subLabel: 'Émission DVCR',
          )),
          SliverToBoxAdapter(child: _Section(
            title: 'JOUR DE MATCH',
            category: 'matchday',
            mock: const [],
            subLabel: 'Jour de match',
          )),

          const SliverToBoxAdapter(child: _PartenaireSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── AppBar — exactement comme ACTUS ────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 52,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(140),
                  Colors.black.withAlpha(200),
                ],
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.transparent),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CONTENU',
            style: GoogleFonts.barlowCondensed(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 2,
              shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
            )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFC8A436).withAlpha(30),
              border: Border.all(color: const Color(0xFFC8A436), width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text('DVCR', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: const Color(0xFFC8A436), letterSpacing: 1)),
          ),
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
          errorBuilder: (_, __, ___) => Container(color: _kGreen),
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
                    Text('DVCR', style: GoogleFonts.permanentMarker(
                      fontSize: 22,
                      color: Colors.white)),
                    const SizedBox(height: 3),
                    Text('Le média 100% CSSA · sans engagement',
                      style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A4438), Color(0xFF166B57)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBorder, width: 1),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF0A4438).withAlpha(120),
                    blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Soutenir', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700,
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
// ── JOUR DE MATCH card — sans score ────────────────────────────────────────────
class _JourDeMatchCard extends StatelessWidget {
  const _JourDeMatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Zone photo + équipes (pas de score) ─────────────────────────────
          Stack(
            children: [
              Image.asset(
                'assets/images/JOURDEMATCH.jpg',
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                alignment: const Alignment(0.6, -0.5),
                errorBuilder: (_, __, ___) => Container(height: 220, color: _kCard),
              ),
              // Légère vignette pour lisibilité du bouton
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(220),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFC8A436), width: 1.2),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.black.withAlpha(90),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DRAPEAU VERT CARTON ROUGE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: const Color(0xFFC8A436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Le média 100% CSSA',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── Footer sombre avec bouton ──────────────────────────────────────
          const SizedBox(height: 0),
        ],
      ),
    );
  }
}

// ── Section titre + scroll horizontal ────────────────────────────────────────
class _Section extends StatefulWidget {
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
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late final Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = YoutubePlaylistService.forCategory(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 3,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC8A436),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          // Vidéos
          FutureBuilder<List<VideoModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && (!snap.hasData || snap.data!.isEmpty)) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFC8A436))),
                );
              }
              final vids = snap.data ?? [];
              if (vids.isEmpty) {
                return const SizedBox(
                  height: 40,
                  child: Center(child: Text('Aucune vidéo disponible', style: TextStyle(color: Colors.white70))),
                );
              }
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
              subLabel: widget.subLabel.isEmpty ? _defaultLabel(videos[i].category) : widget.subLabel,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => NativeVideoScreen(videoId: videos[i].cleanId, title: videos[i].title))),
            ),
          ),
        ),
      ),
    );
  }

  String _defaultLabel(String cat) {
    switch (cat) {
      case 'resume':   return 'Régional 1 · 2024/25';
      case 'podcast':  return 'Émission DVCR';
      case 'matchday': return 'Jour de match';
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
                  style: GoogleFonts.permanentMarker(
                    fontSize: 22,
                    color: _kText)),
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
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Contenu exclusif · Réservé aux partenaires',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: _kGrey,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          // Vidéos
          FutureBuilder<List<VideoModel>>(
            future: YoutubePlaylistService.getPartenaires(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && (!snap.hasData || snap.data!.isEmpty)) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFFF9100))),
                );
              }
              final vids = snap.data ?? [];
              if (vids.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Aucun contenu partenaire disponible', style: TextStyle(color: Colors.white70))),
                );
              }
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
                                builder: (_) => NativeVideoScreen(videoId: vids[i].cleanId, title: vids[i].title))),
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
                            color: _kText, size: 18),
                      ),
                      const SizedBox(height: 5),
                      Text('PARTENAIRES',
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: _kText, letterSpacing: 1.5)),
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
          child: Text('', style: GoogleFonts.inter(fontSize: 13, height: 1.2),
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
                        color: Colors.white.withAlpha(50), shape: BoxShape.circle,
                        border: Border.all(color: Colors.white60, width: 1.5),
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
                  Text(subLabel, style: GoogleFonts.inter(
                      fontSize: 10, color: _kGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(video.title, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kText, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

