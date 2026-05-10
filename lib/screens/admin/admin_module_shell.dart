import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

/// En-tête de page pour les modules admin (Live, Matchs, etc.).
class AdminModuleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const AdminModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.dashboard_rounded,
    this.accent = adminGold,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: adminCardDecoration(
        radius: 18,
        borderColor: accent.withAlpha(70),
        glow: true,
        glowColor: accent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withAlpha(46), accent.withAlpha(14)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withAlpha(100)),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                    height: 1.0,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bloc section : en-tête de rubrique + contenu.
///
/// [wrapInCard] : false quand le [child] contient déjà ses propres cartes
/// (ex. live, salon) pour éviter l’empilement visuel.
class AdminModuleSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? accent;
  final bool wrapInCard;

  const AdminModuleSection({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.child,
    this.accent,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final ac = accent ?? adminGold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ac, ac.withAlpha(90)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: ac,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      height: 1.05,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: adminGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (wrapInCard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: adminCardDecoration(radius: 16),
            child: child,
          )
        else
          child,
      ],
    );
  }
}
