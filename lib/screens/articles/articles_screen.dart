import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/main_shell_insets.dart';
import '../../services/dvcr_share_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/article_model.dart';
import '../../services/article_service.dart';
import '../../services/article_read_store.dart';
import '../../services/article_comment_service.dart';
import '../../services/favorites_service.dart';
import '../../services/user_service.dart';
import '../../services/app_settings_service.dart';
import '../../utils/share_helper.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/dvcr_reveal.dart';
import '../../widgets/donation_banner.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
class ArticlesScreen extends StatefulWidget {
  final bool guestMode;
  final VoidCallback? onRequestSignIn;

  const ArticlesScreen({
    super.key,
    this.guestMode = false,
    this.onRequestSignIn,
  });

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  int _catIndex = 0;
  String? _tagFilter;
  bool _isAdmin = false;
  bool _isStrictAdmin = false;
  int _readTick = 0;

  // Barre catégorie : se réduit au scroll bas, revient au scroll haut
  final _catBarHiddenNotifier = ValueNotifier<bool>(false);
  double _scrollAccum = 0;

  @override
  void initState() {
    super.initState();
    ArticleReadStore.ensureLoaded().then((_) {
      if (mounted) setState(() => _readTick++);
    });
    if (widget.guestMode) return;
    UserService.canEditArticles().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
    UserService.isAdmin().then((v) {
      if (mounted) setState(() => _isStrictAdmin = v);
    });
  }

