import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../../utils/remote_image_url.dart';
import '../../widgets/hub_hero_photo.dart';
import '../home/home_shell_widgets.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

/// Nameplate épinglé — visible au repli, sur la photo (jamais un aplat).
class ProfileHeroPinnedToolbar extends StatelessWidget {
  const ProfileHeroPinnedToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: profileGreenBright),
          const SizedBox(width: 8),
          Text('PROFIL', style: ProfileType.nameplate),
        ],
      ),
    );
  }
}

/// Fond hero Profil. Pas de [FlexibleSpaceBar] : la photo reste peinte.
/// Carrousel 3 fonds (`app_config/profile_hero`) + fallback [HubHeroSlot.profile].
class ProfileHeroFlexibleSpace extends StatelessWidget {
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final Widget lockup;

  const ProfileHeroFlexibleSpace({
    super.key,
    required this.initialIndex,
    required this.onPageChanged,
    required this.lockup,
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
          const Alignment(0, -0.28),
          const Alignment(0, -1),
          t,
        )!;
        final veilTop = 0.30 + 0.34 * t;
        final veilMid = 0.06 + 0.46 * t;
        final veilLow = 0.72 + 0.16 * t;
        const veilBottom = 0.92;
        final lockupOpacity = (1 - t * 1.7).clamp(0.0, 1.0);

        return StreamBuilder<HubHeroBannersSettings>(
          stream: AppSettingsService.hubHeroBannersStream(),
          builder: (context, hubSnap) {
            final hub = hubSnap.data ?? HubHeroBannersSettings.defaults;
            return StreamBuilder<ProfileHeroBackgroundSettings>(
              stream: AppSettingsService.profileHeroBackgroundsStream(),
              builder: (context, cfgSnap) {
                final cfg = cfgSnap.data ?? ProfileHeroBackgroundSettings.defaults;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF151515)),
                    ),
                    Positioned.fill(
                      child: _ProfileHeroCarousel(
                        urls: cfg.urls,
                        revisionMillis: cfg.revisionMillis,
                        hubFallbackUrl: hub.urlForSlot(HubHeroSlot.profile),
                        hubRevisionMillis: hub.revisionMillis,
                        initialIndex: initialIndex,
                        alignment: alignment,
                        onPageChanged: onPageChanged,
                        showDots: lockupOpacity > 0.35,
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
                        bottom: 18,
                        child: IgnorePointer(
                          child: Opacity(opacity: lockupOpacity, child: lockup),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProfileHeroCarousel extends StatefulWidget {
  const _ProfileHeroCarousel({
    required this.urls,
    required this.revisionMillis,
    required this.hubFallbackUrl,
    required this.hubRevisionMillis,
    required this.initialIndex,
    required this.alignment,
    required this.onPageChanged,
    required this.showDots,
  });

  final List<String> urls;
  final int revisionMillis;
  final String hubFallbackUrl;
  final int hubRevisionMillis;
  final int initialIndex;
  final Alignment alignment;
  final ValueChanged<int> onPageChanged;
  final bool showDots;

  @override
  State<_ProfileHeroCarousel> createState() => _ProfileHeroCarouselState();
}

class _ProfileHeroCarouselState extends State<_ProfileHeroCarousel> {
  late PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, 2);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(covariant _ProfileHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final next = widget.initialIndex.clamp(0, 2);
      if (_page != next && _pageController.hasClients) {
        _pageController.jumpToPage(next);
        setState(() => _page = next);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _pageImage(String url) {
    final trimmed = url.trim();
    final cacheW = profileImageCacheWidth(
      context,
      MediaQuery.sizeOf(context).width,
    );
    if (trimmed.isNotEmpty && !shouldSkipNetworkImageUrl(trimmed)) {
      return Image.network(
        cacheBustedImageUrl(trimmed, widget.revisionMillis),
        fit: BoxFit.cover,
        alignment: widget.alignment,
        gaplessPlayback: true,
        headers: kDvcrImageHttpHeaders,
        cacheWidth: cacheW,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _hubOrAsset(),
      );
    }
    return _hubOrAsset();
  }

  Widget _hubOrAsset() {
    final hub = widget.hubFallbackUrl.trim();
    if (hub.isNotEmpty) {
      return HubHeroPhoto(
        slot: HubHeroSlot.profile,
        alignment: widget.alignment,
        fallbackAsset: ProfileHeroBackgroundSettings.defaultAssetPath,
        cacheWidth: profileImageCacheWidth(
          context,
          MediaQuery.sizeOf(context).width,
        ),
        filterQuality: FilterQuality.low,
        fallback: Image.asset(
          ProfileHeroBackgroundSettings.defaultAssetPath,
          fit: BoxFit.cover,
          alignment: widget.alignment,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF151515)),
        ),
      );
    }
    return Image.asset(
      ProfileHeroBackgroundSettings.defaultAssetPath,
      fit: BoxFit.cover,
      alignment: widget.alignment,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF151515)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.urls.length >= 3
        ? widget.urls
        : [...widget.urls, ...List.filled(3 - widget.urls.length, '')];

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          controller: _pageController,
          physics: const PageScrollPhysics(),
          onPageChanged: (i) {
            setState(() => _page = i);
            widget.onPageChanged(i);
          },
          children: [
            _pageImage(u[0]),
            _pageImage(u[1]),
            _pageImage(u[2]),
          ],
        ),
        if (widget.showDots)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = _page == i;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_page == i) return;
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Construit le [SliverAppBar] Profil (photo pleine opacité au repli).
abstract final class ProfileHeroSliver {
  static const double toolbarHeight = 52;
  static const double expandedBody = 248;

  static SliverAppBar build(
    BuildContext context, {
    required int initialIndex,
    required ValueChanged<int> onPageChanged,
    required Widget lockup,
    required VoidCallback onBack,
    required VoidCallback onNotifications,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: topPad + toolbarHeight + expandedBody,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      forceMaterialTransparency: true,
      toolbarHeight: toolbarHeight,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leadingWidth: 52,
      titleSpacing: 0,
      leading: Center(
        child: HomeToolbarButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
      ),
      title: const ProfileHeroPinnedToolbar(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: HomeToolbarButton(
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
          ),
        ),
      ],
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ProfileHeroFlexibleSpace(
          initialIndex: initialIndex,
          onPageChanged: onPageChanged,
          lockup: lockup,
        ),
      ),
    );
  }
}
