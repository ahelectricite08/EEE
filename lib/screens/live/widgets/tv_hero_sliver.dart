import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_settings_service.dart';
import '../../../widgets/hub_hero_photo.dart';
import '../theme/tv_theme.dart';
import '../theme/tv_type.dart';

int tvHeroCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

/// Nameplate épinglé — visible au repli, sur la photo (jamais un aplat).
class TvHeroPinnedToolbar extends StatelessWidget {
  const TvHeroPinnedToolbar({super.key});

  static final _channelUri = Uri.parse(
    'https://www.youtube.com/@drapeauvertcartonrouge',
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: TvTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DVCR TV',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TvType.nameplate,
            ),
          ),
          GestureDetector(
            onTap: () => launchUrl(
              _channelUri,
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'CHAÎNE',
              style: TvType.kickerOnPhoto.copyWith(letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo hero TV. Pas de [FlexibleSpaceBar] : il tue l’opacité au repli.
class TvHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String subtitle;
  final double lockupBottom;

  static const _heroAsset = 'assets/images/JOURDEMATCH.jpg';

  const TvHeroFlexibleSpace({
    super.key,
    required this.title,
    required this.subtitle,
    this.lockupBottom = 20,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final maxExtent = settings?.maxExtent ?? constraints.maxHeight;
        final minExtent = settings?.minExtent ?? constraints.maxHeight;
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final delta = maxExtent - minExtent;
        final t = delta <= 0
            ? 0.0
            : (1 - (current - minExtent) / delta).clamp(0.0, 1.0);

        final alignment = Alignment.lerp(
          const Alignment(0, -0.15),
          const Alignment(0, -1),
          t,
        )!;

        final veilTop = 0.30 + 0.34 * t;
        final veilMid = 0.06 + 0.46 * t;
        final veilLow = 0.72 + 0.16 * t;
        const veilBottom = 0.92;
        final lockupOpacity = (1 - t * 1.7).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF151515))),
            Positioned.fill(
              child: HubHeroPhoto(
                slot: HubHeroSlot.tv,
                alignment: alignment,
                fallbackAsset: _heroAsset,
                cacheWidth: tvHeroCacheWidth(context),
                filterQuality: FilterQuality.low,
                fallback: Container(
                  color: const Color(0xFF151515),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.live_tv_rounded,
                    size: 40,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: veilTop),
                      Colors.black.withValues(alpha: veilMid),
                      Colors.black.withValues(alpha: veilLow),
                      Colors.black.withValues(alpha: veilBottom),
                    ],
                    stops: const [0.0, 0.34, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            if (lockupOpacity > 0)
              Positioned(
                left: TvTheme.gutter,
                right: TvTheme.gutter,
                bottom: lockupBottom,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 44, height: 3, color: TvTheme.accent),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TvType.masthead,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TvType.caption.copyWith(
                          color: TvTheme.heroTextMuted,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

abstract final class TvHeroSliver {
  static const double expandedBody = 168;
  static const double accentStripeHeight = 3;
  static const double toolbarHeight = 48;

  static SliverAppBar build(
    BuildContext context, {
    String title = 'DVCR TV',
    String subtitle = 'Replays, émissions, Shorts et moments du club.',
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight:
          topPad + toolbarHeight + expandedBody + accentStripeHeight,
      stretch: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      title: const TvHeroPinnedToolbar(),
      clipBehavior: Clip.hardEdge,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          TvHeroFlexibleSpace(
            title: title,
            subtitle: subtitle,
            lockupBottom: 20,
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: accentStripeHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: TvTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