  @override
  void dispose() {
    _catBarHiddenNotifier.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
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
      title: widget.guestMode
          ? ArticlesHeroGuestToolbar(
              onLogin: _openLogin,
              onCreateAccount: () => widget.onRequestSignIn?.call(),
            )
          : const ArticlesHeroPinnedToolbar(),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ArticlesHeroFlexibleSpace(
          title: 'DVCR ACTUS',
          guestSubtitle: widget.guestMode
              ? 'Lecture libre des actus — le reste de l’app demande un compte'
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_catIndex];
    final _ = _readTick;

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
              // Barre catégorie — glisse vers le bas
              ValueListenableBuilder<bool>(
                valueListenable: _catBarHiddenNotifier,
                builder: (context, hidden, child) => AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: ClipRect(
                    child: AnimatedSlide(
                      offset: hidden ? const Offset(0, 1) : Offset.zero,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: hidden ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: SizedBox(
                          height: hidden ? 0 : null,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                child: ArticleCategoryBar(
                  selectedIndex: _catIndex,
                  onChanged: (index) => setState(() {
                    _catIndex = index;
                    _tagFilter = null;
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notif) {
          if (notif is ScrollUpdateNotification) {
            final delta = notif.scrollDelta ?? 0;
            if (delta < 0) {
              _scrollAccum = 0;
              if (_catBarHiddenNotifier.value) _catBarHiddenNotifier.value = false;
            } else {
              _scrollAccum += delta;
              if (_scrollAccum > 60 && !_catBarHiddenNotifier.value) {
                _catBarHiddenNotifier.value = true;
              }
            }
          } else if (notif is ScrollEndNotification) {
            _scrollAccum = 0;
          }
          return false;
        },
        child: StreamBuilder<List<ArticleModel>>(
        stream: ArticleService.all(
          category: cat == 'TOUT' ? null : cat,
          limit: 40,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildArticlesHeroSliver(context),
                const SliverToBoxAdapter(child: ArticlesErrorState()),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MainShellInsets.tabScrollTail(context, extra: 8),
                  ),
                ),
              ],
            );
          }
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
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MainShellInsets.tabScrollTail(context, extra: 8),
                  ),
                ),
              ],
            );
          }

          final all = snap.data!;
          final tags = <String>{};
          for (final a in all) {
            tags.addAll(a.tags);
          }
          final tagList = tags.toList()..sort();
          final articles = _tagFilter == null
              ? all
              : all.where((a) => a.tags.contains(_tagFilter)).toList();
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
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MainShellInsets.tabScrollTail(context, extra: 8),
                  ),
                ),
              ],
            );
          }

          final featured = articles.firstWhere(
            (a) => a.featured,
            orElse: () => articles.first,
          );
          final rest = articles.where((a) => a.id != featured.id).toList();
          final wide = MediaQuery.sizeOf(context).width >= 720;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildArticlesHeroSliver(context),
              if (tagList.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: ArticleTagFilterBar(
                      tags: tagList,
                      selected: _tagFilter,
                      onChanged: (t) => setState(() => _tagFilter = t),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: DVCRReveal(
                  duration: const Duration(milliseconds: 480),
                  offsetY: 22,
                  child: _isAdmin
                      ? GestureDetector(
                          onLongPress: () =>
                              _showMenu(context, featured, _isStrictAdmin),
                          child: ArticlesFeaturedCard(
                            article: featured,
                            unread: !ArticleReadStore.isOpened(featured.id),
                            onTap: () => _openDetail(context, featured),
                          ),
                        )
                      : ArticlesFeaturedCard(
                          article: featured,
                          unread: !ArticleReadStore.isOpened(featured.id),
                          onTap: () => _openDetail(context, featured),
                        ),
                ),
              ),
              if (rest.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 1,
                          color: kArticlesGreen,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cat == 'TOUT' ? 'À lire aussi' : cat,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kArticlesText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (wide)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final article = rest[i];
                      final card = ArticleCompactCard(
                        article: article,
                        grid: true,
                        unread: !ArticleReadStore.isOpened(article.id),
                        onTap: () => _openDetail(context, article),
                      );
                      return _isAdmin
                          ? GestureDetector(
                              onLongPress: () => _showMenu(
                                context,
                                article,
                                _isStrictAdmin,
                              ),
                              child: card,
                            )
                          : card;
                    }, childCount: rest.length),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final article = rest[i];
                    final card = ArticleCompactCard(
                      article: article,
                      isLast: i == rest.length - 1,
                      unread: !ArticleReadStore.isOpened(article.id),
                      onTap: () => _openDetail(context, article),
                    );
                    return _isAdmin
                        ? GestureDetector(
                            onLongPress: () =>
                                _showMenu(context, article, _isStrictAdmin),
                            child: card,
                          )
                        : card;
                  }, childCount: rest.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: const DonationBanner(
                  slot: SoutenezDvcrBannerSlot.articles,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MainShellInsets.tabScrollTail(context, extra: 8),
                ),
              ),
            ],
          );
        },
      ),
    ), // NotificationListener
    );
  }

  void _showMenu(BuildContext context, ArticleModel article, bool canDelete) {
    showModalBottomSheet(
      useRootNavigator: true,
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
  Future<void> _openDetail(BuildContext context, ArticleModel article) async {
    await ArticleReadStore.markOpened(article.id);
    if (mounted) setState(() => _readTick++);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          article: article,
          guestMode: widget.guestMode,
          onRequestSignIn: widget.onRequestSignIn,
        ),
      ),
    );
    if (mounted) setState(() => _readTick++);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE DÉTAIL ARTICLE
// ─────────────────────────────────────────────────────────────────────────────
class ArticleDetailScreen extends StatefulWidget {
  final ArticleModel article;
  final bool guestMode;
  final VoidCallback? onRequestSignIn;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.guestMode = false,
    this.onRequestSignIn,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  double _fontSize = 17.0;
  static const _kFontSizeKey = 'article_font_size';
  static const _kFontMin = 12.0;
  static const _kFontMax = 22.0;

  WebViewController? _wixWebController;
  String? _wixLoadedUrl;

  /// Titre dans la barre lorsque l’utilisateur a défilé — ValueNotifier, pas de setState.
  final ScrollController _articleScrollController = ScrollController();
  final ValueNotifier<bool> _showCollapsedArticleTitle = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<double> _readProgress = ValueNotifier<double>(0);
  DateTime? _lastProgressPersist;
  static const _kShowTitleScrollOn = 96.0;
  static const _kShowTitleScrollOff = 56.0;

