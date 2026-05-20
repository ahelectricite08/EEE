import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widgets/dvcr_reveal.dart';
import '../theme/prono_tokens.dart';

/// Barre épinglée au scroll (même idée que [LiveHeroPinnedToolbar] / [ArticlesHeroPinnedToolbar]).
class PronoTabHeroPinnedToolbar extends StatelessWidget {
  const PronoTabHeroPinnedToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(85)),
            ),
            child: Text(
              'PRONOS DVCR',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.65,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  color: Colors.white.withAlpha(235),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  'PRONOSTICS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fond photo + parallax ([FlexibleSpaceBar]), aligné sur Live / Actus.
class PronoTabHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String subtitle;

  /// Même visuel que [_PronoHomeHero] (accueil prono).
  static const _heroAsset = 'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg';

  const PronoTabHeroFlexibleSpace({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Widget heroImage() {
      return Image.asset(
        _heroAsset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.12),
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: PronoTokens.accentDeep,
          child: Center(
            child: Icon(
              Icons.stadium_rounded,
              size: 48,
              color: Colors.white.withAlpha(50),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: heroImage()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(125),
                  Colors.black.withAlpha(50),
                ],
                stops: const [0.0, 0.48],
              ),
            ),
          ),
        ),
        FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: heroImage()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(230),
                        Color.lerp(
                          PronoTokens.accent,
                          PronoTokens.accentGold,
                          0.22,
                        )!.withAlpha(118),
                        PronoTokens.accent.withAlpha(72),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.22, 0.42, 0.78],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 0.96,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(110),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(232),
                        height: 1.32,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [SliverAppBar] collapsing : bords arrondis bas 22, stretch.
/// Hauteur expansée volontairement plus basse que Live / Actus pour laisser la place au contenu.
abstract final class PronoTabHeroSliver {
  static const Color _sheetTop = PronoTokens.surface;

  /// Zone image + titre sous la toolbar (sans status ni barre épinglée).
  static const double _expandedBody = 128;

  static SliverAppBar build(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + 52 + _expandedBody,
      stretch: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 52,
      titleSpacing: 0,
      title: const PronoTabHeroPinnedToolbar(),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: PronoTabHeroFlexibleSpace(
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  /// Jonction sous le hero (reveal + arrondi haut, comme Live / Actus).
  static Widget sheetLeadInSliver() {
    return SliverToBoxAdapter(
      child: DVCRReveal(
        duration: const Duration(milliseconds: 480),
        offsetY: 22,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: ColoredBox(
            color: _sheetTop,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 46,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: PronoTokens.barStripeColors(active: true),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
