import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_palette.dart';

/// AppBar des sous-pages profil — même ADN que l’accueil (clair, vert, filet discret).
class ProfileSubpageAppBar {
  ProfileSubpageAppBar._();

  static AppBar build(BuildContext context, String title) {
    return AppBar(
      backgroundColor: profileBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: profileGreen,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: profileText,
          letterSpacing: 0.45,
          height: 1.0,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: profileBorder.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Carte surface standard (listes, blocs compte).
class ProfileElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const ProfileElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: profileGreenDeep.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Container(
          decoration: BoxDecoration(
            color: profileSurface,
            borderRadius: r,
            border: Border.all(color: profileBorder),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}

/// État vide discret (favoris, sections alertes…).
class ProfileEmptyHint extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final Widget? action;

  const ProfileEmptyHint({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileElevatedCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: profileText,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: profileMutedText,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Titre de section secondaire (sous-blocs dans une page).
class ProfileInlineSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;

  const ProfileInlineSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.barlowCondensed(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: profileText,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: profileBorder.withValues(alpha: 0.85),
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class ProfileToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const ProfileToolbarButton({
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(74)),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}

/// En-tête de page (même logique que [HomeSectionHeader] : barre + capsule + texte).
class ProfileSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accent;
  final Widget? trailing;
  final bool showBadge;

  const ProfileSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.accent,
    this.trailing,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? profileGold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tone, profileGreen],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.withValues(alpha: 0.42)),
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
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tone.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'DVCR',
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
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: profileText,
                    letterSpacing: 0.5,
                    height: 0.95,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: profileMutedText,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Ligne liste « premium » : pas de [Ink] (meilleures contraintes), ripple sur [DecoratedBox].
class ProfileListRow extends StatelessWidget {
  /// Couleur d’accent (bordure par défaut si [cardBorderColor] est null).
  final Color accentStripe;
  final Color? stripeColor;
  final Color? cardBorderColor;
  final Widget leading;
  final Widget middle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;
  final double rowBorderRadius;

  const ProfileListRow({
    super.key,
    required this.accentStripe,
    required this.leading,
    required this.middle,
    this.stripeColor,
    this.cardBorderColor,
    this.trailing,
    this.onTap,
    this.contentPadding = const EdgeInsets.fromLTRB(0, 0, 10, 0),
    this.rowBorderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final stripe = stripeColor ?? accentStripe;
    final border = cardBorderColor ??
        accentStripe.withValues(alpha: 0.22);
    final r = rowBorderRadius;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: profileGreenDeep.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: stripe,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(r - 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: middle),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileHubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool disabled;

  const ProfileHubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: profileSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: profileBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withAlpha(70)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: profileText,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: profileMutedText,
              height: 1.32,
            ),
          ),
        ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 12, color: Colors.white54),
                      const SizedBox(width: 5),
                      Text(
                        'Bientôt disponible',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          letterSpacing: 0.2,
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

class ProfileOverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const ProfileOverviewMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: profileSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: profileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(70)),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: profileText,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: profileMutedText,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
