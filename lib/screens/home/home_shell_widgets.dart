import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_palette.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onSeeAll;
  final Widget? trailing;
  final bool showBadge;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.accent,
    this.onSeeAll,
    this.trailing,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? homeGreen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: tone,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.withAlpha(16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.withAlpha(48)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: tone, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBadge) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tone.withAlpha(48)),
                    ),
                    child: Text(
                      'À suivre',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: tone,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: homeText,
                    letterSpacing: 0.6,
                    height: 0.95,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: homeMutedText,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null || onSeeAll != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailing case final t?) ...[
                  t,
                  if (onSeeAll != null) const SizedBox(height: 6),
                ],
                if (onSeeAll != null)
                  InkWell(
                    onTap: onSeeAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tout voir',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: homeGreen,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: homeMutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HomeToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const HomeToolbarButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(70)),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}

class HomeQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool disabled;

  const HomeQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: homeSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: homeBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        height: 198,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withAlpha(55)),
                  ),
                  child: Text(
                    'RACCOURCI',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.45,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: accent.withAlpha(220),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withAlpha(70)),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: homeText,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: homeMutedText,
                    height: 1.28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  disabled ? 'Bientot disponible' : 'Explorer maintenant',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: disabled ? homeMutedText : homeText,
                  ),
                ),
                const Spacer(),
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_rounded,
                  size: 16,
                  color: disabled ? homeMutedText : accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!disabled) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          card,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 11,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bientôt',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte « raccourci » responsive (2 colonnes) — même vocabulaire que [HomeQuickActionCard].
class HomeWideActionCard extends StatelessWidget {
  /// Hauteur fixe partagée avec les [SizedBox] parents (évite overflow texte / accessibilité).
  static const double layoutHeight = 218;

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const HomeWideActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layoutHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: homeSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: homeBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              // Pas d'[Expanded] ici : dans un sliver / slide, la hauteur max peut
              // rester infinie jusqu'au Material et provoquer « h=Infinity ».
              child: ClipRect(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accent.withAlpha(55)),
                          ),
                          child: Text(
                            'RACCOURCI',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.45,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: accent.withAlpha(220),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withAlpha(70)),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: homeText,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: homeMutedText,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Ouvrir',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: homeText,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
