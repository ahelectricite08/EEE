import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/article_model.dart';

const kArticlesGreen = Color(0xFF0A4438);
const kArticlesGreenDeep = Color(0xFF062921);
const kArticlesIvory = Color(0xFFF5F2E9);
const kArticlesSheet = Color(0xFFFAF8F7);
const kArticlesGold = Color(0xFFC8A436);
const kArticlesCard = Color(0xFFFFFFFF);
const kArticlesText = Color(0xFF173C31);
const kArticlesMuted = Color(0xFF6E776F);
const kArticlesBorder = Color(0xFFD8D2C4);
const kArticlesRed = Color(0xFFBA203C);

const articleCategories = [
  'TOUT',
  'RÉSULTATS',
  'AVANT-MATCH',
  'CHRONIQUES SEDANAISES',
  'ANALYSE',
  'COULISSES',
  'CLUB',
];

Color articleCategoryColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':
      return const Color(0xFF2F8F6B);
    case 'AVANT-MATCH':
      return const Color(0xFFB87333);
    case 'CHRONIQUES SEDANAISES':
      return const Color(0xFF2B6CB0);
    case 'ANALYSE':
      return const Color(0xFF7A5AF8);
    case 'COULISSES':
      return const Color(0xFF9A6B39);
    case 'CLUB':
      return kArticlesRed;
    case ArticleModel.kUncategorizedToutOnly:
      return kArticlesMuted;
    default:
      return kArticlesMuted;
  }
}

String articleRelDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  const months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

const _kArticlesHeroImageUrl =
    'https://static.wixstatic.com/media/e91e00_2566f43876394b5c875cb0cfde1de9c2~mv2.jpg';

class _ArticlesHeroNetworkImage extends StatelessWidget {
  const _ArticlesHeroNetworkImage();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _kArticlesHeroImageUrl,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.32),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF151515),
        alignment: Alignment.center,
        child: Icon(
          Icons.article_outlined,
          size: 48,
          color: Colors.white.withAlpha(55),
        ),
      ),
    );
  }
}

/// Barre fixe (comme DVCR TV) : rédaction à gauche, lien site dvcr.fr à droite.
class ArticlesHeroPinnedToolbar extends StatelessWidget {
  const ArticlesHeroPinnedToolbar({super.key});

  static final _siteUri = Uri.parse('https://dvcr.fr');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kArticlesGold.withAlpha(38),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(85)),
            ),
            child: Text(
              'RÉDACTION DVCR',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.55,
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => launchUrl(
                _siteUri,
                mode: LaunchMode.externalApplication,
              ),
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DVCR.FR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fond hero Sliver : double image + parallax (même idée que l’accueil / DVCR TV).
class ArticlesHeroFlexibleSpace extends StatelessWidget {
  final String title;

  const ArticlesHeroFlexibleSpace({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: _ArticlesHeroNetworkImage()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(125),
                  Colors.black.withAlpha(50),
                ],
                stops: const [0.0, 0.48],
              ),
            ),
          ),
        ),
        FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _ArticlesHeroNetworkImage()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(230),
                        kArticlesGreen.withAlpha(110),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.36, 0.78],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.45,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Articles, décryptages et coulisses du club.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(230),
                        height: 1.25,
                      ),
                    ),
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

/// Hero statique (hors Sliver).
class ArticlesTopHero extends StatelessWidget {
  final String title;

  const ArticlesTopHero({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: SizedBox(
        height: 198 + topPad,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _ArticlesHeroNetworkImage()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(95),
                      Colors.black.withAlpha(50),
                      kArticlesGreen.withAlpha(200),
                      kArticlesGreenDeep,
                    ],
                    stops: const [0.0, 0.32, 0.72, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ArticlesHeroPinnedToolbar(),
                    const Spacer(),
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.45,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Articles, décryptages et coulisses du club.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(230),
                        height: 1.25,
                      ),
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

class ArticleCategoryBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const ArticleCategoryBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Material(
        color: kArticlesIvory,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: kArticlesGold.withAlpha(85)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            itemCount: articleCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final selected = selectedIndex == index;
              return Material(
                color: selected ? kArticlesGreenDeep : kArticlesCard,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected ? kArticlesGold : kArticlesBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                elevation: selected ? 2 : 0,
                shadowColor: selected
                    ? kArticlesGold.withAlpha(80)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(index),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Center(
                      child: Text(
                        articleCategories[index],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : kArticlesText,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ArticlesFeaturedCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;

  const ArticlesFeaturedCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = articleCategoryColor(article.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: kArticlesCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kArticlesGold.withAlpha(70)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 216,
                        width: double.infinity,
                        child:
                            article.imageUrl != null &&
                                article.imageUrl!.isNotEmpty
                            ? Image.network(
                                article.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: kArticlesGreenDeep),
                              )
                            : Container(color: kArticlesGreenDeep),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withAlpha(30),
                                Colors.black.withAlpha(140),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (article.displayCategoryLabel.isNotEmpty)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              article.displayCategoryLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'À LA UNE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: kArticlesGold,
                                letterSpacing: 0.65,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          articleRelDate(article.date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kArticlesMuted,
                          ),
                        ),
                      ),
                      _StatsPill(
                        icon: Icons.remove_red_eye_outlined,
                        label: '${article.viewsCount}',
                      ),
                      const SizedBox(width: 8),
                      _StatsPill(
                        icon: Icons.favorite_border_rounded,
                        label: '${article.likesCount}',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: 176,
                    child: _PrimaryArticleButton(
                      label: 'Lire l\'article',
                      onTap: onTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArticleCompactCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;
  final bool isLast;

  const ArticleCompactCard({
    super.key,
    required this.article,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = articleCategoryColor(article.category);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, isLast ? 0 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kArticlesCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kArticlesBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 78,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (article.displayCategoryLabel.isNotEmpty) ...[
                        Text(
                          article.displayCategoryLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kArticlesText,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            articleRelDate(article.date),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kArticlesMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _TinyStat(
                            icon: Icons.remove_red_eye_outlined,
                            label: '${article.viewsCount}',
                          ),
                          const SizedBox(width: 8),
                          _TinyStat(
                            icon: Icons.favorite_border_rounded,
                            label: '${article.likesCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child:
                        article.imageUrl != null && article.imageUrl!.isNotEmpty
                        ? Image.network(
                            article.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: kArticlesIvory),
                          )
                        : Container(
                            color: kArticlesIvory,
                            child: Icon(Icons.article_outlined, color: color),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArticlesEmptyState extends StatelessWidget {
  const ArticlesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kArticlesCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kArticlesGold.withAlpha(55)),
        ),
        child: Column(
          children: [
            const Icon(Icons.article_outlined, color: kArticlesGreen, size: 36),
            const SizedBox(height: 12),
            Text(
              'Aucune actu pour le moment',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kArticlesText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les prochains articles DVCR apparaîtront ici dès leur publication.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kArticlesMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryArticleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryArticleButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: kArticlesGold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kArticlesGold.withAlpha(70),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatsPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kArticlesIvory,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kArticlesMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kArticlesText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: kArticlesMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kArticlesMuted,
          ),
        ),
      ],
    );
  }
}
