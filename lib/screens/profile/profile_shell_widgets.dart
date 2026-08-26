import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/remote_image_url.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

/// AppBar des sous-pages profil — ivoire, filet 1 px, pas de bande saturée.
class ProfileSubpageAppBar {
  ProfileSubpageAppBar._();

  static AppBar build(
    BuildContext context,
    String title, {
    Color? accentColor,
  }) {
    final tone = accentColor ?? profileGreenBright;
    return AppBar(
      backgroundColor: profileBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: tone, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(title, style: ProfileType.title),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: profileHairline),
      ),
    );
  }
}

/// Contenant papier — filet 1 px, rayon sobre, pas d’ombre Material.
class ProfileElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;

  const ProfileElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = profilePaperRadius,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: r,
      child: DecoratedBox(
        decoration: profilePaper(edge: borderColor),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
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
          Icon(icon, color: accent, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: ProfileType.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: ProfileType.body),
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
      children: [
        Container(width: 22, height: 1, color: accent),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 8),
        Text(title, style: ProfileType.section),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: profileHairline, height: 1, thickness: 1)),
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

/// En-tête de page (filet club + Barlow).
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
    final tone = accent ?? profileGreenBright;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 22, height: 2, color: tone),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ProfileType.title),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: ProfileType.caption),
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

/// Ligne liste papier — contenant réel, photo optionnelle, pas de filet coloré.
class ProfileListRow extends StatelessWidget {
  final Color accentStripe;
  final Color? stripeColor;
  final Color? cardBorderColor;
  final Widget leading;
  final Widget middle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;
  final double rowBorderRadius;
  final String? photoUrl;

  const ProfileListRow({
    super.key,
    required this.accentStripe,
    required this.leading,
    required this.middle,
    this.stripeColor,
    this.cardBorderColor,
    this.trailing,
    this.onTap,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 10, 10, 10),
    this.rowBorderRadius = profilePaperRadius,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final border = cardBorderColor ??
        (stripeColor ?? accentStripe).withValues(alpha: 0.22);
    final r = rowBorderRadius;
    final thumb = (photoUrl ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: DecoratedBox(
            decoration: profilePaper(edge: border),
            child: Padding(
              padding: contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (thumb.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        thumb,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheWidth: profileImageCacheWidth(context, 56),
                        headers: kDvcrImageHttpHeaders,
                        errorBuilder: (_, __, ___) => leading,
                      ),
                    )
                  else
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

/// Rangée d’action du hub Profil (menu papier).
class ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? profileGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: profilePaper(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: tone),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: ProfileType.label),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileType.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: profileGreen,
                  ),
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
    final card = DecoratedBox(
      decoration: profilePaper(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 10),
            Text(title, style: ProfileType.title.copyWith(fontSize: 20)),
            const SizedBox(height: 6),
            Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: ProfileType.caption),
          ],
        ),
      ),
    );

    if (!disabled) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(profilePaperRadius),
      child: Stack(
        children: [
          card,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(
                color: profileInk.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    'Bientôt disponible',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
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
    return DecoratedBox(
      decoration: profilePaper(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 10),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProfileType.figure),
            const SizedBox(height: 4),
            Text(label, style: ProfileType.caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
