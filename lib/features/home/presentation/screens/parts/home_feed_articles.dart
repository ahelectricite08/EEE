part of '../home_screen.dart';

int _homeArticleCacheWidth(BuildContext context, double logicalPx) {
  return (logicalPx * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

class _ArticlesFeed extends StatelessWidget {
  final String category;
  const _ArticlesFeed({required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArticleModel>>(
      stream: const HomeArticlesFeedAdapter().watchPublished(
        category: category == 'TOUT' ? null : category,
        limit: 5,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Column(
            children: [
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
            ],
          );
        }
        final articles = snap.data!;
        if (articles.isEmpty) return const SizedBox();

        final marked = articles.where((a) => a.featured).toList();
        final featured =
            marked.isNotEmpty ? marked.first : articles.first;
        final rest =
            articles.where((a) => a.id != featured.id).toList();

        return Column(
          children: [
            _HomeFeaturedArticleCard(article: featured),
            ...rest.map(
              (article) => _HomeArticleRow(article: article),
            ),
          ],
        );
      },
    );
  }
}

class _HomeArticleCover extends StatelessWidget {
  final String? url;
  final int cacheWidth;
  final Widget? emptyChild;

  const _HomeArticleCover({
    required this.url,
    required this.cacheWidth,
    this.emptyChild,
  });

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) {
      return emptyChild ?? const ColoredBox(color: Color(0xFF151515));
    }
    return Image.network(
      src,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheWidth,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (_, __, ___) =>
          emptyChild ?? const ColoredBox(color: Color(0xFF151515)),
    );
  }
}

class _HomeFeaturedArticleCard extends StatelessWidget {
  final ArticleModel article;
  const _HomeFeaturedArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final minutes = article.estimatedReadingMinutes;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        decoration: HomeTheme.paper(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HomeArticleCover(
                    url: article.imageUrl,
                    cacheWidth: _homeArticleCacheWidth(
                      context,
                      MediaQuery.sizeOf(context).width - 40,
                    ),
                    emptyChild: ColoredBox(
                      color: HomeTheme.surfaceMuted,
                      child: Icon(
                        Icons.article_outlined,
                        color: _catColor(article.category).withAlpha(80),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: HomeTheme.greenDeep.withValues(alpha: 0.88),
                      child: Text(
                        'À LA UNE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (article.displayCategoryLabel.isNotEmpty)
                        article.displayCategoryLabel.toUpperCase(),
                      '$minutes min',
                      _relDate(article.date),
                    ].join('  ·  '),
                    style: HomeType.kicker,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: HomeType.headline,
                  ),
                  if (article.hasTeaser) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.teaser,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.caption,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Lire l’article',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: HomeTheme.greenDeep,
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
}

class _HomeArticleRow extends StatelessWidget {
  final ArticleModel article;
  const _HomeArticleRow({required this.article});

  static const _thumbW = 118.0;
  static const _thumbH = 108.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        decoration: HomeTheme.paper(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _thumbW,
              height: _thumbH,
              child: _HomeArticleCover(
                url: article.imageUrl,
                cacheWidth: _homeArticleCacheWidth(context, _thumbW),
                emptyChild: ColoredBox(
                  color: HomeTheme.surfaceMuted,
                  child: Icon(
                    Icons.article_outlined,
                    size: 22,
                    color: _catColor(article.category).withAlpha(80),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (article.displayCategoryLabel.isNotEmpty)
                          article.displayCategoryLabel.toUpperCase(),
                        _relDate(article.date),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.kicker,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.title.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
