part of 'home_screen.dart';

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
            padding: const EdgeInsets.only(left: 14, right: 4),
            itemCount: videos.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
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

class _HomeTVCardPremium extends StatelessWidget {
  final VideoModel video;
  final String subLabel;
  final VoidCallback onTap;

  const _HomeTVCardPremium({
    required this.video,
    required this.subLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = video.youtubeThumbnail;
    final metaLabel = _homeVideoMetaLabel(video);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _kCard,
                        child: Center(
                          child: Icon(
                            Icons.sports_soccer_rounded,
                            color: _kRed.withAlpha(90),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(160),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white60, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    if (video.duration.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subLabel.isNotEmpty)
                    Text(
                      subLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFFC8A436),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (subLabel.isNotEmpty) const SizedBox(height: 4),
                  SizedBox(
                    height: 34,
                    child: Text(
                      video.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        height: 1.18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: _kGrey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metaLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _homeVideoCategoryLabel(String category) {
  switch (category) {
    case 'resume':
      return 'Resume des matchs';
    case 'podcast':
      return 'Emission DVCR';
    case 'matchday':
      return 'Jour de match';
    case 'all':
    case 'ALL':
    case '':
      return '';
    default:
      return '';
  }
}

Future<List<VideoModel>> _loadHomeDvcrTvVideos() async {
  final results = await Future.wait([
    YoutubePlaylistService.getMatchday(),
    YoutubePlaylistService.getResumes(),
  ]);
  final all = results.expand((videos) => videos).toList();
  final seen = <String>{};
  final unique = all.where((video) => seen.add(video.youtubeId)).toList();
  unique.sort((a, b) => b.date.compareTo(a.date));
  return unique;
}

String _homeVideoMetaLabel(VideoModel video) {
  final d = video.date;
  final months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
