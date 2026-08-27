import 'package:flutter/material.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../../../widgets/dvcr_reveal.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';

/// Nameplate magazine sur la photo (onglets Accueil, Matchs, Progression…).
class PronoTabHeroPinnedToolbar extends StatelessWidget {
  final PronoPageAccent pageAccent;

  const PronoTabHeroPinnedToolbar({
    super.key,
    required this.pageAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: pageAccent.color),
          const SizedBox(width: 8),
          Text('PRONOS', style: PronoType.nameplate),
        ],
      ),
    );
  }
}

class PronoTabHeroFlexibleSpace extends StatelessWidget {
  final String title;
  final String subtitle;
  final PronoPageAccent pageAccent;
  final String? heroImageUrl;
  final int revisionMillis;

  static const _heroAsset =
      'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg';

  const PronoTabHeroFlexibleSpace({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pageAccent,
    this.heroImageUrl,
    this.revisionMillis = 0,
  });

  Widget _assetImage(Alignment alignment) {
    return Image.asset(
      _heroAsset,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: pageAccent.deep,
        child: Center(
          child: Icon(
            Icons.stadium_rounded,
            size: 40,
            color: PronoArenaTheme.heroTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _heroImage(BuildContext context, Alignment alignment) {
    final url = (heroImageUrl ?? '').trim();
    if (url.isEmpty) return _assetImage(alignment);
    final busted = cacheBustedImageUrl(url, revisionMillis);
    // Pas d’asset en dessous : c’est la photo Accueil (même JPEG) qui
    // restait une frame sur Matchs le temps du décodage.
    return DvcrNetworkImage(
      busted,
      key: ValueKey('prono-hero-${pageAccent.name}-$busted'),
      fit: BoxFit.cover,
      alignment: alignment,
      cacheWidth: dvcrStadiumCacheWidth(context),
      filterQuality: FilterQuality.medium,
      gaplessPlayback: false,
      placeholder: ColoredBox(color: pageAccent.deep),
      errorBuilder: (_, __, ___) => _assetImage(alignment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rule = pageAccent == PronoPageAccent.progression
        ? PronoArenaTheme.gold
        : pageAccent.color;

    // On n’utilise PAS FlexibleSpaceBar : il applique une opacité décroissante
    // à son `background`, si bien qu’en position repliée la photo disparaît et
    // laisse voir le `backgroundColor` du SliverAppBar — l’aplat vert plein.
    // Ici la photo est peinte à pleine opacité quel que soit le repli ; seuls
    // le cadrage, le voile et le lockup de titre suivent la progression.
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
        // Offstage / 1er layout : l’app bar peut se croire repliée alors que
        // le scroll est à 0. On garde alors le cadrage déployé, sinon la
        // photo saute (crop haut) en passant Accueil → Matchs.
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
        final veilBottom = 0.92;
        final lockupOpacity = ((1 - visualT * 1.7)).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: ColoredBox(color: pageAccent.deep)),
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
                left: PronoArenaTheme.gutter,
                right: PronoArenaTheme.gutter,
                bottom: 20,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 44, height: 3, color: rule),
                      const SizedBox(height: 12),
                      Text(
                        PronoArenaTheme.heroKicker(pageAccent),
                        style: PronoType.kickerOnPhoto,
                      ),
                      const SizedBox(height: 7),
                      Text(title, style: PronoType.masthead),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: PronoType.caption.copyWith(
                          color: PronoArenaTheme.heroTextMuted,
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

abstract final class PronoTabHeroSliver {
  static const Color _sheetTop = PronoTokens.scaffoldBottom;
  static const double _expandedBody = 168;
  static const double _accentStripeHeight = 3;

  /// Hero Pronos. Passe [bannerSlot] pour charger l’URL Firestore
  /// (`app_config/prono_banners`), ou [heroImageUrl] pour une URL fixe.
  static Widget build(
    BuildContext context, {
    required String title,
    required String subtitle,
    required PronoPageAccent pageAccent,
    PronoBannerSlot? bannerSlot,
    String? heroImageUrl,
    int revisionMillis = 0,
  }) {
    if (bannerSlot != null) {
      return StreamBuilder<PronoBannersSettings>(
        stream: AppSettingsService.pronoBannersStream(),
        initialData: AppSettingsService.lastKnownPronoBanners,
        builder: (context, snap) {
          final banners = snap.data ?? PronoBannersSettings.defaults;
          return _sliverAppBar(
            context,
            title: title,
            subtitle: subtitle,
            pageAccent: pageAccent,
            heroImageUrl: banners.urlForSlot(bannerSlot),
            revisionMillis: banners.revisionMillis,
          );
        },
      );
    }
    return _sliverAppBar(
      context,
      title: title,
      subtitle: subtitle,
      pageAccent: pageAccent,
      heroImageUrl: heroImageUrl,
      revisionMillis: revisionMillis,
    );
  }

  static SliverAppBar _sliverAppBar(
    BuildContext context, {
    required String title,
    required String subtitle,
    required PronoPageAccent pageAccent,
    String? heroImageUrl,
    int revisionMillis = 0,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + 48 + _expandedBody + _accentStripeHeight,
      stretch: false,
      // Transparent : c'est le flexibleSpace qui peint la photo sur toute la
      // hauteur, y compris replié. Une couleur ici réapparaîtrait en aplat.
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 48,
      titleSpacing: 0,
      title: PronoTabHeroPinnedToolbar(pageAccent: pageAccent),
      clipBehavior: Clip.hardEdge,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          PronoTabHeroFlexibleSpace(
            key: ValueKey(
              'prono-hero-${pageAccent.name}-${heroImageUrl ?? ''}-$revisionMillis',
            ),
            title: title,
            subtitle: subtitle,
            pageAccent: pageAccent,
            heroImageUrl: heroImageUrl,
            revisionMillis: revisionMillis,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _accentStripeHeight,
            child: DecoratedBox(
              decoration: PronoArenaTheme.heroAccentStripe(pageAccent),
            ),
          ),
        ],
      ),
    );
  }

  static Widget sheetLeadInSliver({double height = 0}) {
    return SliverToBoxAdapter(
      child: DVCRReveal(
        duration: PronoTokens.animFast,
        offsetY: 8,
        child: ColoredBox(
          color: _sheetTop,
          child: SizedBox(height: height),
        ),
      ),
    );
  }
}