  @override
  void initState() {
    super.initState();
    ArticleReadStore.markOpened(widget.article.id);
    unawaited(_bumpView());
    _loadFontSize();
    _articleScrollController.addListener(_onArticleDetailScroll);
  }

  Future<void> _bumpView() async {
    try {
      await ArticleService.incrementView(widget.article.id);
    } catch (_) {}
  }

  void _onArticleDetailScroll() {
    if (!_articleScrollController.hasClients || !mounted) return;
    final o = _articleScrollController.offset;
    var next = _showCollapsedArticleTitle.value;
    if (o >= _kShowTitleScrollOn) {
      next = true;
    } else if (o <= _kShowTitleScrollOff) {
      next = false;
    }
    if (next != _showCollapsedArticleTitle.value) {
      _showCollapsedArticleTitle.value = next;
    }

    final max = _articleScrollController.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (o / max).clamp(0.0, 1.0);
    if ((p - _readProgress.value).abs() <= 0.008) return;
    _readProgress.value = p;

    final now = DateTime.now();
    if (_lastProgressPersist != null &&
        now.difference(_lastProgressPersist!) < const Duration(milliseconds: 450)) {
      return;
    }
    _lastProgressPersist = now;
    unawaited(ArticleReadStore.saveProgress(widget.article.id, p));
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
      useRootNavigator: true,
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
                style: GoogleFonts.inter(
                  fontSize: _fontSize,
                  color: kArticlesText,
                  height: 1.5,
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
    unawaited(
      ArticleReadStore.saveProgress(widget.article.id, _readProgress.value),
    );
    _showCollapsedArticleTitle.dispose();
    _readProgress.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _openRelatedArticle(BuildContext context, ArticleModel article) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          article: article,
          guestMode: widget.guestMode,
          onRequestSignIn: widget.onRequestSignIn,
        ),
      ),
    );
  }

  void _promptGuestSignIn() {
    showGuestAuthOptionsSheet(
      context,
      onCreateAccount: () => widget.onRequestSignIn?.call(),
      onLogin: () =>
          Navigator.of(context, rootNavigator: true).pushNamed('/login'),
    );
  }

  void _ensureWixWebView(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return;
    if (!ArticleModel.isWixArticlePageUrl(u)) return;
    if (_wixLoadedUrl == u && _wixWebController != null) return;
    _wixLoadedUrl = u;
    _wixWebController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kArticlesIvory)
      ..loadRequest(Uri.parse(u));
    if (!kIsWeb) {
      _wixWebController!.enableZoom(false);
    }
  }

  Map<String, Style> _wixArticleHtmlStyles(double fontSize) {
    return {
      'html': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        backgroundColor: Colors.transparent,
      ),
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(fontSize),
        fontFamily: GoogleFonts.inter().fontFamily,
        color: kArticlesText,
        lineHeight: const LineHeight(1.5),
        backgroundColor: Colors.transparent,
      ),
      'article': Style(backgroundColor: Colors.transparent),
      'div': Style(backgroundColor: Colors.transparent),
      'section': Style(backgroundColor: Colors.transparent),
      'main': Style(backgroundColor: Colors.transparent),
      'header': Style(backgroundColor: Colors.transparent),
      'footer': Style(backgroundColor: Colors.transparent),
      'aside': Style(backgroundColor: Colors.transparent),
      'figure': Style(
        margin: Margins.only(bottom: 16),
        backgroundColor: Colors.transparent,
      ),
      'p': Style(
        margin: Margins.only(bottom: 16),
        backgroundColor: Colors.transparent,
      ),
      'h1': Style(
        fontSize: FontSize(fontSize + 8),
        fontWeight: FontWeight.w800,
        margin: Margins.only(bottom: 12, top: 8),
        fontFamily: GoogleFonts.barlowCondensed().fontFamily,
        color: kArticlesText,
      ),
      'h2': Style(
        fontSize: FontSize(fontSize + 5),
        fontWeight: FontWeight.w800,
        margin: Margins.only(bottom: 10, top: 8),
        fontFamily: GoogleFonts.barlowCondensed().fontFamily,
        color: kArticlesText,
      ),
      'h3': Style(
        fontSize: FontSize(fontSize + 3),
        fontWeight: FontWeight.w700,
        margin: Margins.only(bottom: 8, top: 6),
        fontFamily: GoogleFonts.barlowCondensed().fontFamily,
        color: kArticlesText,
      ),
      'strong,b': Style(fontWeight: FontWeight.w700),
      'a': Style(
        color: kArticlesGreenDeep,
        textDecoration: TextDecoration.underline,
      ),
      'ul,ol': Style(margin: Margins.only(bottom: 14)),
      'li': Style(margin: Margins.only(bottom: 6)),
      'blockquote': Style(
        border: const Border(
          left: BorderSide(color: kArticlesGreenDeep, width: 2),
        ),
        padding: HtmlPaddings.only(left: 12),
        margin: Margins.only(bottom: 16),
        fontStyle: FontStyle.italic,
        color: kArticlesMuted,
      ),
      'img': Style(
        width: Width.auto(),
        height: Height.auto(),
        display: Display.block,
        margin: Margins.only(bottom: 16),
      ),
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
            style: GoogleFonts.inter(
              fontSize: _fontSize,
              color: kArticlesText,
              height: 1.5,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 18));
      }

      final rawUrl = (match.group(1) ?? match.group(2) ?? '').trim();
      final imageUrl = rawUrl.startsWith(r'\') ? rawUrl.substring(1) : rawUrl;
      if (imageUrl.isNotEmpty) {
        widgets.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ColoredBox(
                color: kArticlesIvory,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  cacheWidth: articleImageCacheWidth(
                    context,
                    MediaQuery.sizeOf(context).width.clamp(0, 680),
                  ),
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
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
          style: GoogleFonts.inter(
            fontSize: _fontSize,
            color: kArticlesText,
            height: 1.5,
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
            : (user.email?.split('@').first ?? UserRole.teamDvcr.displayName),
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

  void _shareArticle(ArticleModel article) {
    DvcrShare.share(ShareHelper.articleText(article), context: context);
  }

  Future<void> _openWixSite(String url) async {
    final u = Uri.tryParse(url);
    if (u != null && await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Widget _readingShell({required Widget child}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: child,
      ),
    );
  }

  Widget _favoriteChip(ArticleModel article, Color color) {
    return StreamBuilder<bool>(
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
            borderRadius: BorderRadius.circular(2),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kArticlesCard,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: kArticlesBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFavorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isFavorite ? color : kArticlesGreenDeep,
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
    );
  }

  Widget _relatedArticles(ArticleModel article) {
    return StreamBuilder<List<ArticleModel>>(
      stream: ArticleService.all(limit: 20),
      builder: (context, relatedSnap) {
        final allArticles = (relatedSnap.data ?? const <ArticleModel>[])
            .where((item) => item.id != article.id)
            .toList();
        final sameTags = allArticles.where((item) {
          if (article.tags.isEmpty) return false;
          return item.tags.any(article.tags.contains);
        }).toList();
        final sameCategory = allArticles
            .where((item) => item.category == article.category)
            .toList();
        final newest = [...allArticles]..sort((a, b) => b.date.compareTo(a.date));

        final related = <ArticleModel>[];
        for (final bucket in [sameTags, sameCategory, newest]) {
          for (final item in bucket) {
            if (!related.any((existing) => existing.id == item.id)) {
              related.add(item);
            }
            if (related.length == 3) break;
          }
          if (related.length == 3) break;
        }

        if (related.isEmpty) {
          return Text(
            'D\'autres articles arrivent bientôt.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kArticlesMuted,
            ),
          );
        }

        return Column(
          children: related.asMap().entries.map((entry) {
            final index = entry.key;
            final relatedArticle = entry.value;
            return ArticleCompactCard(
              article: relatedArticle,
              padded: false,
              isLast: index == related.length - 1,
              unread: !ArticleReadStore.isOpened(relatedArticle.id),
              onTap: () => _openRelatedArticle(context, relatedArticle),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _backButton(BuildContext context) {
    return Padding(
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
    );
  }

  /// Fallback Wix sans HTML : WebView hors sliver (plus de guerre de gestures).
  Widget _buildWixWebFallbackScaffold(ArticleModel article) {
    final top = MediaQuery.paddingOf(context).top;
    const coverBody = 188.0;
    return Scaffold(
      backgroundColor: kArticlesSheet,
      body: Column(
        children: [
          SizedBox(
            height: top + coverBody,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF151515)),
                if ((article.imageUrl ?? '').isNotEmpty)
                  Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.18),
                    cacheWidth: articleImageCacheWidth(
                      context,
                      MediaQuery.sizeOf(context).width,
                    ),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF151515)),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x88000000),
                        Color(0x14000000),
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
                Positioned(left: 0, top: top, child: _backButton(context)),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 4,
            child: ColoredBox(color: kArticlesProgress),
          ),
          Expanded(
            child: _wixWebController == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: kArticlesGreen,
                      strokeWidth: 2,
                    ),
                  )
                : WebViewWidget(controller: _wixWebController!),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ArticleDetailShareBar(
                onShare: () => _shareArticle(article),
                onOpenSite: article.hasOpenableWixArticleUrl
                    ? () => _openWixSite(article.wixUrl!)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<ArticleModel?>(
      stream: ArticleService.streamById(widget.article.id),
      builder: (context, snap) {
        final article = snap.data ?? widget.article;
        final color = articleCategoryColor(article.category);
        final liked =
            currentUid.isNotEmpty && article.likedBy.contains(currentUid);

        final useWixWeb = article.hasOpenableWixArticleUrl &&
            !article.hasDisplayableContentHtml &&
            !article.hasDisplayablePlainContent;
        if (useWixWeb) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final before = _wixWebController;
            _ensureWixWebView(article.wixUrl);
            if (before != _wixWebController) setState(() {});
          });
          return _buildWixWebFallbackScaffold(article);
        }

        final coverH =
            (MediaQuery.sizeOf(context).width * 0.78).clamp(280.0, 360.0);
        final progressTop =
            MediaQuery.paddingOf(context).top + kToolbarHeight;

        return Scaffold(
          backgroundColor: kArticlesSheet,
          body: Stack(
            children: [
              CustomScrollView(
                controller: _articleScrollController,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: coverH,
                    toolbarHeight: kToolbarHeight,
                    pinned: true,
                    stretch: false,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    centerTitle: false,
                    titleSpacing: 0,
                    title: ValueListenableBuilder<bool>(
                      valueListenable: _showCollapsedArticleTitle,
                      builder: (context, show, child) {
                        return AnimatedOpacity(
                          opacity: show ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: child,
                        );
                      },
                      child: Padding(
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
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    leading: _backButton(context),
                    flexibleSpace: _ArticleCoverFlexibleSpace(
                      imageUrl: article.imageUrl,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _readingShell(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        child: ArticleDetailMetaCard(
                          article: article,
                          categoryColor: color,
                          liked: liked,
                          readingMinutes: article.estimatedReadingMinutes,
                          onReadingOptions: () => _showReadingOptions(context),
                          onLike: widget.guestMode
                              ? _promptGuestSignIn
                              : () => ArticleService.toggleLike(article.id),
                          favoriteButton: widget.guestMode
                              ? const SizedBox.shrink()
                              : _favoriteChip(article, color),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _readingShell(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          22,
                          20,
                          28 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((article.videoUrl ?? '').isNotEmpty)
                              ArticleVideoLink(
                                url: article.videoUrl!,
                                onOpen: (url) async {
                                  final u = Uri.tryParse(url);
                                  if (u != null && await canLaunchUrl(u)) {
                                    await launchUrl(
                                      u,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                            if (article.hasDisplayableContentHtml &&
                                article.contentHtml != null)
                              ArticleContentCard(
                                children: [
                                  RepaintBoundary(
                                    child: Html(
                                      data: wixArticleHtmlForDisplay(
                                        article.contentHtml!,
                                      ),
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
                                  ),
                                ],
                              )
                            else
                              ArticleContentCard(
                                children: _buildContent(article.content),
                              ),
                            if (article.galleryImages.isNotEmpty)
                              ArticleGalleryStrip(urls: article.galleryImages),
                            const SizedBox(height: 28),
                            ArticleDetailShareBar(
                              onShare: () => _shareArticle(article),
                              onOpenSite: article.hasOpenableWixArticleUrl
                                  ? () => _openWixSite(article.wixUrl!)
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            const ArticleDetailSectionTitle(
                              title: 'À lire aussi',
                            ),
                            const SizedBox(height: 14),
                            _relatedArticles(article),
                            const SizedBox(height: 32),
                            _ArticleCommentsSection(
                              article: article,
                              commentCtrl: _commentCtrl,
                              sending: _sendingComment,
                              onSubmit: () => _submitComment(article),
                              guestMode: widget.guestMode,
                              onRequestSignIn: widget.onRequestSignIn,
                              onGuestAuthOptions: widget.guestMode
                                  ? _promptGuestSignIn
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: progressTop,
                left: 0,
                right: 0,
                child: ArticleReadingProgressBar(progress: _readProgress),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cover de fiche : la photo reste au repli, pas d’aplat vert.
class _ArticleCoverFlexibleSpace extends StatelessWidget {
  final String? imageUrl;

  const _ArticleCoverFlexibleSpace({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final maxExtent = settings?.maxExtent ?? constraints.maxHeight;
        final minExtent = settings?.minExtent ?? constraints.maxHeight;
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final delta = maxExtent - minExtent;
        final t = delta <= 0
            ? 0.0
            : (1 - (current - minExtent) / delta).clamp(0.0, 1.0);
        final alignment = Alignment.lerp(
          const Alignment(0, -0.18),
          const Alignment(0, -1),
          t,
        )!;
        final veil = 0.22 + 0.42 * t;

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF151515)),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                alignment: alignment,
                gaplessPlayback: true,
                cacheWidth: articleImageCacheWidth(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF151515),
                ),
              )
            else
              const ColoredBox(color: Color(0xFF151515)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: veil),
                    Colors.black.withValues(alpha: 0.08 + 0.35 * t),
                    Colors.black.withValues(alpha: 0.55 + 0.25 * t),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
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
  final bool guestMode;
  final VoidCallback? onRequestSignIn;
  final VoidCallback? onGuestAuthOptions;

  const _ArticleCommentsSection({
    required this.article,
    required this.commentCtrl,
    required this.sending,
    required this.onSubmit,
    this.guestMode = false,
    this.onRequestSignIn,
    this.onGuestAuthOptions,
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
            title: guestMode
                ? 'Compte requis pour commenter'
                : 'Connecte-toi pour commenter',
            subtitle: guestMode
                ? 'Crée un compte ou connecte-toi pour participer aux discussions.'
                : 'Les membres DVCR peuvent réagir et participer sous les articles.',
            actionLabel: guestMode ? 'COMPTE / CONNEXION' : 'SE CONNECTER',
            onAction: () {
              if (guestMode) {
                if (onGuestAuthOptions != null) {
                  onGuestAuthOptions!();
                } else {
                  onRequestSignIn?.call();
                }
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
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
                      (comment['displayName'] as String?
                          ?? UserRole.teamDvcr.displayName)
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

