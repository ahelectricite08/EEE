import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs / relief alignés sur le classement tournoi (Coupe du monde).
abstract final class PronoLbStyle {
  static const bg = Color(0xFFF5F2E9);
  static const green = Color(0xFF0A4438);
  static const gold = Color(0xFFC8A436);
  static const text = Color(0xFF173C31);
  static const muted = Color(0xFF5C6560);
}

/// Titre + texte d’intro (hors carte).
class PronoLbTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const PronoLbTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: PronoLbStyle.green,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PronoLbStyle.text.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte blanche avec ombre (tableau classement).
class PronoLbTableShell extends StatelessWidget {
  final List<Widget> children;

  const PronoLbTableShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PronoLbStyle.green.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: PronoLbStyle.green.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class PronoLbColumnHeader extends StatelessWidget {
  final String nameLabel;
  final bool showExactColumn;

  const PronoLbColumnHeader({
    super.key,
    required this.nameLabel,
    this.showExactColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: PronoLbStyle.green.withValues(alpha: 0.06),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: PronoLbStyle.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nameLabel.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: PronoLbStyle.muted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            width: showExactColumn ? 48 : 56,
            child: Text(
              'PTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: PronoLbStyle.muted,
              ),
            ),
          ),
          if (showExactColumn) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 56,
              child: Text(
                'EXACTS',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: PronoLbStyle.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PronoLbZoneDivider extends StatelessWidget {
  final String label;

  const PronoLbZoneDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: PronoLbStyle.green.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: PronoLbStyle.muted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: PronoLbStyle.green.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class PronoLbDataRow extends StatelessWidget {
  final int displayRank;
  final String title;
  final String? subtitle;
  final int points;
  final int? exactScores;
  final bool podiumHighlight;
  final bool isMe;
  final bool showExactColumn;

  const PronoLbDataRow({
    super.key,
    required this.displayRank,
    required this.title,
    this.subtitle,
    required this.points,
    this.exactScores,
    required this.podiumHighlight,
    required this.isMe,
    this.showExactColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      decoration: BoxDecoration(
        color: podiumHighlight
            ? PronoLbStyle.gold.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? PronoLbStyle.green.withValues(alpha: 0.55)
              : PronoLbStyle.muted.withValues(alpha: 0.18),
          width: isMe ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$displayRank',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PronoLbStyle.green,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PronoLbStyle.text,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: PronoLbStyle.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: showExactColumn ? 48 : 56,
            child: Text(
              '$points',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PronoLbStyle.text,
              ),
            ),
          ),
          if (showExactColumn) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 56,
              child: Text(
                '${exactScores ?? 0}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PronoLbStyle.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PronoLbFootnote extends StatelessWidget {
  final String text;

  const PronoLbFootnote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: PronoLbStyle.muted,
          height: 1.4,
        ),
      ),
    );
  }
}
