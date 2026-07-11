part of 'home_screen.dart';

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
        if (!snap.hasData) {
          return Column(
            children: const [
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
              DVCRArticleRowSkeleton(),
            ],
          );
        }
        final articles = snap.data!;
        if (articles.isEmpty) return const SizedBox();

        return Column(
          children: articles.asMap().entries.map((e) {
            final article = e.value;
            final color = _catColor(article.category);

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArticleDetailScreen(article: article),
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
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
                              if (article.displayCategoryLabel.isNotEmpty) ...[
                                Text(
                                  article.displayCategoryLabel.toUpperCase(),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '  ·  ',
                                  style: GoogleFonts.barlow(
                                    fontSize: 11,
                                    color: _kGrey,
                                  ),
                                ),
                              ],
                              Text(
                                _relDate(article.date),
                                style: GoogleFonts.barlow(
                                  fontSize: 11,
                                  color: _kGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _kText,
                              height: 1.08,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 86,
                      height: 62,
                      decoration: BoxDecoration(
                        color: homeSurfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: article.imageUrl != null
                          ? Image.network(
                              article.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.article_outlined,
                                size: 20,
                                color: color.withAlpha(80),
                              ),
                            )
                          : Icon(
                              Icons.article_outlined,
                              size: 20,
                              color: color.withAlpha(80),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}


