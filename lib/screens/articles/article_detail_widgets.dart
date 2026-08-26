import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/article_model.dart';
import 'articles_list_widgets.dart';

/// Wix sert souvent du **AVIF** dans `src` (`enc_avif`) : [Image.network] ne le décode pas sur beaucoup d’Android.
/// `data-pin-media` pointe en général vers du JPEG plus large — on le préfère.
String wixStaticUrlWithoutAvif(String url) {
  if (url.isEmpty) return url;
  if (!url.toLowerCase().contains('enc_avif')) return url;
  var s = url.replaceAll(RegExp(r',blur_\d+'), '');
  s = s.replaceAll(RegExp(r',enc_avif,quality_auto', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r',enc_avif'), '');
  return s;
}

/// Résout l’URL affichable pour les `<img>` Wix (lazy-load, srcset, AVIF → JPEG).
String wixArticleResolvedImageUrl(Map<String, String> attrs) {
  String g(String k) => (attrs[k] ?? '').trim();

  bool usableHttp(String s) =>
      s.startsWith('http') && !s.toLowerCase().startsWith('data:');

  final pin = g('data-pin-media');
  if (usableHttp(pin)) {
    return wixStaticUrlWithoutAvif(pin);
  }

  final src = g('src');
  if (usableHttp(src)) return wixStaticUrlWithoutAvif(src);
  if (src.startsWith('//')) return wixStaticUrlWithoutAvif('https:$src');

  for (final k in [
    'data-src',
    'data-lazy-src',
    'data-image',
    'data-url',
    'data-wix-url',
  ]) {
    final u = g(k);
    if (usableHttp(u)) return wixStaticUrlWithoutAvif(u);
  }

  final srcset = g('srcset');
  if (srcset.isNotEmpty) {
    final first = srcset.split(',').first.trim().split(RegExp(r'\s+')).first;
    if (first.startsWith('http')) return wixStaticUrlWithoutAvif(first);
    if (first.startsWith('//')) {
      return wixStaticUrlWithoutAvif('https:$first');
    }
  }

  if (src.isNotEmpty && !src.toLowerCase().startsWith('data:')) {
    return wixStaticUrlWithoutAvif(src);
  }
  return '';
}

Map<String, String> _extensionAttrsToMap(ExtensionContext context) {
  final out = <String, String>{};
  for (final e in context.attributes.entries) {
    out[e.key.toString()] = e.value.toString();
  }
  return out;
}

String _decodeHtmlEntitiesInUrl(String url) {
  if (url.isEmpty) return url;
  return url
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .trim();
}

double _parsePositiveDimension(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.trim().toLowerCase().replaceAll(RegExp(r'px|%'), '');
  if (cleaned.isEmpty || cleaned == 'auto') return 0;
  return double.tryParse(cleaned) ?? 0;
}

/// Ratio w/h depuis attributs Wix ou `w_980,h_653` dans l’URL — réserve la hauteur
/// dès le premier frame (évite le relayout en cascade au scroll).
double _articleImgAspect(Map<String, String> attrs, String url) {
  final w = _parsePositiveDimension(attrs['width']);
  final h = _parsePositiveDimension(attrs['height']);
  if (w > 8 && h > 8) return w / h;

  final dw = _parsePositiveDimension(
    attrs['data-width'] ?? attrs['data-image-width'],
  );
  final dh = _parsePositiveDimension(
    attrs['data-height'] ?? attrs['data-image-height'],
  );
  if (dw > 8 && dh > 8) return dw / dh;

  final m = RegExp(r'w_(\d{2,5}),h_(\d{2,5})').firstMatch(url);
  if (m != null) {
    final ww = double.parse(m.group(1)!);
    final hh = double.parse(m.group(2)!);
    if (ww > 8 && hh > 8) return ww / hh;
  }
  return 16 / 10;
}

/// Image HTML en **bloc** (pas WidgetSpan) : largeur écran bornée, hauteur figée.
class _ArticleHtmlBoundedImage extends StatelessWidget {
  final String url;
  final double aspect;

