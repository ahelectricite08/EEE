import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../utils/remote_image_url.dart';
import '../../../widgets/dvcr_network_image.dart';
import '../theme/calendar_theme.dart';
import '../theme/calendar_type.dart';

/// Nameplate épinglé — visible au repli, sur la photo (jamais un aplat).
class CalendarHeroPinnedToolbar extends StatelessWidget {
  final String nameplate;
  final Widget? trailing;

  const CalendarHeroPinnedToolbar({
    super.key,
    this.nameplate = 'CALENDRIER',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: CalendarTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nameplate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CalendarType.nameplate,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Photo hero du calendrier. Pas de [FlexibleSpaceBar] : il tue l’opacité
/// au repli et laisse un rectangle vert. Ici la photo reste peinte.
class CalendarHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String subtitle;
  final String kicker;
  final String? heroImageUrl;
  final int revisionMillis;
  final String fallbackAsset;
  final String? fallbackNetworkUrl;
  final double lockupBottom;

  static const _defaultAsset = 'assets/images/IMG_0842.JPG';

  const CalendarHeroFlexibleSpace({
    super.key,
    required this.title,
    required this.subtitle,
    this.kicker = 'CSSA',
    this.heroImageUrl,
    this.revisionMillis = 0,
    this.fallbackAsset = _defaultAsset,
    this.fallbackNetworkUrl,
    this.lockupBottom = 20,
  });

  Widget _fallback(BuildContext context, Alignment alignment) {
    final net = (fallbackNetworkUrl ?? '').trim();
    if (net.isNotEmpty) {
      return DvcrNetworkImage(
        net,
        key: ValueKey(net),
        fit: BoxFit.cover,
        alignment: alignment,
        cacheWidth: dvcrStadiumCacheWidth(context),
        gaplessPlayback: false,
        errorBuilder: (_, __, ___) => _asset(alignment),
      );
    }
    return _asset(alignment);
  }

  Widget _asset(Alignment alignment) {
    return Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: CalendarTheme.ink,
        child: Center(
          child: Icon(
            Icons.stadium_rounded,
            size: 40,
            color: CalendarTheme.heroTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _heroImage(BuildContext context, Alignment alignment) {
    final url = (heroImageUrl ?? '').trim();
    if (url.isEmpty) return _fallback(context, alignment);
    final busted = cacheBustedImageUrl(url, revisionMillis);
    return DvcrNetworkImage(
      busted,
      key: ValueKey('calendar-hero-$busted'),
      fit: BoxFit.cover,
      alignment: alignment,
      cacheWidth: dvcrStadiumCacheWidth(context),
      gaplessPlayback: false,
      placeholder: const ColoredBox(color: CalendarTheme.ink),
      errorBuilder: (_, __, ___) => _fallback(context, alignment),
    );
  }

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
        final scrollPixels =
            Scrollable.maybeOf(context)?.position.pixels ?? 0;
        final visualT = scrollPixels <= 0.5 ? 0.0 : t;

        final alignment = Alignment.lerp(
          const Alignment(0, -0.18),
          const Alignment(0, -1),
          visualT,
        )!;

        final veilTop = 0.30 + 0.34 * visualT;
        final veilMid = 0.06 + 0.46 * visualT;
        final veilLow = 0.72 + 0.16 * visualT;
        const veilBottom = 0.92;
        final lockupOpacity = (1 - visualT * 1.7).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: CalendarTheme.ink)),
            Positioned.fill(child: _heroImage(context, alignment)),
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
                left: CalendarTheme.gutter,
                right: CalendarTheme.gutter,
                bottom: lockupBottom,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 44, height: 3, color: CalendarTheme.accent),
                      const SizedBox(height: 12),
                      Text(kicker, style: CalendarType.kickerOnPhoto),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CalendarType.masthead,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: CalendarType.caption.copyWith(
                          color: CalendarTheme.heroTextMuted,
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

/// Hero calendrier — photo admin `HubHeroSlot.calendar`, même pipeline hub_heroes.
abstract final class CalendarHeroSliver {
  static const double expandedBody = 168;
  static const double accentStripeHeight = 3;
  static const double toolbarHeight = 48;

  static const _fallbackNetwork =
      'https://static.wixstatic.com/media/4ebc61_12bf15e736a344ba8bd86f482cc37aac~mv2.jpg';

  static Widget build(
    BuildContext context, {
    required String title,
    required String subtitle,
    String kicker = 'CSSA',
    String nameplate = 'CALENDRIER',
    Widget? toolbarAction,
    PreferredSizeWidget? bottom,
  }) {
    return StreamBuilder<HubHeroBannersSettings>(
      stream: AppSettingsService.hubHeroBannersStream(),
      initialData: AppSettingsService.lastKnownHubHeroBanners,
      builder: (context, snap) {
        final banners =
            snap.data ?? AppSettingsService.lastKnownHubHeroBanners;
        return _sliverAppBar(
          context,
          title: title,
          subtitle: subtitle,
          kicker: kicker,
          nameplate: nameplate,
          toolbarAction: toolbarAction,
          bottom: bottom,
          heroImageUrl: banners.urlForSlot(HubHeroSlot.calendar),
          revisionMillis: banners.revisionMillis,
        );
      },
    );
  }

  static SliverAppBar sliverAppBar(
    BuildContext context, {
    required String title,
    required String subtitle,
    String kicker = 'CSSA',
    String nameplate = 'CALENDRIER',
    Widget? toolbarAction,
    PreferredSizeWidget? bottom,
    String? heroImageUrl,
    int revisionMillis = 0,
  }) {
    return _sliverAppBar(
      context,
      title: title,
      subtitle: subtitle,
      kicker: kicker,
      nameplate: nameplate,
      toolbarAction: toolbarAction,
      bottom: bottom,
      heroImageUrl: heroImageUrl,
      revisionMillis: revisionMillis,
    );
  }

  static SliverAppBar _sliverAppBar(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String kicker,
    required String nameplate,
    Widget? toolbarAction,
    PreferredSizeWidget? bottom,
    String? heroImageUrl,
    int revisionMillis = 0,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomH = bottom?.preferredSize.height ?? 0;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + toolbarHeight + expandedBody + accentStripeHeight + bottomH,
      stretch: false,
      automaticallyImplyLeading: false,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      title: CalendarHeroPinnedToolbar(
        nameplate: nameplate,
        trailing: toolbarAction,
      ),
      clipBehavior: Clip.hardEdge,
      bottom: bottom,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          // Photo = bande hero seulement (toolbar + 168), pas derrière le
          // bandeau papier. Sinon le BoxFit.cover recadre plus haut qu’en
          // Pronos et la photo « saute » en passant Pronos → Calendrier.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: bottomH,
            child: CalendarHeroFlexibleSpace(
              key: ValueKey(
                'calendar-hero-${heroImageUrl ?? ''}-$revisionMillis',
              ),
              title: title,
              subtitle: subtitle,
              kicker: kicker,
              heroImageUrl: heroImageUrl,
              revisionMillis: revisionMillis,
              fallbackNetworkUrl: _fallbackNetwork,
              lockupBottom: 20,
            ),
          ),
          Positioned(
            bottom: bottomH,
            left: 0,
            right: 0,
            height: accentStripeHeight,
            child: DecoratedBox(
              decoration: CalendarTheme.heroAccentStripe(),
            ),
          ),
        ],
      ),
    );
  }
}
