import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/remote_image_url.dart';
import 'match_detail_theme.dart';
import 'match_detail_type.dart';
import 'matches_helpers.dart';

int matchDetailHeroCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

int matchDetailCrestCacheWidth(BuildContext context, double size) {
  return (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 256);
}

/// Écusson — même taille des deux côtés.
/// Fill blanc franc. Filet 1 px : vert CSSA / gris chaud adversaire.
class MatchDetailCrest extends StatelessWidget {
  final String? url;
  final String teamName;
  final double size;
  final bool onPhoto;

  const MatchDetailCrest({
    super.key,
    required this.url,
    required this.teamName,
    this.size = MatchDetailTheme.crestHero,
    this.onPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final sedan = isSedanTeam(teamName);
    final u = url?.trim();
    final cacheW = matchDetailCrestCacheWidth(context, size);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MatchDetailTheme.crestFill,
          shape: BoxShape.circle,
          border: Border.all(
            width: MatchDetailTheme.crestStroke,
            color: sedan
                ? MatchDetailTheme.crestStrokeCssa
                : MatchDetailTheme.crestStrokeAway,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: u != null && u.isNotEmpty && !shouldSkipNetworkImageUrl(u)
              ? Image.network(
                  u,
                  fit: BoxFit.contain,
                  headers: kDvcrImageHttpHeaders,
                  cacheWidth: cacheW,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Icon(
      Icons.shield_outlined,
      size: size * 0.38,
      color: MatchDetailTheme.green,
    );
  }
}

/// En-tête de section — filet + kicker, jamais une chip Material.
class MatchDetailSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final Color? accent;

  const MatchDetailSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? MatchDetailTheme.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 16, height: 2, color: tone),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MatchDetailType.kicker.copyWith(color: MatchDetailTheme.text),
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: MatchDetailType.meta),
          ],
        ],
      ),
    );
  }
}

/// Tampon sportif — rectangle, pas une pilule Material.
class MatchDetailStamp extends StatelessWidget {
  final String label;
  final bool live;
  final bool ink;
  final Color? background;
  final Color? foreground;

  const MatchDetailStamp({
    super.key,
    required this.label,
    this.live = false,
    this.ink = false,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (live) {
      bg = MatchDetailTheme.red;
      fg = Colors.white;
    } else if (ink) {
      bg = MatchDetailTheme.ink;
      fg = Colors.white;
    } else {
      bg = background ?? MatchDetailTheme.surfaceMuted;
      fg = foreground ?? MatchDetailTheme.text;
    }
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: MatchDetailType.kicker.copyWith(
            letterSpacing: 1.1,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// CTA papier — filet 1 px, pas de FilledButton or.
class MatchDetailPaperButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool ink;

  const MatchDetailPaperButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.ink = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ink ? MatchDetailTheme.ink : MatchDetailTheme.surface,
          border: Border.all(
            color: ink ? MatchDetailTheme.ink : MatchDetailTheme.green,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: ink ? Colors.white : MatchDetailTheme.green,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: ink
                        ? Colors.white
                        : (enabled
                            ? MatchDetailTheme.green
                            : MatchDetailTheme.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglets fiche — soulignement filet, pas de chips remplies.
class MatchDetailUnderlineTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const MatchDetailUnderlineTabs({
    super.key,
    required this.controller,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MatchDetailTheme.scaffold,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Row(
              children: List.generate(labels.length, (i) {
                final selected = controller.index == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.animateTo(i),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              labels[i].toUpperCase(),
                              textAlign: TextAlign.center,
                              style: MatchDetailType.kicker.copyWith(
                                letterSpacing: 1.2,
                                color: selected
                                    ? MatchDetailTheme.text
                                    : MatchDetailTheme.textMuted,
                              ),
                            ),
                          ),
                          ColoredBox(
                            color: selected
                                ? MatchDetailTheme.green
                                : MatchDetailTheme.hairline,
                            child: const SizedBox(height: 2, width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Nameplate épinglé — visible au repli, sur la photo.
class MatchDetailPinnedToolbar extends StatelessWidget {
  final String nameplate;

  const MatchDetailPinnedToolbar({super.key, required this.nameplate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: MatchDetailTheme.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            nameplate.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MatchDetailType.nameplate,
          ),
        ),
      ],
    );
  }
}
