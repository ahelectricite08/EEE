import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article_model.dart';
import '../services/article_service.dart';
import '../services/user_service.dart';
import '../widgets/donation_banner.dart';
import 'article_editor_screen.dart';

// ── Palette identique à live_screen ───────────────────────────────────────────
const _kRed    = Color(0xFFBA203C);
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kGrey   = Color(0xFF888888);

const _categories = ['TOUT', 'RÉSULTATS', 'AVANT-MATCH', 'CHRONIQUES SEDANAISES', 'ANALYSE', 'COULISSES', 'CLUB'];

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':   return const Color(0xFF4CAF50);
    case 'AVANT-MATCH': return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':   return const Color(0xFF2196F3);
    case 'ANALYSE':   return const Color(0xFF9C27B0);
    case 'COULISSES': return const Color(0xFFFF9800);
    case 'CLUB':      return _kRed;
    default:          return _kGrey;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});
  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  int _catIndex = 0;
  bool _isAdmin      = false;
  bool _isStrictAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canEditArticles().then((v) { if (mounted) setState(() => _isAdmin = v); });
    UserService.isAdmin().then((v) { if (mounted) setState(() => _isStrictAdmin = v); });
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_catIndex];

    return Scaffold(
      backgroundColor: _kBg,
      body: StreamBuilder<List<ArticleModel>>(
        stream: ArticleService.all(
          category: cat == 'TOUT' ? null : cat,
          limit: 20,
        ),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _kRed));
          }
          final articles = snap.data!;
          if (articles.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildFilters()),
                const SliverFillRemaining(
                  child: Center(
                    child: Text('Aucun article pour le moment',
                      style: TextStyle(color: _kGrey, fontSize: 14)),
                  ),
                ),
              ],
            );
          }

          final featured = articles.firstWhere(
            (a) => a.featured, orElse: () => articles.first);
          final rest = articles.where((a) => a.id != featured.id).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),

              SliverToBoxAdapter(
                child: _isAdmin
                    ? GestureDetector(
                        onLongPress: () => _showMenu(context, featured, _isStrictAdmin),
                        child: _FeaturedHero(
                          article: featured,
                          onTap: () => _openDetail(context, featured),
                        ),
                      )
                    : _FeaturedHero(
                        article: featured,
                        onTap: () => _openDetail(context, featured),
                      ),
              ),

              SliverToBoxAdapter(child: _buildFilters()),
              SliverToBoxAdapter(child: _SectionHeader(
                label: cat == 'TOUT' ? 'DERNIÈRES ACTUS' : cat,
              )),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final article = rest[i];
                    return _isAdmin
                        ? GestureDetector(
                            onLongPress: () => _showMenu(context, article, _isStrictAdmin),
                            child: _ArticleRow(
                              article: article,
                              isLast: i == rest.length - 1,
                              onTap: () => _openDetail(context, article),
                            ),
                          )
                        : _ArticleRow(
                            article: article,
                            isLast: i == rest.length - 1,
                            onTap: () => _openDetail(context, article),
                          );
                  },
                  childCount: rest.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: DonationBanner(
                  donationUrl: 'https://www.helloasso.com',
                  photoAsset: 'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                  title: 'SOUTENEZ DVCR',
                  subtitle: 'Chaque don nous aide à grandir',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }

  void _showMenu(BuildContext context, ArticleModel article, bool canDelete) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title: Text('Modifier', style: GoogleFonts.barlow(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ArticleEditorScreen(article: article)));
              },
            ),
            ListTile(
              leading: Icon(
                article.featured ? Icons.star : Icons.star_border,
                color: article.featured ? Colors.amber : Colors.white70),
              title: Text(article.featured ? 'Retirer de la une' : 'Mettre à la une',
                style: GoogleFonts.barlow(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                if (article.featured) {
                  await ArticleService.removeFeatured(article.id);
                } else {
                  await ArticleService.setFeatured(article.id);
                }
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFAA3A3A)),
                title: Text('Supprimer', style: GoogleFonts.barlow(color: const Color(0xFFAA3A3A))),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF161616),
                      title: Text('Supprimer ?', style: GoogleFonts.barlowCondensed(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      content: Text('Cette action est irréversible.',
                        style: GoogleFonts.barlow(color: Colors.white54)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                          child: Text('Annuler', style: TextStyle(color: Colors.white38))),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                          child: Text('Supprimer', style: TextStyle(color: _kRed))),
                      ],
                    ),
                  );
                  if (ok == true) await ArticleService.delete(article.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── AppBar style RÉSULTATS ────────────────────────────────────────────────
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
        child: Container(height: 1, color: _kBorder),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ACTUS',
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

  // ── Filtres style RÉSULTATS (gold) ───────────────────────────────────
  Widget _buildFilters() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final sel = _catIndex == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _catIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? Color(0xFFC8A436).withAlpha(20) : Colors.transparent,
                    border: Border.all(
                      color: sel ? Color(0xFFC8A436) : _kBorder, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_categories[i],
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: sel ? Color(0xFFC8A436) : Colors.white70, letterSpacing: 0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, ArticleModel article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        children: [
          Text(
            label,
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
        ],
      ),
    );
  }
}

