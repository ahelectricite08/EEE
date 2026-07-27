import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/prono/presentation/theme/prono_theme.dart';

/// Couleurs / relief classement prono — table claire minimal gaming.
abstract final class PronoLbStyle {
  static const bg = PronoArenaTheme.scaffoldTop;
  static const highlight = PronoArenaTheme.edgeHighlight;
  /// Alias rétrocompatible.
  static const green = highlight;
  static const gold = PronoArenaTheme.accentGold;
  static const text = PronoArenaTheme.text;
  static const muted = PronoArenaTheme.textMuted;
  static const surface = PronoArenaTheme.surface;
  static const surfaceMuted = PronoArenaTheme.surfaceMuted;
  static const border = PronoArenaTheme.border;
}

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
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: PronoLbStyle.text,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PronoLbStyle.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class PronoLbTableShell extends StatelessWidget {
  final List<Widget> children;

  const PronoLbTableShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: PronoTheme.cardDecoration(radius: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: PronoLbStyle.surfaceMuted,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PronoLbStyle.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nameLabel.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PronoLbStyle.muted,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(
            width: showExactColumn ? 48 : 56,
            child: Text(
              'PTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PronoLbStyle.muted,
              ),
            ),
          ),
          if (showExactColumn) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                'EXACTS',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, color: PronoLbStyle.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PronoLbStyle.muted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, color: PronoLbStyle.border)),
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

  Widget _rankCell() {
    final rankColor = PronoTheme.podiumRankColor(displayRank);
    final isPodium = displayRank <= 3;
    return SizedBox(
      width: 32,
      child: Text(
        '$displayRank',
        style: GoogleFonts.barlowCondensed(
          fontSize: isPodium ? 18 : 14,
          fontWeight: FontWeight.w800,
          color: isPodium ? rankColor : PronoLbStyle.muted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stripeColor = PronoTheme.podiumStripeColor(displayRank);
    final hasStripe = displayRank <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isMe ? PronoLbStyle.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isMe
            ? Border.all(color: PronoLbStyle.border)
            : hasStripe
                ? null
                : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasStripe)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rankCell(),
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
                              fontSize: 14,
                              fontWeight:
                                  isMe ? FontWeight.w700 : FontWeight.w600,
                              color: PronoLbStyle.text,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle != null &&
                              subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PronoLbStyle.muted,
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
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: hasStripe
                              ? stripeColor
                              : PronoLbStyle.text,
                        ),
                      ),
                    ),
                    if (showExactColumn) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${exactScores ?? 0}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PronoLbStyle.muted,
                          ),
                        ),
                      ),
                    ],
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

class PronoLbFootnote extends StatelessWidget {
  final String text;

  const PronoLbFootnote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: PronoLbStyle.muted,
          height: 1.4,
        ),
      ),
    );
  }
}
