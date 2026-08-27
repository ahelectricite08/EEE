import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/article_model.dart';
import '../../services/app_settings_service.dart';
import '../../utils/remote_image_url.dart';
import '../../widgets/hub_hero_photo.dart';
import '../home/home_shell_widgets.dart';
import '../social/social_links_screen.dart';

/// Décodage Wix à la taille écran, pas en pleine résolution (liste / une).
int articleImageCacheWidth(BuildContext context, double logicalPx) {
  return (logicalPx * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

const kArticlesGreen = Color(0xFF0A4438);
const kArticlesGreenBright = Color(0xFF167A5F);
const kArticlesGreenDeep = Color(0xFF062921);
/// Filet de lecture — vert club lisible sur ivoire et sur photo hero.
const kArticlesProgress = Color(0xFF0B3D2E);
const kArticlesIvory = Color(0xFFF4F0E6);
const kArticlesSheet = Color(0xFFF4F0E6);
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
    return HubHeroPhoto(
      slot: HubHeroSlot.articles,
      alignment: const Alignment(0, -0.15),
      fallbackNetworkUrl: _kArticlesHeroImageUrl,
      cacheWidth: articleImageCacheWidth(
        context,
        MediaQuery.sizeOf(context).width,
      ),
      filterQuality: FilterQuality.low,
      fallback: Container(
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
          Row(
            children: [
              Container(width: 3, height: 16, color: kArticlesGreenBright),
              const SizedBox(width: 8),
              Text(
                'DVCR ACTUS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: Colors.white,
                ),
              ),
            ],
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
    useRootNavigator: true,
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
  final double lockupBottom;

  const ArticlesHeroFlexibleSpace({
    super.key,
    required this.title,
    this.guestSubtitle,
    this.lockupBottom = 20,
  });

  @override
  Widget build(BuildContext context) {
    // Pas de FlexibleSpaceBar : il tue l’opacité au repli (aplat vert).
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
          const Alignment(0, -0.15),
          const Alignment(0, -1),
          t,
        )!;
        final veilTop = 0.30 + 0.34 * t;
        final veilMid = 0.06 + 0.46 * t;
        final veilLow = 0.72 + 0.16 * t;
        const veilBottom = 0.92;
        final lockupOpacity = (1 - t * 1.7).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF151515))),
            Positioned.fill(
              child: HubHeroPhoto(
                slot: HubHeroSlot.articles,
                alignment: alignment,
                fallbackNetworkUrl: _kArticlesHeroImageUrl,
                cacheWidth: articleImageCacheWidth(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                filterQuality: FilterQuality.low,
                fallback: Container(
                  color: const Color(0xFF151515),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.article_outlined,
                    size: 48,
                    color: Colors.white.withAlpha(55),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: veilTop),
                      Colors.black.withValues(alpha: veilMid),
                      Colors.black.withValues(alpha: veilLow),
                      Colors.black.withValues(alpha: veilBottom),
                    ],
                    stops: const [0.0, 0.34, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            if (lockupOpacity > 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: lockupBottom,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 3,
                        color: kArticlesGreenBright,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 0.9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guestSubtitle ??
                            'La rédaction — matchs, coulisses, club.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Hero Actus — même bande photo que TV / Pronos / Calendrier (168 + filet 3 px).
abstract final class ArticlesHeroSliver {
  static const double expandedBody = 168;
  static const double accentStripeHeight = 3;
  static const double toolbarHeight = 48;

  static SliverAppBar build(
    BuildContext context, {
    required bool guestMode,
    VoidCallback? onLogin,
    VoidCallback? onCreateAccount,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight:
          topPad + toolbarHeight + expandedBody + accentStripeHeight,
      stretch: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      title: guestMode
          ? ArticlesHeroGuestToolbar(
              onLogin: onLogin ?? () {},
              onCreateAccount: onCreateAccount ?? () {},
            )
          : const ArticlesHeroPinnedToolbar(),
      clipBehavior: Clip.hardEdge,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          ArticlesHeroFlexibleSpace(
            title: 'DVCR ACTUS',
            guestSubtitle: guestMode
                ? 'Lecture libre des actus — le reste de l’app demande un compte'
                : null,
            lockupBottom: 20,
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: accentStripeHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: kArticlesGreenBright),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero statique (hors Sliver) — même bande 168 + filet que [ArticlesHeroSliver].
class ArticlesTopHero extends StatelessWidget {
  final String title;

  const ArticlesTopHero({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: topPad +
          ArticlesHeroSliver.toolbarHeight +
          ArticlesHeroSliver.expandedBody +
          ArticlesHeroSliver.accentStripeHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF151515))),
          const Positioned.fill(child: _ArticlesHeroNetworkImage()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.34, 0.78, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ArticlesHeroPinnedToolbar(),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 3,
                    color: kArticlesGreenBright,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Articles, décryptages et coulisses du club.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: ArticlesHeroSliver.accentStripeHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: kArticlesGreenBright),
            ),
          ),
        ],
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

/// Cover liste / une : pas de `height: infinity` (casse [IntrinsicHeight]
/// et tout parent qui mesure l’intrinsic height dans un [SliverList]).
class _ArticleNetworkCover extends StatelessWidget {
  final String? url;
  final Color fallbackColor;
  final int cacheWidth;
  final FilterQuality filterQuality;
  final Widget? emptyChild;

  const _ArticleNetworkCover({
    required this.url,
    required this.cacheWidth,
    this.fallbackColor = const Color(0xFF151515),
    this.filterQuality = FilterQuality.low,
    this.emptyChild,
  });

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) {
      return emptyChild ?? ColoredBox(color: fallbackColor);
    }
    return Image.network(
      src,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (_, __, ___) =>
          emptyChild ?? ColoredBox(color: fallbackColor),
    );
  }
}

class ArticlesFeaturedCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;
  final bool unread;

  const ArticlesFeaturedCard({
    super.key,
    required this.article,
    required this.onTap,
    this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = article.estimatedReadingMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: kArticlesCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kArticlesBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: _ArticleNetworkCover(
                          url: article.imageUrl,
                          cacheWidth: articleImageCacheWidth(
                            context,
                            MediaQuery.sizeOf(context).width - 32,
                          ),
                          filterQuality: FilterQuality.medium,
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
                          decoration: BoxDecoration(
                            color: kArticlesGreenDeep.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(2),
                          ),
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
                      if (unread)
                        const Positioned(
                          right: 12,
                          top: 12,
                          child: _UnreadPip(),
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
                          articleRelDate(article.date),
                        ].join('  ·  '),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: kArticlesMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kArticlesText,
                          height: 1.02,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (article.hasTeaser) ...[
                        const SizedBox(height: 8),
                        Text(
                          article.teaser,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: kArticlesMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if ((article.authorName ?? '').trim().isNotEmpty)
                            Expanded(
                              child: Text(
                                article.authorName!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kArticlesText,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          Text(
                            'Lire l’article',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kArticlesGreenDeep,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: kArticlesGreenDeep,
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
      ),
    );
  }
}

class ArticleCompactCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;
  final bool isLast;
  final bool unread;
  final bool grid;
  final bool padded;

  const ArticleCompactCard({
    super.key,
    required this.article,
    required this.onTap,
    this.isLast = false,
    this.unread = false,
    this.grid = false,
    this.padded = true,
  });

  static const _thumbWidth = 118.0;
  static const _thumbHeight = 108.0;

  @override
  Widget build(BuildContext context) {
    final minutes = article.estimatedReadingMinutes;
    final screenW = MediaQuery.sizeOf(context).width;
    final cover = _ArticleNetworkCover(
      url: article.imageUrl,
      cacheWidth: articleImageCacheWidth(
        context,
        grid ? (screenW - 42) / 2 : _thumbWidth,
      ),
      fallbackColor: kArticlesIvory,
      emptyChild: ColoredBox(
        color: kArticlesIvory,
        child: Icon(
          Icons.article_outlined,
          color: articleCategoryColor(article.category),
          size: 28,
        ),
      ),
    );

    return Padding(
      padding: grid
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(padded ? 16 : 0, 0, padded ? 16 : 0, isLast ? 0 : 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: kArticlesCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kArticlesBorder, width: 1),
            ),
            child: grid
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 11,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              cover,
                              if (unread)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: _UnreadPip(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                        child: _ArticleCardCopy(
                          article: article,
                          minutes: minutes,
                          compact: true,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _thumbWidth,
                        height: _thumbHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(5),
                              ),
                              child: cover,
                            ),
                            if (unread)
                              const Positioned(
                                top: 8,
                                left: 8,
                                child: _UnreadPip(),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: _ArticleCardCopy(
                            article: article,
                            minutes: minutes,
                            compact: false,
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

class _ArticleCardCopy extends StatelessWidget {
  final ArticleModel article;
  final int minutes;
  final bool compact;

  const _ArticleCardCopy({
    required this.article,
    required this.minutes,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (article.displayCategoryLabel.isNotEmpty)
              article.displayCategoryLabel.toUpperCase(),
            '$minutes min',
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.35,
            color: kArticlesMuted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          article.title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w800,
            color: kArticlesText,
            height: 1.08,
          ),
        ),
        if (article.hasTeaser && !compact) ...[
          const SizedBox(height: 6),
          Text(
            article.teaser,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.35,
              color: kArticlesMuted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          articleRelDate(article.date),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: kArticlesMuted,
          ),
        ),
      ],
    );
  }
}

class _UnreadPip extends StatelessWidget {
  const _UnreadPip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF167A5F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class ArticlesEmptyState extends StatelessWidget {
  const ArticlesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
        decoration: BoxDecoration(
          color: kArticlesCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kArticlesBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.article_outlined, color: kArticlesGreen, size: 32),
            const SizedBox(height: 12),
            Text(
              'Aucune actu pour le moment',
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kArticlesText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dès qu’un billet est publié sur dvcr.fr, il arrive ici — avec sa une et son temps de lecture.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
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

class ArticlesErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const ArticlesErrorState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
        decoration: BoxDecoration(
          color: kArticlesCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kArticlesBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: kArticlesMuted, size: 32),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les actus',
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kArticlesText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vérifie ta connexion. Les articles déjà lus restent dans tes favoris.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kArticlesMuted,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'RÉESSAYER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kArticlesGreenDeep,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ArticleTagFilterBar extends StatelessWidget {
  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const ArticleTagFilterBar({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final on = selected == tag;
          return GestureDetector(
            onTap: () => onChanged(on ? null : tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: on ? kArticlesGreenDeep : kArticlesCard,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: on ? kArticlesGreenDeep : kArticlesBorder,
                ),
              ),
              child: Text(
                tag,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : kArticlesText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

