import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article_model.dart';
import '../services/dvcr_share_service.dart';
import '../utils/share_helper.dart';
import 'dvcr_reveal.dart';

const _kRed = Color(0xFFBA203C);
const _kCard = Color(0xFF141414);
const _kDivider = Color(0xFF1C1C1C);

// ── Article row OL TV style ───────────────────────────────────────────────────
class ArticleRow extends StatelessWidget {
  final ArticleModel article;
  final bool isLast;
  final VoidCallback? onTap;

  const ArticleRow({
    super.key,
    required this.article,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DVCRReveal(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Contenu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date + catégorie
                        Row(
                          children: [
                            Text(
                              _fmtDate(article.date),
                              style: GoogleFonts.barlow(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kRed,
                              ),
                            ),
                            if (article.displayCategoryLabel.isNotEmpty) ...[
                              Text(
                                ' · ',
                                style: GoogleFonts.barlow(
                                  fontSize: 11,
                                  color: const Color(0xFF444444),
                                ),
                              ),
                              Text(
                                article.displayCategoryLabel.toUpperCase(),
                                style: GoogleFonts.barlow(
                                  fontSize: 11,
                                  color: const Color(0xFF666666),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Titre
                        Text(
                          article.title,
                          style: GoogleFonts.barlow(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'LIRE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white54,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Thumbnail
                  Container(
                    width: 80,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: article.imageUrl != null
                        ? Image.network(
                            article.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_outlined,
                              color: Colors.white12,
                              size: 22,
                            ),
                          )
                        : const Icon(
                            Icons.sports_soccer_rounded,
                            color: Colors.white12,
                            size: 22,
                          ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                color: _kDivider,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final months = [
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Video card (grid style Gentle Mates YouTube) ──────────────────────────────
class VideoCard extends StatelessWidget {
  final String title;
  final String youtubeId;
  final String duration;
  final DateTime date;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.title,
    required this.youtubeId,
    required this.duration,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl = 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(
                        Icons.play_circle_outline_rounded,
                        color: Colors.white12,
                        size: 40,
                      ),
                    ),
                  ),
                  // Durée badge
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Play icon center
                  const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white60,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.barlow(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => DvcrShare.share(
                      ShareHelper.replayStripShareText(
                        title: title,
                        duration: duration,
                        relativeDate: _relativeDate(date),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.share_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Date
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                _relativeDate(date),
                style: GoogleFonts.barlow(
                  fontSize: 10,
                  color: const Color(0xFF666666),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${d.day}/${d.month}/${d.year}';
  }
}
