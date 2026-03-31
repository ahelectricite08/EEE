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
            return const Center(child: CircularProgressIndicator(color: _kGold));
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
              _buildHeroAppBar(context, featured),
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
      backgroundColor: _kCard,
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
                color: article.featured ? _kGold : _kGrey),
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

  // ── AppBar + hero avec image article ──────────────────────────────────────
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
            GestureDetector(
              onTap: () => _openDetail(context, featured),
              onLongPress: _isAdmin ? () => _showMenu(context, featured, _isStrictAdmin) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  featured.imageUrl != null
                      ? Image.network(featured.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: _kBg,
                            child: Center(child: Icon(Icons.article_outlined, size: 48, color: color.withAlpha(80)))))
                      : Container(color: _kBg,
                          child: Center(child: Icon(Icons.article_outlined, size: 48, color: color.withAlpha(80)))),

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

                  Positioned(
                    left: 14, right: 14, bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(3)),
                          child: Text(featured.category,
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 0.3)),
                        ),
                        const SizedBox(height: 6),
                        Text(featured.title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
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
          ],
        ),
      ),
    );
  }

  // ── Filtres colorés ───────────────────────────────────────────────────────
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
              color: _kGold,
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
  const _ArticleRow({required this.article, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(article.category);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article.category,
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: color, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(article.title,
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.white),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(article.authorName ?? 'Rédaction DVCR',
                        style: GoogleFonts.inter(
                          fontSize: 11, color: _kGrey)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (article.imageUrl != null)
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _kCard,
                    ),
                    child: Image.network(article.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>  Center(
                        child: Icon(Icons.article_outlined, color: color, size: 24))),
                  ),
              ],
            ),
          ),
          if (!isLast) Container(height: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
        ],
      ),
    );
  }
}
