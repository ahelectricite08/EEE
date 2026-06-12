import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/article_model.dart';
import '../home/home_shell_widgets.dart';
import '../social/social_links_screen.dart';

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
      errorBuilder: (_, __, ___) => Container(
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
/// Popup après quelques secondes sur les actus en mode invité.
Future<void> showGuestSignupPromptDialog(
  BuildContext context, {
  required VoidCallback onRegister,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: kArticlesCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Inscris-toi à l’application DVCR !',
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: kArticlesGreenDeep,
          height: 1.05,
        ),
      ),
      content: Text(
        'Rejoins la communauté : commentaires, live, matchs et tout le contenu.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: kArticlesMuted,
          height: 1.4,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRegister();
              },
              style: FilledButton.styleFrom(
                backgroundColor: kArticlesGold,
                foregroundColor: kArticlesGreenDeep,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                'INSCRIPTION',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Plus tard',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kArticlesMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Barre d’actions compte en mode invité (actu sans connexion).
void showGuestAuthOptionsSheet(
  BuildContext context, {
  required VoidCallback onCreateAccount,
  required VoidCallback onLogin,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kArticlesCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kArticlesBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rejoins la communauté DVCR',
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kArticlesText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crée un compte ou connecte-toi pour commenter '
              'et accéder à tout le contenu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kArticlesMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onCreateAccount();
              },
              style: FilledButton.styleFrom(
                backgroundColor: kArticlesGold,
                foregroundColor: kArticlesGreenDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'CRÉER UN COMPTE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onLogin();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kArticlesGreenDeep,
                side: const BorderSide(color: kArticlesBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'SE CONNECTER',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Barre hero mode invité — même esprit que l’accueil : globe + compte.
class ArticlesHeroGuestToolbar extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;

  const ArticlesHeroGuestToolbar({
    super.key,
    required this.onLogin,
    required this.onCreateAccount,
  });

  void _openAccount(BuildContext context) {
    showGuestAuthOptionsSheet(
      context,
      onLogin: onLogin,
      onCreateAccount: onCreateAccount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          HomeToolbarButton(
            icon: Icons.public_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SocialLinksScreen()),
            ),
          ),
          const Spacer(),
          HomeToolbarButton(
            icon: Icons.person_outline_rounded,
            iconColor: kArticlesGold,
            onTap: () => _openAccount(context),
          ),
        ],
      ),
    );
  }
}

class ArticlesHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String? guestSubtitle;

  const ArticlesHeroFlexibleSpace({
    super.key,
    required this.title,
    this.guestSubtitle,
  });

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
                      guestSubtitle ??
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
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: articleCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? kArticlesGreenDeep : kArticlesCard,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? kArticlesGreenDeep : kArticlesBorder,
                ),
              ),
              child: Text(
                articleCategories[index],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kArticlesText,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: kArticlesCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kArticlesBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ───────────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: article.imageUrl != null &&
                              article.imageUrl!.isNotEmpty
                          ? Image.network(
                              article.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: kArticlesGreenDeep),
                            )
                          : Container(color: kArticlesGreenDeep),
                    ),
                    // Badge catégorie + À LA UNE
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          if (article.displayCategoryLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                article.displayCategoryLabel.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kArticlesGold,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'À LA UNE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Texte ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: kArticlesText,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: kArticlesMuted),
                        const SizedBox(width: 4),
                        Text(
                          articleRelDate(article.date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: kArticlesMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TinyStat(
                          icon: Icons.remove_red_eye_outlined,
                          label: '${article.viewsCount}',
                        ),
                        const SizedBox(width: 8),
                        _TinyStat(
                          icon: Icons.favorite_border_rounded,
                          label: '${article.likesCount}',
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: kArticlesGreenDeep,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lire →',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
      padding: EdgeInsets.fromLTRB(14, 0, 14, isLast ? 0 : 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kArticlesCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kArticlesBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenu texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge catégorie
                    if (article.displayCategoryLabel.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(22),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: color.withAlpha(60)),
                        ),
                        child: Text(
                          article.displayCategoryLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    // Titre
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kArticlesText,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Meta
                    Row(
                      children: [
                        Text(
                          articleRelDate(article.date),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: kArticlesMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TinyStat(
                          icon: Icons.remove_red_eye_outlined,
                          label: '${article.viewsCount}',
                        ),
                        const SizedBox(width: 6),
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
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: article.imageUrl != null &&
                          article.imageUrl!.isNotEmpty
                      ? Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: kArticlesIvory),
                        )
                      : Container(
                          color: kArticlesIvory,
                          child: Icon(Icons.article_outlined,
                              color: color, size: 24),
                        ),
                ),
              ),
            ],
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
