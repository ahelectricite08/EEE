import 'package:flutter/material.dart';

import '../../services/youtube_playlist_service.dart';
import '../../widgets/donation_banner.dart';
import '../../widgets/dvcr_reveal.dart';
import 'live_palette.dart';
import 'live_widgets.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  int _refreshToken = 0;

  Future<void> _onRefresh() async {
    try {
      await YoutubePlaylistService.refreshAllFeeds();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: kLiveSheet,
      body: RefreshIndicator(
        color: kLiveGold,
        backgroundColor: kLiveGreenDeep,
        displacement: 72,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: topPad + 52 + 228,
              stretch: true,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 52,
              titleSpacing: 0,
              title: const LiveHeroPinnedToolbar(),
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              flexibleSpace: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: const LiveHeroFlexibleSpace(),
              ),
            ),
            SliverToBoxAdapter(
              child: DVCRReveal(
                duration: const Duration(milliseconds: 480),
                offsetY: 22,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: ColoredBox(
                    color: kLiveSheet,
                    child: Column(
                      children: [
                        LiveSpotlight(refreshToken: _refreshToken),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: DonationBanner(
                            donationUrl: 'https://www.helloasso.com',
                            photoAsset:
                                'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                            title: 'SOUTENEZ DVCR',
                            subtitle: 'Chaque don nous aide à grandir',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                refreshToken: _refreshToken,
                title: 'Dernières vidéos',
                category: 'all',
                subtitle: 'Toute la chaîne DVCR TV, claire et accessible.',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                refreshToken: _refreshToken,
                title: 'Jour de match',
                category: 'matchday',
                subtitle:
                    'L\'ambiance, les coulisses et les rendez-vous terrain.',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Émissions et podcasts',
                refreshToken: _refreshToken,
                category: 'podcast',
                subtitle: 'Les formats discussion, plateau et audio.',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Résumés de matchs',
                refreshToken: _refreshToken,
                category: 'resume',
                subtitle: 'Les résumés et temps forts à revoir rapidement.',
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}
