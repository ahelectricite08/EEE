part of '../home_screen.dart';

class _DVCRTVRow extends StatefulWidget {
  @override
  State<_DVCRTVRow> createState() => _DVCRTVRowState();
}

class _DVCRTVRowState extends State<_DVCRTVRow> {
  late Future<List<VideoModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadHomeDvcrTvVideos();
  }

  void _reload() {
    setState(() {
      _future = _loadHomeDvcrTvVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoModel>>(
      future: _future,
      builder: (context, snap) {
        final cardW = MediaQuery.of(context).size.width * 0.465;
        final totalH = cardW * (9 / 16) + 110;

        if (!snap.hasData && !snap.hasError) {
          return SizedBox(
            height: totalH,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 20, right: 8),
              children: const [
                SizedBox(width: 180, child: DVCRCardSkeleton()),
                SizedBox(width: 10),
                SizedBox(width: 180, child: DVCRCardSkeleton()),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return EmptyStatePanel(
            icon: Icons.live_tv_rounded,
            title: 'DVCR TV indisponible',
            subtitle: 'Impossible de charger les videos pour le moment.',
            actionLabel: 'REESSAYER',
            onAction: _reload,
          );
        }

        final videos = snap.data ?? const <VideoModel>[];
        if (videos.isEmpty) {
          return const EmptyStatePanel(
            icon: Icons.video_library_outlined,
            title: 'Aucune video disponible',
            subtitle: 'Les prochaines videos DVCR TV apparaitront ici.',
          );
        }

        return SizedBox(
          height: totalH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 18, right: 6),
            itemCount: videos.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: cardW,
                child: _HomeTVCardPremium(
                  video: videos[i],
                  subLabel: _normalizeSubLabel(
                    _homeVideoCategoryLabel(videos[i].category),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NativeVideoScreen(
                        videoId: videos[i].cleanId,
                        title: videos[i].title,
                        video: videos[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalizeSubLabel(String value) {
    if (value.contains('2024/25') || value.contains('2024-25')) {
      return 'Resume des matchs';
    }
    return value;
  }
}
