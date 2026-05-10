import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dvcr_share_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/article_model.dart';
import '../../services/article_service.dart';
import '../../services/article_comment_service.dart';
import '../../services/favorites_service.dart';
import '../../services/user_service.dart';
import '../../utils/share_helper.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/donation_banner.dart';
import '../../widgets/dvcr_reveal.dart';
import '../../widgets/empty_state_panel.dart';
import 'article_editor_screen.dart';
import 'article_detail_widgets.dart';
import 'articles_list_widgets.dart';

const _categories = [
  'TOUT',
  'RÉSULTATS',
  'AVANT-MATCH',
  'CHRONIQUES SEDANAISES',
  'ANALYSE',
  'COULISSES',
  'CLUB',
];

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':
      return const Color(0xFF4CAF50);
    case 'AVANT-MATCH':
      return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':
      return const Color(0xFF2196F3);
    case 'ANALYSE':
      return const Color(0xFF9C27B0);
    case 'COULISSES':
      return const Color(0xFFFF9800);
    case 'CLUB':
      return kArticlesRed;
    default:
      return kArticlesMuted;
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
  bool _isAdmin = false;
  bool _isStrictAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canEditArticles().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
    UserService.isAdmin().then((v) {
      if (mounted) setState(() => _isStrictAdmin = v);
    });
  }

  SliverAppBar _buildArticlesHeroSliver(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + 52 + 210,
      stretch: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 52,
      titleSpacing: 0,
      title: const ArticlesHeroPinnedToolbar(),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: const ArticlesHeroFlexibleSpace(title: 'ACTUS'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_catIndex];

    return Scaffold(
      backgroundColor: kArticlesSheet,
      bottomNavigationBar: Material(
        color: kArticlesSheet,
        elevation: 8,
        shadowColor: Colors.black26,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1, thickness: 1, color: kArticlesBorder),
              ArticleCategoryBar(
                selectedIndex: _catIndex,
                onChanged: (index) => setState(() => _catIndex = index),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<ArticleModel>>(
        stream: ArticleService.all(
          category: cat == 'TOUT' ? null : cat,
          limit: 20,
        ),
        builder: (context, snap) {
          if (!snap.hasData) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildArticlesHeroSliver(context),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(const [
                      DVCRCardSkeleton(),
                      SizedBox(height: 12),
                      DVCRCardSkeleton(),
                      SizedBox(height: 12),
                      DVCRCardSkeleton(),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          }

          final articles = snap.data!;
          if (articles.isEmpty) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildArticlesHeroSliver(context),
                SliverToBoxAdapter(
                  child: DVCRReveal(
                    duration: const Duration(milliseconds: 480),
                    offsetY: 20,
                    child: const ArticlesEmptyState(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          }

          final featured = articles.firstWhere(
            (a) => a.featured,
            orElse: () => articles.first,
          );
          final rest = articles.where((a) => a.id != featured.id).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildArticlesHeroSliver(context),
              SliverToBoxAdapter(
                child: DVCRReveal(
                  duration: const Duration(milliseconds: 480),
                  offsetY: 22,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isAdmin
                          ? GestureDetector(
                              onLongPress: () =>
                                  _showMenu(context, featured, _isStrictAdmin),
                              child: ArticlesFeaturedCard(
                                article: featured,
                                onTap: () => _openDetail(context, featured),
                              ),
                            )
                          : ArticlesFeaturedCard(
                              article: featured,
                              onTap: () => _openDetail(context, featured),
                            ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: Text(
                    cat == 'TOUT' ? 'Dernières actus' : cat,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: kArticlesText,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final article = rest[i];
                  return _isAdmin
                      ? GestureDetector(
                          onLongPress: () =>
                              _showMenu(context, article, _isStrictAdmin),
                          child: ArticleCompactCard(
                            article: article,
                            isLast: i == rest.length - 1,
                            onTap: () => _openDetail(context, article),
                          ),
                        )
                      : ArticleCompactCard(
                          article: article,
                          isLast: i == rest.length - 1,
                          onTap: () => _openDetail(context, article),
                        );
                }, childCount: rest.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: DonationBanner(
                  donationUrl: 'https://www.helloasso.com',
                  photoAsset:
                      'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                  title: 'SOUTENEZ DVCR',
                  subtitle: 'Chaque don nous aide à grandir',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  void _showMenu(BuildContext context, ArticleModel article, bool canDelete) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kArticlesIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: kArticlesBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: kArticlesGreen),
              title: Text(
                'Modifier',
                style: GoogleFonts.barlow(color: kArticlesText),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleEditorScreen(article: article),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                article.featured ? Icons.star : Icons.star_border,
                color: article.featured ? Colors.amber : Colors.white70,
              ),
              title: Text(
                article.featured ? 'Retirer de la une' : 'Mettre à la une',
                style: GoogleFonts.barlow(color: Colors.white),
              ),
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
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFAA3A3A),
                ),
                title: Text(
                  'Supprimer',
                  style: GoogleFonts.barlow(color: const Color(0xFFAA3A3A)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: kArticlesCard,
                      surfaceTintColor: Colors.transparent,
                      title: Text(
                        'Supprimer ?',
                        style: GoogleFonts.barlowCondensed(
                          color: kArticlesText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      content: Text(
                        'Cette action est irréversible.',
                        style: GoogleFonts.barlow(color: kArticlesMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Annuler',
                            style: TextStyle(color: kArticlesMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Supprimer',
                            style: const TextStyle(color: kArticlesRed),
                          ),
                        ),
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
  void _openDetail(BuildContext context, ArticleModel article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _ArticleRow extends StatelessWidget {
  final ArticleModel article;
  final bool isLast;
  final VoidCallback onTap;
  const _ArticleRow({
    required this.article,
    required this.onTap,
    this.isLast = false,
  });

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
                          if (article.displayCategoryLabel.isNotEmpty)
                            Text(
                              article.displayCategoryLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          if (article.displayCategoryLabel.isNotEmpty)
                            const SizedBox(height: 3),
                          Text(
                            article.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kArticlesText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                          color: kArticlesCard,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.article_outlined,
                              color: color,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 14,
                      color: kArticlesMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.viewsCount}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: kArticlesMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 14,
                      color: kArticlesMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.likesCount}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: kArticlesMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isLast)
            Container(
              height: 1,
              color: kArticlesBorder,
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE DÉTAIL ARTICLE
// ─────────────────────────────────────────────────────────────────────────────
class ArticleDetailScreen extends StatefulWidget {
  final ArticleModel article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  double _fontSize = 15.0;
  static const _kFontSizeKey = 'article_font_size';
  static const _kFontMin = 12.0;
  static const _kFontMax = 22.0;

  WebViewController? _wixWebController;
  String? _wixLoadedUrl;

  /// Titre dans la barre verte lorsque l’utilisateur a défilé (barre réduite).
  final ScrollController _articleScrollController = ScrollController();
  bool _showCollapsedArticleTitle = false;
  static const _kShowTitleScrollOn = 96.0;
  static const _kShowTitleScrollOff = 56.0;

  @override
  void initState() {
    super.initState();
    ArticleService.incrementView(widget.article.id);
    _loadFontSize();
    _articleScrollController.addListener(_onArticleDetailScroll);
  }

  void _onArticleDetailScroll() {
    if (!_articleScrollController.hasClients || !mounted) return;
    final o = _articleScrollController.offset;
    bool next = _showCollapsedArticleTitle;
    if (o >= _kShowTitleScrollOn) {
      next = true;
    } else if (o <= _kShowTitleScrollOff) {
      next = false;
    }
    if (next != _showCollapsedArticleTitle) {
      setState(() => _showCollapsedArticleTitle = next);
    }
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kFontSizeKey);
    if (saved != null && mounted) setState(() => _fontSize = saved);
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_kFontSizeKey, size);
  }

  void _showReadingOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kArticlesIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: kArticlesBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'TAILLE DU TEXTE',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kArticlesMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'A',
                    style: GoogleFonts.barlow(
                      fontSize: 13,
                      color: kArticlesMuted,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: kArticlesGreen,
                        inactiveTrackColor: kArticlesBorder,
                        thumbColor: kArticlesGreen,
                        overlayColor: kArticlesGreen.withAlpha(30),
                        trackHeight: 2,
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: _kFontMin,
                        max: _kFontMax,
                        divisions: 10,
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _fontSize = v);
                          _saveFontSize(v);
                        },
                      ),
                    ),
                  ),
                  Text(
                    'A',
                    style: GoogleFonts.barlow(
                      fontSize: 20,
                      color: kArticlesText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Aperçu du texte à cette taille',
                style: GoogleFonts.barlow(
                  fontSize: _fontSize,
                  color: kArticlesText,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _articleScrollController.removeListener(_onArticleDetailScroll);
    _articleScrollController.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _openRelatedArticle(BuildContext context, ArticleModel article) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }

  void _ensureWixWebView(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return;
    if (_wixLoadedUrl == u && _wixWebController != null) return;
    _wixLoadedUrl = u;
    _wixWebController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(u));
  }

  int _estimatedReadingMinutes(String content) {
    final clean = content
        .replaceAll(RegExp(r'\[PHOTO:.*?\]', dotAll: true), ' ')
        .replaceAll(RegExp(r'!\[.*?\]\(\\?.*?\)', dotAll: true), ' ')
        .trim();
    final words = clean
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return words == 0 ? 1 : ((words / 200).ceil()).clamp(1, 99);
  }

  String _plainTextFromHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _estimatedReadingMinutesForArticle(ArticleModel article) {
    if (article.contentHtml != null && article.contentHtml!.trim().isNotEmpty) {
      final t = _plainTextFromHtml(article.contentHtml!);
      if (t.length > 40) {
        return _estimatedReadingMinutes(t);
      }
    }
    return _estimatedReadingMinutes(article.content);
  }

  Map<String, Style> _wixArticleHtmlStyles(double fontSize) {
    return {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(fontSize),
        fontFamily: GoogleFonts.barlow().fontFamily,
        color: kArticlesText,
        lineHeight: LineHeight(1.65),
      ),
      'p': Style(margin: Margins.only(bottom: 14)),
      'h1': Style(
        fontSize: FontSize(fontSize + 10),
        fontWeight: FontWeight.w800,
        margin: Margins.only(bottom: 12, top: 6),
        fontFamily: GoogleFonts.barlowCondensed().fontFamily,
        color: kArticlesGreenDeep,
      ),
      'h2': Style(
        fontSize: FontSize(fontSize + 6),
        fontWeight: FontWeight.w800,
        margin: Margins.only(bottom: 10, top: 6),
        fontFamily: GoogleFonts.barlowCondensed().fontFamily,
        color: kArticlesGreenDeep,
      ),
      'h3': Style(
        fontSize: FontSize(fontSize + 4),
        fontWeight: FontWeight.w700,
        margin: Margins.only(bottom: 8, top: 4),
        color: kArticlesGreenDeep,
      ),
      'strong,b': Style(fontWeight: FontWeight.w700),
      'a': Style(
        color: kArticlesGreen,
        textDecoration: TextDecoration.underline,
      ),
      'ul,ol': Style(margin: Margins.only(bottom: 12)),
      'li': Style(margin: Margins.only(bottom: 6)),
      'blockquote': Style(
        border: Border(
          left: BorderSide(color: kArticlesGold.withValues(alpha: 0.7), width: 3),
        ),
        padding: HtmlPaddings.only(left: 12),
        margin: Margins.only(bottom: 14),
        fontStyle: FontStyle.italic,
        color: kArticlesMuted,
      ),
      'img': Style(width: Width(100, Unit.percent)),
      'figure': Style(margin: Margins.only(bottom: 16)),
    };
  }

  List<Widget> _buildContent(String content) {
    final widgets = <Widget>[];
    final imageRegex = RegExp(
      r'\[PHOTO:(.*?)\]|!\[.*?\]\((\\?.*?)\)',
      dotAll: true,
    );

    var start = 0;
    for (final match in imageRegex.allMatches(content)) {
      final textPart = content.substring(start, match.start).trim();
      if (textPart.isNotEmpty) {
        widgets.add(
          Text(
            textPart,
            style: GoogleFonts.barlow(
              fontSize: _fontSize,
              color: kArticlesText,
              height: 1.78,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 18));
      }

      final rawUrl = (match.group(1) ?? match.group(2) ?? '').trim();
      final imageUrl = rawUrl.startsWith(r'\') ? rawUrl.substring(1) : rawUrl;
      if (imageUrl.isNotEmpty) {
        widgets.add(
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kArticlesBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 18));
      }

      start = match.end;
    }

    final trailingText = content.substring(start).trim();
    if (trailingText.isNotEmpty) {
      widgets.add(
        Text(
          trailingText,
          style: GoogleFonts.barlow(
            fontSize: _fontSize,
            color: kArticlesText,
            height: 1.78,
          ),
        ),
      );
    }
    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }
    return widgets;
  }

  Future<void> _submitComment(ArticleModel article) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      await ArticleCommentService.addComment(
        articleId: article.id,
        message: _commentCtrl.text,
        displayName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'Supporter DVCR'),
      );
      _commentCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commentaire publié.')));
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<ArticleModel?>(
      stream: ArticleService.streamById(widget.article.id),
      builder: (context, snap) {
        final article = snap.data ?? widget.article;
        final color = _catColor(article.category.toUpperCase());
        final liked =
            currentUid.isNotEmpty && article.likedBy.contains(currentUid);

        if (article.isWixArticle && !article.hasDisplayableContentHtml) {
          final wu = article.wixUrl;
          if (wu != null && wu.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final before = _wixWebController;
              _ensureWixWebView(wu);
              if (before != _wixWebController) setState(() {});
            });
          }
        }

        return Scaffold(
          backgroundColor: kArticlesSheet,
          body: CustomScrollView(
            controller: _articleScrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: kArticlesGreenDeep,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                titleSpacing: 0,
                title: _showCollapsedArticleTitle
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          article.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            height: 1.15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : null,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kArticlesCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: kArticlesBorder),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: kArticlesText,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      article.imageUrl != null
                          ? Image.network(
                              article.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: kArticlesGreenDeep),
                            )
                          : Container(
                              color: kArticlesGreenDeep,
                              child: Center(
                                child: Icon(
                                  Icons.article_outlined,
                                  size: 64,
                                  color: articleCategoryColor(
                                    article.category,
                                  ).withAlpha(100),
                                ),
                              ),
                            ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              kArticlesGreenDeep.withAlpha(220),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Detail meta
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: ArticleDetailMetaCard(
                    article: article,
                    categoryColor: color,
                    liked: liked,
                    readingMinutes: _estimatedReadingMinutesForArticle(article),
                    onReadingOptions: () => _showReadingOptions(context),
                    onShare: () =>
                        DvcrShare.share(ShareHelper.articleText(article)),
                    favoriteButton: StreamBuilder<bool>(
                      stream: FavoritesService.watchIsFavorite(
                        FavoriteType.article,
                        article.id,
                      ),
                      builder: (context, snap) {
                        final isFavorite = snap.data ?? false;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => FavoritesService.toggle(
                              type: FavoriteType.article,
                              itemId: article.id,
                              title: article.title,
                              subtitle: article.categoryForShare,
                              imageUrl: article.imageUrl,
                              routeHint: 'article',
                              extra: {
                                'authorName': article.authorName,
                                'date': article.date.toIso8601String(),
                              },
                            ),
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kArticlesBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFavorite
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: isFavorite
                                        ? color
                                        : kArticlesGreenDeep,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Favori',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kArticlesText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Contenu ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (article.isWixArticle &&
                          article.hasDisplayableContentHtml &&
                          article.contentHtml != null) ...[
                        ArticleContentCard(
                          children: [
                            Html(
                              data: wixArticleHtmlForDisplay(article.contentHtml!),
                              shrinkWrap: true,
                              extensions: wixArticleHtmlExtensions(),
                              onLinkTap: (url, attributes, element) async {
                                if (url == null || url.isEmpty) return;
                                final u = Uri.tryParse(url);
                                if (u != null && await canLaunchUrl(u)) {
                                  await launchUrl(
                                    u,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              style: _wixArticleHtmlStyles(_fontSize),
                            ),
                            if (article.wixUrl != null &&
                                article.wixUrl!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final u = Uri.parse(article.wixUrl!);
                                    if (await canLaunchUrl(u)) {
                                      await launchUrl(
                                        u,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                    color: kArticlesGreenDeep,
                                  ),
                                  label: Text(
                                    'Ouvrir sur dvcr.fr',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: kArticlesGreenDeep,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (article.isWixArticle &&
                          article.wixUrl != null &&
                          article.wixUrl!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Chargement de l’article… Si le texte n’apparaît pas, '
                            'synchronise à nouveau depuis Wix ou ouvre la version site.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kArticlesMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (_wixWebController != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              height: (MediaQuery.sizeOf(context).height * 0.58)
                                  .clamp(380.0, 720.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: kArticlesBorder),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: WebViewWidget(
                                controller: _wixWebController!,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: kArticlesGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ] else
                        ArticleContentCard(
                          children: _buildContent(article.content),
                        ),

                      const SizedBox(height: 32),

                      const ArticleDetailSectionTitle(
                        title: 'Articles similaires',
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<ArticleModel>>(
                        stream: ArticleService.all(limit: 20),
                        builder: (context, relatedSnap) {
                          final allArticles =
                              (relatedSnap.data ?? const <ArticleModel>[])
                                  .where((item) => item.id != article.id)
                                  .toList();
                          final sameCategory = allArticles
                              .where(
                                (item) => item.category == article.category,
                              )
                              .toList();
                          final mostLiked = [...allArticles]
                            ..sort(
                              (a, b) => b.likesCount.compareTo(a.likesCount),
                            );

                          final related = <ArticleModel>[];
                          for (final item in sameCategory) {
                            if (!related.any(
                              (existing) => existing.id == item.id,
                            )) {
                              related.add(item);
                            }
                            if (related.length == 3) {
                              break;
                            }
                          }
                          for (final item in mostLiked) {
                            if (!related.any(
                              (existing) => existing.id == item.id,
                            )) {
                              related.add(item);
                            }
                            if (related.length == 3) {
                              break;
                            }
                          }

                          if (related.isEmpty) {
                            return Text(
                              'D\'autres articles arrivent bientôt.',
                              style: GoogleFonts.barlow(
                                fontSize: 13,
                                color: kArticlesMuted,
                              ),
                            );
                          }

                          return Column(
                            children: related.asMap().entries.map((entry) {
                              final index = entry.key;
                              final relatedArticle = entry.value;
                              return _ArticleRow(
                                article: relatedArticle,
                                isLast: index == related.length - 1,
                                onTap: () => _openRelatedArticle(
                                  context,
                                  relatedArticle,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      _ArticleCommentsSection(
                        article: article,
                        commentCtrl: _commentCtrl,
                        sending: _sendingComment,
                        onSubmit: () => _submitComment(article),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArticleCommentsSection extends StatelessWidget {
  final ArticleModel article;
  final TextEditingController commentCtrl;
  final bool sending;
  final VoidCallback onSubmit;

  const _ArticleCommentsSection({
    required this.article,
    required this.commentCtrl,
    required this.sending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ArticleDetailSectionTitle(title: 'Commentaires'),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kArticlesCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kArticlesBorder),
              ),
              child: Text(
                '${article.commentsCount}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: kArticlesMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (user == null)
          EmptyStatePanel(
            icon: Icons.lock_outline_rounded,
            title: 'Connecte-toi pour commenter',
            subtitle:
                'Les membres DVCR peuvent réagir et participer sous les articles.',
            actionLabel: 'SE CONNECTER',
            onAction: () => Navigator.pushNamed(context, '/login'),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kArticlesCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kArticlesBorder),
            ),
            child: Column(
              children: [
                TextField(
                  controller: commentCtrl,
                  minLines: 2,
                  maxLines: 5,
                  style: GoogleFonts.inter(fontSize: 13, color: kArticlesText),
                  decoration: InputDecoration(
                    hintText: 'Ton commentaire...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: kArticlesMuted,
                    ),
                    filled: true,
                    fillColor: kArticlesIvory,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kArticlesBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kArticlesBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kArticlesGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: sending ? null : onSubmit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kArticlesGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'PUBLIER',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
          builder: (context, userSnap) {
            final roles = UserService.parseRolesFromData(userSnap.data?.data());
            final canModerate = UserService.canModerateArticleComments(roles);
            final currentUid = user?.uid ?? '';

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ArticleCommentService.watchComments(article.id),
              builder: (context, snap) {
                final comments = snap.data ?? const <Map<String, dynamic>>[];
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: kArticlesGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                if (comments.isEmpty) {
                  return const ArticleDetailEmptyPanel(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucun commentaire pour le moment',
                    subtitle: 'Sois le premier à réagir à cet article.',
                  );
                }

                return Column(
                  children: comments.map((comment) {
                    final uid = (comment['uid'] as String? ?? '').trim();
                    final canDelete =
                        canModerate ||
                        (currentUid.isNotEmpty && uid == currentUid);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ArticleCommentTile(
                        articleId: article.id,
                        comment: comment,
                        canDelete: canDelete,
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ArticleCommentTile extends StatelessWidget {
  final String articleId;
  final Map<String, dynamic> comment;
  final bool canDelete;

  const _ArticleCommentTile({
    required this.articleId,
    required this.comment,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = comment['createdAt'];
    String dateLabel = 'À l’instant';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      dateLabel =
          '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kArticlesCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kArticlesBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (comment['displayName'] as String? ?? 'Supporter DVCR')
                          .trim(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kArticlesText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: kArticlesMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                GestureDetector(
                  onTap: () async {
                    await ArticleCommentService.deleteComment(
                      articleId: articleId,
                      commentId: (comment['id'] as String? ?? '').trim(),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commentaire supprimé.')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kArticlesIvory,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kArticlesBorder),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: kArticlesMuted,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (comment['message'] as String? ?? '').trim(),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kArticlesText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
