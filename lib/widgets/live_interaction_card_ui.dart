import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

const kLiveCardGold = Color(0xFFC8A436);
const kLiveCardRed = Color(0xFFBA203C);
const kLiveCardRadius = 18.0;

/// Carte live commune (sondage émission, homme du match).
class LiveInteractionCardShell extends StatelessWidget {
  final Widget header;
  final Widget body;
  final String? backgroundImageUrl;
  final String? fallbackAsset;

  const LiveInteractionCardShell({
    super.key,
    required this.header,
    required this.body,
    this.backgroundImageUrl,
    this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kLiveCardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColorsLight.card,
          borderRadius: BorderRadius.circular(kLiveCardRadius),
          border: Border.all(color: AppColorsLight.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeroBanner(
              backgroundImageUrl: backgroundImageUrl,
              fallbackAsset: fallbackAsset,
              child: header,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: body,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String? backgroundImageUrl;
  final String? fallbackAsset;
  final Widget child;

  const _HeroBanner({
    required this.child,
    this.backgroundImageUrl,
    this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroImage(
            url: backgroundImageUrl,
            asset: fallbackAsset,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(80),
                  Colors.black.withAlpha(160),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 12,
            bottom: 12,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String? url;
  final String? asset;

  const _HeroImage({this.url, this.asset});

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty) {
      return Image.network(
        u,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _assetOrColor(),
      );
    }
    return _assetOrColor();
  }

  Widget _assetOrColor() {
    final a = asset;
    if (a != null && a.isNotEmpty) {
      return Image.asset(
        a,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.green),
      );
    }
    return const ColoredBox(color: AppColors.green);
  }
}

/// Logo sponsor dans le bandeau (fond blanc pour lisibilité).
class LiveInteractionSponsorMark extends StatelessWidget {
  final String? logoUrl;
  final String? name;

  const LiveInteractionSponsorMark({
    super.key,
    this.logoUrl,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final url = (logoUrl ?? '').trim();
    final label = (name ?? '').trim();
    if (url.isEmpty && label.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 76, maxHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallbackText(label),
            )
          : _fallbackText(label),
    );
  }

  Widget _fallbackText(String label) {
    if (label.isEmpty) {
      return const Icon(Icons.campaign_rounded, size: 20, color: AppColors.green);
    }
    return Center(
      child: Text(
        label.length > 10 ? '${label.substring(0, 10)}.' : label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: AppColors.green,
          height: 1.1,
        ),
      ),
    );
  }
}

class LiveInteractionHeroHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool isLive;
  final String? sponsorLogoUrl;
  final String? sponsorName;
  final Widget? trailing;
  final IconData icon;

  const LiveInteractionHeroHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.isLive,
    this.sponsorLogoUrl,
    this.sponsorName,
    this.trailing,
    this.icon = Icons.poll_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasSponsor =
        (sponsorLogoUrl ?? '').trim().isNotEmpty ||
        (sponsorName ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: kLiveCardGold, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withAlpha(230),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (hasSponsor) ...[
              const SizedBox(width: 8),
              LiveInteractionSponsorMark(
                logoUrl: sponsorLogoUrl,
                name: sponsorName,
              ),
            ],
            const SizedBox(width: 8),
            LiveInteractionLiveBadge(active: isLive),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.05,
            letterSpacing: 0.2,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(210),
            ),
          ),
        ],
      ],
    );
  }
}

class LiveInteractionLiveBadge extends StatelessWidget {
  final bool active;

  const LiveInteractionLiveBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? kLiveCardRed.withAlpha(220)
            : Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? kLiveCardRed : Colors.white.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            active ? 'LIVE' : 'CLOS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveInteractionMetaRow extends StatelessWidget {
  final List<LiveInteractionMetaChip> chips;

  const LiveInteractionMetaRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class LiveInteractionMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final bool onDark;

  const LiveInteractionMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.highlight = false,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = onDark
        ? Colors.white.withAlpha(38)
        : highlight
            ? const Color(0xFFFFF9E8)
            : AppColorsLight.cardMuted;
    final border = onDark
        ? Colors.white.withAlpha(60)
        : highlight
            ? kLiveCardGold.withAlpha(120)
            : AppColorsLight.border;
    final fg = onDark
        ? Colors.white
        : highlight
            ? AppColors.green
            : AppColorsLight.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: onDark ? Colors.white : AppColorsLight.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveInteractionHint extends StatelessWidget {
  final String text;

  const LiveInteractionHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColorsLight.textSecondary,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Ligne de choix (sondage ou joueur).
class LiveInteractionChoiceRow extends StatelessWidget {
  final String letter;
  final String label;
  final String? hint;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const LiveInteractionChoiceRow({
    super.key,
    required this.letter,
    required this.label,
    this.hint,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFF9E8)
                  : AppColorsLight.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? kLiveCardGold.withAlpha(200)
                    : AppColorsLight.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.green.withAlpha(24)
                        : AppColorsLight.cardMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.green,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColorsLight.textPrimary,
                        ),
                      ),
                      if (hint != null && hint!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColorsLight.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.green : AppColorsLight.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur d’équipe (2 colonnes).
class LiveInteractionTeamPicker extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String selectedTeamId;
  final bool enabled;
  final ValueChanged<String> onTeamSelected;

  const LiveInteractionTeamPicker({
    super.key,
    required this.teams,
    required this.selectedTeamId,
    required this.enabled,
    required this.onTeamSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < teams.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == teams.length - 1 ? 0 : 8),
              child: _TeamChip(
                letter: String.fromCharCode(65 + (i % 26)),
                label: (teams[i]['name'] as String? ?? '').trim(),
                selected:
                    (teams[i]['id'] as String? ?? '').trim() == selectedTeamId,
                enabled: enabled,
                onTap: () =>
                    onTeamSelected((teams[i]['id'] as String? ?? '').trim()),
              ),
            ),
          ),
      ],
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String letter;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TeamChip({
    required this.letter,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withAlpha(18)
                : AppColorsLight.cardMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.green : AppColorsLight.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                letter,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColorsLight.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveInteractionAdminChip extends StatelessWidget {
  final VoidCallback onTap;

  const LiveInteractionAdminChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withAlpha(90)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'EDIT',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveInteractionResultBanner extends StatelessWidget {
  final String text;

  const LiveInteractionResultBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLiveCardGold.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: kLiveCardGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColorsLight.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
