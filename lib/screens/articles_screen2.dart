import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article_model.dart';
import '../services/article_service.dart';
import '../services/user_service.dart';
import 'article_editor_screen.dart';

// ── Palette style RÉSULTATS ──────────────────────────────────────────────────────
const _kRed    = Color(0xFFBA203C);
const _kGreen  = Color(0xFF0A4438);
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kGrey   = Color(0xFF888888);
const _kGold   = Color(0xFFC8A436);

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
  bool _isAdmin      = false; // peut modifier (admin + éditeur)
  bool _isStrictAdmin = false; // peut supprimer (admin uniquement)

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

          // Article à la une = featured:true ou premier par défaut
          final featured = articles.firstWhere(
            (a) => a.featured, orElse: () => articles.first);
          final rest = articles.where((a) => a.id != featured.id).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeroAppBar(context, featured),

              SliverToBoxAdapter(child: _buildFilters()),
              SliverToBoxAdapter(child: _SectionHeader(
                label: cat == 'TOUT' ? 'DERNIÈRES ACTUS' : cat,
              )),

              // ── Feed articles ─────────────────────────────────────────────
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
      backgroundColor: const Color(0xFF142019),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: _kGrey),
              title: Text('Modifier', style: GoogleFonts.inter(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ArticleEditorScreen(article: article)));
              },
            ),
            ListTile(
              leading: Icon(
                article.featured ? Icons.star : Icons.star_border,
                color: article.featured ? Colors.amber : _kGrey),
              title: Text(article.featured ? 'Retirer de la une' : 'Mettre à la une',
                style: GoogleFonts.inter(color: Colors.white70)),
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
                title: Text('Supprimer', style: GoogleFonts.inter(color: const Color(0xFFAA3A3A))),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: _kCard,
                      title: Text('Supprimer ?', style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      content: Text('Cette action est irréversible.',
                        style: GoogleFonts.inter(color: _kGrey)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                          child: Text('Annuler', style: TextStyle(color: _kGrey))),
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

  // ── AppBar style live_screen ──────────────────────────────────────────────
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
            'assets/images/Copie de JOUR DE MATCH.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withAlpha(80)),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text('ACTUS',
              style: GoogleFonts.permanentMarker(
                fontSize: 24, color: Colors.white)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('DVCR', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar + hero combinés (image remonte jusqu'en haut) ─────────────────
  SliverAppBar _buildHeroAppBar(BuildContext context, ArticleModel featured) {
    final color   = _catColor(featured.category);
    final topPad  = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + 52 + 260,
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 52,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text('ACTUS', style: GoogleFonts.permanentMarker(fontSize: 24, color: Colors.white)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('DVCR', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 1)),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Copie de JOUR DE MATCH.png',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withAlpha(80)),
            children: [
              // Image pleine largeur jusqu'en haut
              featured.imageUrl != null
                  ? Image.network(featured.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: _kBg,
                        child: Center(child: Icon(Icons.article_outlined, size: 48, color: color.withAlpha(80)))))
                  : Container(color: _kBg,
                      child: Center(child: Icon(Icons.article_outlined, size: 48, color: color.withAlpha(80)))),

              // Gradient haut pour lisibilité de la status bar
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: const Alignment(0, -0.2),
                      colors: [Colors.black.withAlpha(140), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // Gradient bas — titre lisible
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

              // Badge "À LA UNE" — sous la toolbar
              Positioned(
                top: topPad + 52 + 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text('À LA UNE', style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 1)),
                ),
              ),

              // Badge catégorie — sous la toolbar
              Positioned(
                top: topPad + 52 + 10,
                left: 12,
                child: _CatBadge(category: featured.category, color: color),
              ),

              // Titre + meta en bas
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(featured.title,
                      style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: Colors.white, height: 1.15),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(_relDate(featured.date),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                      Text('  ·  ', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                      Text(featured.authorName ?? 'Rédaction DVCR',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtres angulaires style sport ───────────────────────────────────────
  Widget _buildFilters() {
    return Container(
      color: _kBg,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final sel = _catIndex == i;
            final color = _catColor(_categories[i]);
            return GestureDetector(
              onTap: () => setState(() => _catIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? color : _kCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: sel ? color : _kBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  _categories[i],
                  style: GoogleFonts.inter(
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

  void _openDetail(BuildContext context, ArticleModel article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }
}

// ── Header section — centré + underline rouge (style _Section de live_screen) ─
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
            style: GoogleFonts.permanentMarker(
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 28,
            height: 2,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Article row ────────────────────────────────────────────────────────────────
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Barre colorée gauche (style catégorie)
                Container(
                  width: 3,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Catégorie + date
                      Row(
                        children: [
                          Text(
                            article.category.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _kBorder),
                          ),
                          Text(
                            _relDate(article.date),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Titre
                      Text(
                        article.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Auteur
                      Text(
                        article.authorName ?? 'Rédaction DVCR',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Thumbnail
                Container(
                  width: 88,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: article.imageUrl != null
                      ? Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumb(color),
                        )
                      : _thumb(color),
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  Widget _thumb(Color color) => Container(
    color: _kBg,
    child: Center(
      child: Icon(Icons.article_outlined, size: 22, color: color.withAlpha(80)),
    ),
  );
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
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
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

  // Parse le contenu et insère les photos [PHOTO:url] à la bonne position
  List<Widget> _buildContent(String content) {
    final photoRegex = RegExp(r'\[PHOTO:(.*?)\]');
    final parts = content.split(photoRegex);
    final matches = photoRegex.allMatches(content).map((m) => m.group(1)!).toList();
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].trim().isNotEmpty) {
        widgets.add(Text(
          parts[i].trim(),
          style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFFCCCCCC), height: 1.7),
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
          // Hero image + back button
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: _kGreen,
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
                              Container(color: _kGreen))
                      : Container(
                          color: _kGreen,
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

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie + date
                  Row(
                    children: [
                      _CatBadge(category: article.category, color: color),
                      const SizedBox(width: 10),
                      Text(
                        _relDate(article.date),
                        style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Titre
                  Text(
                    article.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Auteur
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kGrey,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    height: 1,
                    color: _kBorder,
                  ),

                  // Corps de l'article avec photos inline
                  ..._buildContent(article.content),

                  const SizedBox(height: 32),

                  // Tags bas
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