  const _ArticleHtmlBoundedImage({
    required this.url,
    required this.aspect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context).width;
        var w = constraints.maxWidth;
        if (!w.isFinite || w <= 0) {
          w = (screen - 40).clamp(120.0, 680.0);
        }
        w = w.clamp(120.0, 680.0);
        final ratio = aspect <= 0 ? 16 / 10 : aspect;
        final h = (w / ratio).clamp(80.0, 560.0);
        final cacheW = articleImageCacheWidth(context, w);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: w,
              height: h,
              child: ColoredBox(
                color: kArticlesIvory,
                child: Image.network(
                  url,
                  width: w,
                  height: h,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  cacheWidth: cacheW,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  headers: const {
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
                  },
                  loadingBuilder: (ctx, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      width: w,
                      height: h,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kArticlesProgress,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (ctx, error, stackTrace) {
                    if (kDebugMode) {
                      debugPrint('DVCR wix image failed: $url\n$error');
                    }
                    return SizedBox(
                      width: w,
                      height: h,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 36,
                        color: Colors.grey.shade500,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _buildWixImgBlock(ExtensionContext context) {
  final raw = wixArticleResolvedImageUrl(_extensionAttrsToMap(context));
  final url = _decodeHtmlEntitiesInUrl(raw);
  if (url.isEmpty) return const SizedBox.shrink();
  final attrs = _extensionAttrsToMap(context);
  return _ArticleHtmlBoundedImage(
    url: url,
    aspect: _articleImgAspect(attrs, url),
  );
}

Widget _buildWixIframe(ExtensionContext context) {
  final src = (context.attributes['src'] ?? '').trim();
  if (src.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final u = Uri.tryParse(src.startsWith('//') ? 'https:$src' : src);
          if (u != null) {
            await launchUrl(u, mode: LaunchMode.externalApplication);
          }
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: kArticlesIvory,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kArticlesBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: kArticlesGreenDeep,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lire la vidéo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kArticlesText,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 16, color: kArticlesMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

/// À passer à [Html.extensions] pour les articles Wix (images lazy-load / wixstatic).
/// Images en **bloc** (pas [WidgetSpan]) pour un scroll stable dans un sliver.
List<HtmlExtension> wixArticleHtmlExtensions() => [
      TagExtension(
        tagsToExtend: {'img'},
        builder: _buildWixImgBlock,
      ),
      TagExtension(
        tagsToExtend: {'iframe'},
        builder: _buildWixIframe,
      ),
    ];

/// Blanc page Wix (`#fff`, `white`, `rgb(255,255,255)`) — pas les fonds colorés.
final _wixWhiteBgDeclRe = RegExp(
  r'(?:background-color|background)\s*:\s*'
  r'(?:#fff(?:fff)?|white|'
  r'rgb\(\s*255\s*(?:,\s*|\s+)255\s*(?:,\s*|\s+)255(?:\s*/\s*[\d.%]+)?\s*\)|'
  r'rgba\(\s*255\s*,\s*255\s*,\s*255\s*,\s*[\d.]+\s*\)|'
  r'hsl\(\s*0\s*,\s*0%\s*,\s*100%\s*\))'
  r'(?:\s*!important)?\s*;?',
  caseSensitive: false,
);

String _wixCssWhiteBackgroundsToTransparent(String css) {
  return css.replaceAllMapped(_wixWhiteBgDeclRe, (m) {
    final raw = m.group(0)!;
    final prop = raw.toLowerCase().contains('background-color')
        ? 'background-color'
        : 'background';
    return '$prop:transparent;';
  });
}

/// html / body / article + inline Wix : fond blanc → transparent (un seul ivoire).
String _wixNeutralizeWhitePageBackgrounds(String html) {
  var h = html;
  h = h.replaceAllMapped(
    RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
    (m) {
      var block = _wixCssWhiteBackgroundsToTransparent(m.group(0)!);
      block = block.replaceAllMapped(
        RegExp(
          r'(^|\}|\s)((?:html|body|article)(?:\s*,\s*(?:html|body|article))*)\s*\{([^}]*)\}',
          caseSensitive: false,
        ),
        (mm) {
          final sel = mm.group(2)!;
          var body = mm.group(3)!;
          if (!RegExp(
            r'background(?:-color)?\s*:\s*transparent',
            caseSensitive: false,
          ).hasMatch(body)) {
            body = 'background:transparent;background-color:transparent;$body';
          }
          return '${mm.group(1)}$sel{$body}';
        },
      );
      return block;
    },
  );
  h = h.replaceAllMapped(
    RegExp(r'''\sstyle\s*=\s*(["'])(.*?)\1''', caseSensitive: false, dotAll: true),
    (m) {
      final q = m.group(1)!;
      final style = _wixCssWhiteBackgroundsToTransparent(m.group(2)!)
          .replaceAll(RegExp(r';\s*;'), ';')
          .trim();
      if (style.isEmpty) return '';
      return ' style=$q$style$q';
    },
  );
  h = h.replaceAll(
    RegExp(
      r'''\sbgcolor\s*=\s*(["']?)(?:#fff(?:fff)?|white)\1''',
      caseSensitive: false,
    ),
    '',
  );
  return h;
}

/// Retire en fin de HTML les blocs Wix / Ricos vides (lignes vides, rcv-block) → évite le grand blanc au-dessus de « Ouvrir sur dvcr.fr ».
String wixArticleHtmlForDisplay(String raw) {
  var h = _wixNeutralizeWhitePageBackgrounds(raw);
  for (var i = 0; i < 80; i++) {
    final before = h.length;
    h = h.replaceFirst(
      RegExp(
        r'<div\b[^>]*\btype="empty-line"[^>]*>\s*</div>\s*$',
        caseSensitive: false,
      ),
      '',
    );
    h = h.replaceFirst(
      RegExp(
        r'<div\b[^>]*\bdata-hook="rcv-block-last"[^>]*>\s*</div>\s*$',
        caseSensitive: false,
      ),
      '',
    );
    h = h.replaceFirst(
      RegExp(
        r'<div\b[^>]*\btype="paragraph"[^>]*\bdata-hook="rcv-block\d+"[^>]*>\s*</div>\s*$',
        caseSensitive: false,
      ),
      '',
    );
    h = h.replaceFirst(
      RegExp(
        r'<div\b[^>]*\bdata-breakout="normal"[^>]*>\s*<div\b[^>]*>\s*<span\b[^>]*>\s*<br\b[^>]*(?:\s*/)?>\s*</span>\s*</div>\s*</div>\s*$',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    h = h.replaceFirst(
      RegExp(r'(?:\s|&nbsp;)+$', caseSensitive: false),
      '',
    );
    if (h.length == before) break;
  }
  return h.trimRight();
}

class ArticleReadingProgressBar extends StatelessWidget {
  final ValueListenable<double> progress;

  const ArticleReadingProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, _) {
          return SizedBox(
            height: 4,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xE6F4F0E6),
                border: Border(
                  top: BorderSide(color: Color(0x66FFFFFF), width: 0.5),
                ),
              ),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: const Color(0x66F4F0E6),
                color: kArticlesProgress,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ArticleDetailMetaCard extends StatelessWidget {
  final ArticleModel article;
  final Color categoryColor;
  final bool liked;
  final int readingMinutes;
  final VoidCallback onReadingOptions;
  final VoidCallback? onLike;
  final Widget favoriteButton;

  const ArticleDetailMetaCard({
    super.key,
    required this.article,
    required this.categoryColor,
    required this.liked,
    required this.readingMinutes,
    required this.onReadingOptions,
    required this.favoriteButton,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final author = (article.authorName ?? '').trim().isEmpty
        ? 'Rédaction DVCR'
        : article.authorName!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (article.displayCategoryLabel.isNotEmpty) ...[
          Text(
            article.displayCategoryLabel.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: kArticlesGreenDeep,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          article.title,
          style: GoogleFonts.barlowCondensed(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: kArticlesText,
            height: 1.06,
            letterSpacing: 0.15,
          ),
        ),
        if (article.hasTeaser) ...[
          const SizedBox(height: 12),
          Text(
            article.teaser,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: kArticlesMuted,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '$author  ·  ${_formatFullDate(article.date)}  ·  $readingMinutes min',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: kArticlesMuted,
          ),
        ),
        if (article.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: article.tags
                .take(8)
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: kArticlesBorder),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: kArticlesMuted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        const DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: kArticlesBorder, width: 1),
            ),
          ),
          child: SizedBox(width: double.infinity, height: 1),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DetailStatChip(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: article.likesCount == 0
                  ? 'J’ai lu'
                  : '${article.likesCount} j\'aime',
              accent: liked ? categoryColor : null,
              onTap: onLike,
            ),
            _DetailActionChip(
              icon: Icons.text_fields_rounded,
              label: 'Lecture',
              onTap: onReadingOptions,
            ),
            favoriteButton,
            Text(
              '${article.viewsCount} vues',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kArticlesMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ArticleContentCard extends StatelessWidget {
  final List<Widget> children;

  const ArticleContentCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class ArticleDetailShareBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback? onOpenSite;

  const ArticleDetailShareBar({
    super.key,
    required this.onShare,
    this.onOpenSite,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: kArticlesBorder),
          bottom: BorderSide(color: kArticlesBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _ShareBarButton(
                icon: Icons.ios_share_rounded,
                label: 'Partager',
                onTap: onShare,
              ),
            ),
            if (onOpenSite != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ShareBarButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'Ouvrir sur dvcr.fr',
                  onTap: onOpenSite!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kArticlesCard,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: kArticlesBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: kArticlesGreenDeep),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kArticlesText,
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

class ArticleDetailSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const ArticleDetailSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kArticlesText,
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class ArticleDetailEmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ArticleDetailEmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: kArticlesCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kArticlesBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: kArticlesIvory,
              shape: BoxShape.circle,
              border: Border.all(color: kArticlesBorder),
            ),
            child: Icon(icon, color: kArticlesGreenDeep, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: kArticlesText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kArticlesMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class ArticleGalleryStrip extends StatelessWidget {
  final List<String> urls;

  const ArticleGalleryStrip({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ArticleDetailSectionTitle(title: 'Galerie'),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  urls[i],
                  width: 210,
                  height: 148,
                  fit: BoxFit.cover,
                  cacheWidth: articleImageCacheWidth(context, 210),
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 210),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class ArticleVideoLink extends StatelessWidget {
  final String url;
  final Future<void> Function(String url) onOpen;

  const ArticleVideoLink({
    super.key,
    required this.url,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(url),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kArticlesIvory,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kArticlesBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: kArticlesGreenDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voir la vidéo de l’article',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kArticlesText,
                    ),
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: kArticlesMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  final VoidCallback? onTap;

  const _DetailStatChip({
    required this.icon,
    required this.label,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kArticlesMuted;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kArticlesIvory,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: kArticlesBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: child,
      ),
    );
  }
}

class _DetailActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DetailActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Icon(icon, size: 16, color: kArticlesGreenDeep),
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
        ),
      ),
    );
  }
}

String _formatFullDate(DateTime d) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
