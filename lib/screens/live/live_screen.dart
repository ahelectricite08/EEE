import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/youtube_playlist_service.dart';
import '../../widgets/dvcr_reveal.dart';
import 'live_palette.dart';
import '../../widgets/donation_banner.dart';
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
      await YoutubePlaylistService.refreshIncremental();
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Text(
                            'Parcourir par thème',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kLiveMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: DonationBanner(
                            photoAsset:
                                'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
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
                title: 'Tendances sur DVCR TV',
                category: 'all',
                subtitle: '',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                refreshToken: _refreshToken,
                title: 'Jour de match',
                category: 'matchday',
                subtitle: '',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Émissions & podcasts',
                refreshToken: _refreshToken,
                category: 'podcast',
                subtitle: '',
              ),
            ),
            SliverToBoxAdapter(
              child: LiveVideoCarouselSection(
                title: 'Résumés de matchs',
                refreshToken: _refreshToken,
                category: 'resume',
                subtitle: '',
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}
