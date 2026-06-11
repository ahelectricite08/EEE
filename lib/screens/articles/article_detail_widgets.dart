import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';

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

double _articleImgTargetWidth(ExtensionContext context) {
  final ctx = context.buildContext;
  final screen = ctx != null ? MediaQuery.sizeOf(ctx).width : 400.0;
  const horizontalPadding = 16.0;
  const cardPadding = 18.0;
  final w = screen - 2 * horizontalPadding - 2 * cardPadding;
  return w.clamp(120.0, 2000.0);
}

/// [RichText] / [WidgetSpan] : largeur en % souvent = contrainte infinie → Image 0px.
/// Largeur explicite + pas de Referer (certains CDN Wix renvoient 403).
InlineSpan _buildWixImgSpan(ExtensionContext context) {
  final raw = wixArticleResolvedImageUrl(_extensionAttrsToMap(context));
  final url = _decodeHtmlEntitiesInUrl(raw);
  if (url.isEmpty) return const TextSpan(text: '');

  final w = _articleImgTargetWidth(context);

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Image.network(
        url,
        width: w,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
        },
        loadingBuilder: (ctx, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: w,
            height: 140,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
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
            height: 96,
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Colors.grey.shade500,
            ),
          );
        },
      ),
    ),
  );
}

/// À passer à [Html.extensions] pour les articles Wix (images lazy-load / wixstatic).
List<HtmlExtension> wixArticleHtmlExtensions() => [
      TagExtension.inline(
        tagsToExtend: {'img'},
        builder: _buildWixImgSpan,
      ),
    ];

/// Retire en fin de HTML les blocs Wix / Ricos vides (lignes vides, rcv-block) → évite le grand blanc au-dessus de « Ouvrir sur dvcr.fr ».
String wixArticleHtmlForDisplay(String raw) {
  var h = raw;
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

class ArticleDetailMetaCard extends StatelessWidget {
  final ArticleModel article;
  final Color categoryColor;
  final bool liked;
  final int readingMinutes;
  final VoidCallback onReadingOptions;
  final VoidCallback onShare;
  final Widget favoriteButton;

  const ArticleDetailMetaCard({
    super.key,
    required this.article,
    required this.categoryColor,
    required this.liked,
    required this.readingMinutes,
    required this.onReadingOptions,
    required this.onShare,
    required this.favoriteButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kArticlesCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kArticlesBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.displayCategoryLabel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                article.displayCategoryLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            article.title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: kArticlesText,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                article.authorName ?? 'Redaction DVCR',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kArticlesText,
                ),
              ),
              Text(
                '•',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kArticlesMuted,
                ),
              ),
              Text(
                _formatFullDate(article.date),
                style: GoogleFonts.inter(fontSize: 12, color: kArticlesMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _DetailStatChip(
                icon: Icons.remove_red_eye_outlined,
                label: '${article.viewsCount} vues',
              ),
              _DetailStatChip(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${article.likesCount} j\'aime',
                accent: liked ? categoryColor : null,
              ),
              _DetailStatChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${article.commentsCount} commentaires',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DetailActionChip(
                icon: Icons.text_fields_rounded,
                label: 'Lecture',
                onTap: onReadingOptions,
              ),
              favoriteButton,
              _DetailActionChip(
                icon: Icons.ios_share_rounded,
                label: 'Partager',
                onTap: onShare,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kArticlesIvory,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kArticlesBorder),
                ),
                child: Text(
                  '$readingMinutes min',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kArticlesText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ArticleContentCard extends StatelessWidget {
  final List<Widget> children;

  const ArticleContentCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kArticlesCard,
        borderRadius: BorderRadius.circular(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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

class _DetailStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _DetailStatChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kArticlesMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kArticlesIvory,
        borderRadius: BorderRadius.circular(999),
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
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
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
