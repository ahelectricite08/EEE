import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_palette.dart';

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
