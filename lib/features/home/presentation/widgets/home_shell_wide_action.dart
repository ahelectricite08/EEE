import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_palette.dart';

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
