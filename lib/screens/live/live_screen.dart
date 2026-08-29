import 'package:flutter/material.dart';

import '../../navigation/main_shell_insets.dart';
import '../../services/app_settings_service.dart';
import '../../services/youtube_playlist_service.dart';
import '../../widgets/donation_banner.dart';
import '../../widgets/quiz_raffle_live_card.dart';
import '../../widgets/dvcr_reveal.dart';
import 'adherent_vod_section.dart';
import 'live_widgets.dart';
import 'theme/tv_theme.dart';
import 'widgets/tv_hero_sliver.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  int _refreshToken = 0;

  Future<void> _onRefresh() async {
    try {
      await YoutubePlaylistService.refreshIncremental();
      await YoutubePlaylistService.getShorts(preferComplete: true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvTheme.scaffold,
      body: RefreshIndicator(
        color: TvTheme.greenBright,
        backgroundColor: TvTheme.surface,
        displacement: 72,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            TvHeroSliver.build(context),
            SliverToBoxAdapter(
              child: DVCRReveal(
                duration: const Duration(milliseconds: 480),
                offsetY: 22,
                child: ColoredBox(
                  color: TvTheme.scaffold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      const QuizRaffleLiveSlot(),
                      LiveSpotlight(refreshToken: _refreshToken),
                      const SizedBox(height: 22),
                      LiveShortsRail(refreshToken: _refreshToken),
                      LiveAdherentVodSection(refreshToken: _refreshToken),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                refreshToken: _refreshToken,
                title: 'Dernières vidéos',
                category: 'all',
                subtitle: 'Le fil de la chaîne — hors Shorts',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DonationBanner(
                  slot: SoutenezDvcrBannerSlot.live,
                  compact: true,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                refreshToken: _refreshToken,
                title: 'Jour de match',
                category: 'matchday',
                subtitle: 'Ambiance, coulisses et avant-match',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Résumés de matchs',
                refreshToken: _refreshToken,
                category: 'resume',
                subtitle: 'Les temps forts en condensé',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Émissions & podcasts',
                refreshToken: _refreshToken,
                category: 'podcast',
                subtitle: 'Talks, débriefs et formats longs',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MainShellInsets.tabScrollTail(context)),
            ),
          ],
        ),
      ),
    );
  }
}