// ── Article vedette — hero style "Dernier Match"  ────────────────────────────
class _FeaturedHero extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;
  const _FeaturedHero({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(article.category);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              article.imageUrl != null
                  ? Image.asset(
                      'assets/images/177e5a12-99f4-43bd-9a90-4f9703b49a0a.jpg',
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : Container(height: 220, color: _kCard),
              
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.black.withAlpha(20),
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                ),
              ),
              
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(200),
                      ],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 140, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onTap,
                      child: Row(
                        children: [
                          Text('DERNIER ARTICLE',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white70, letterSpacing: 1.5,
                              shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white, height: 1.2,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFC8A436), width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('LIRE L\'ARTICLE',
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFFC8A436), letterSpacing: 0.5)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: Color(0xFFC8A436), size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Article row —style match card compact ──────────────────────────────────────
class _ArticleRow extends StatelessWidget {
  final ArticleModel article;
  final bool isLast;
  final VoidCallback onTap;
  const _ArticleRow(
      {required this.article, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(article.category);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 44,
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
                          Text(
                            article.category.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            article.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (article.imageUrl != null)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _kCard,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(article.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.article_outlined, color: color, size: 20))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isLast) Container(height: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 14)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
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

class _CatBadge extends StatelessWidget {
  final String category;
  final Color color;
  const _CatBadge({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE DÉTAIL ARTICLE
// ─────────────────────────────────────────────────────────────────────────────
class ArticleDetailScreen extends StatelessWidget {
  final ArticleModel article;
  const ArticleDetailScreen({super.key, required this.article});

  List<Widget> _buildContent(String content) {
    final photoRegex = RegExp(r'\[PHOTO:(.*?)\]');
    final parts = content.split(photoRegex);
    final matches = photoRegex.allMatches(content).map((m) => m.group(1)!).toList();
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].trim().isNotEmpty) {
        widgets.add(Text(
          parts[i].trim(),
          style: GoogleFonts.barlow(fontSize: 15, color: const Color(0xFFCCCCCC), height: 1.7),
        ));
      }
      if (i < matches.length) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            matches[i],
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ));
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor(article.category.toUpperCase());

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: _kBg,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () {
                    final clean = article.content
                        .replaceAll(RegExp(r'\[PHOTO:.*?\]'), '')
                        .trim();
                    final preview = clean.length > 150
                        ? '${clean.substring(0, 150).trimRight()}…'
                        : clean;
                    Share.share(
                      '📰 ${article.title}\n\n'
                      '$preview\n\n'
                      'La suite à lire sur l\'app DVCR !',
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.ios_share_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  article.imageUrl != null
                      ? Image.network(article.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF0A0A0A)))
                      : Container(
                          color: const Color(0xFF0A0A0A),
                          child: Center(
                            child: Icon(Icons.article_outlined,
                                size: 64, color: color.withAlpha(60)),
                          ),
                        ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black, Colors.transparent],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CatBadge(category: article.category, color: color),
                      const SizedBox(width: 10),
                      Text(
                        _relDate(article.date),
                        style: GoogleFonts.barlow(fontSize: 12, color: _kGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    article.title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _kCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBorder),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 16, color: _kGrey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.authorName ?? 'Rédaction DVCR',
                        style: GoogleFonts.barlow(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    height: 1,
                    color: _kBorder,
                  ),

                  ..._buildContent(article.content),

                  const SizedBox(height: 32),

                  Wrap(
                    spacing: 8,
                    children: [
                      _CatBadge(category: article.category, color: color),
                      _CatBadge(category: 'DVCR', color: _kRed),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
