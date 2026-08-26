import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_settings_service.dart';
import '../../widgets/hub_hero_photo.dart';

const _kIvory = Color(0xFFF4F0E6);
const _kGreen = Color(0xFF167A5F);

int socialHeroCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

/// Nameplate épinglé — reste sur la photo au repli.
class SocialHeroPinnedToolbar extends StatelessWidget {
  const SocialHeroPinnedToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: _kGreen),
        const SizedBox(width: 8),
        Text(
          'DVCR · RÉSEAUX',
          style: GoogleFonts.barlowCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Photo hero. Pas de [FlexibleSpaceBar] : il tue l’opacité au repli.
class SocialHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String subtitle;
  final String kicker;
  final double lockupBottom;

  static const fallbackAsset = 'assets/images/IMG_0842.JPG';

  const SocialHeroFlexibleSpace({
    super.key,
    this.title = 'NOS RÉSEAUX',
    this.subtitle =
        'Les adresses officielles DVCR — YouTube, Facebook, site, podcasts.',
    this.kicker = 'DVCR',
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
          const Alignment(0, -0.18),
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
                slot: HubHeroSlot.reseaux,
                alignment: alignment,
                fallbackAsset: fallbackAsset,
                cacheWidth: socialHeroCacheWidth(context),
                filterQuality: FilterQuality.low,
                fallback: const ColoredBox(color: Color(0xFF151515)),
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
                left: 20,
                right: 20,
                bottom: lockupBottom,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 44, height: 3, color: _kGreen),
                      const SizedBox(height: 10),
                      Text(
                        kicker,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.85,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 0.92,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.25,
                        ),
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

abstract final class SocialHeroSliver {
  static const double expandedBody = 198;
  static const double toolbarHeight = 52;

  static SliverAppBar build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + toolbarHeight + expandedBody,
      stretch: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      title: const SocialHeroPinnedToolbar(),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      flexibleSpace: const ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SocialHeroFlexibleSpace(),
      ),
    );
  }
}

const kSocialIvory = _kIvory;
