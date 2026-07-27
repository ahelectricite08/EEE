import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/dvcr_reveal.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';

/// Toolbar compacte sur le hero photo (onglets Accueil, Matchs, Progression…).
class PronoTabHeroPinnedToolbar extends StatelessWidget {
  final PronoPageAccent pageAccent;

  const PronoTabHeroPinnedToolbar({
    super.key,
    required this.pageAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PronoTokens.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PronoTokens.border),
              boxShadow: PronoArenaTheme.cardShadow,
            ),
            child: Text(
              'PRONOS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PronoTokens.textMuted,
                letterSpacing: 1.4,
              ),
            ),
          ),
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

  Widget _assetImage() {
    return Image.asset(
      _heroAsset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.12),
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

  Widget _heroImage() {
    final url = (heroImageUrl ?? '').trim();
    if (url.isEmpty) return _assetImage();
    final busted = cacheBustedImageUrl(url, revisionMillis);
    return Image.network(
      busted,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.12),
      gaplessPlayback: true,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (context, error, stackTrace) => _assetImage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroColors = PronoArenaTheme.heroGradientColors(pageAccent);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _heroImage()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: heroColors,
              ),
            ),
          ),
        ),
        FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _heroImage()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.78),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: PronoArenaTheme.heroText,
                        height: 1,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PronoArenaTheme.heroTextMuted,
                        height: 1.4,
                        letterSpacing: 0.1,
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

abstract final class PronoTabHeroSliver {
  static const Color _sheetTop = PronoTokens.scaffoldBottom;
  static const double _expandedBody = 120;
  static const double _accentStripeHeight = 2;

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
      backgroundColor: PronoTokens.scaffoldTop,
      foregroundColor: PronoTokens.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      toolbarHeight: 48,
      titleSpacing: 0,
      title: PronoTabHeroPinnedToolbar(pageAccent: pageAccent),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PronoTabHeroFlexibleSpace(
              title: title,
              subtitle: subtitle,
              pageAccent: pageAccent,
              heroImageUrl: heroImageUrl,
              revisionMillis: revisionMillis,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _accentStripeHeight,
              child: DecoratedBox(
                decoration: PronoArenaTheme.heroAccentStripe(pageAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget sheetLeadInSliver() {
    return SliverToBoxAdapter(
      child: DVCRReveal(
        duration: PronoTokens.animFast,
        offsetY: 12,
        child: ColoredBox(
          color: _sheetTop,
          child: const SizedBox(height: 8),
        ),
      ),
    );
  }
}
