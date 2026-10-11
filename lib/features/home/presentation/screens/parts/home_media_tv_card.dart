part of '../home_screen.dart';

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
        decoration: HomeTheme.paper(),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DvcrNetworkImage(
                      thumb,
                      fit: BoxFit.cover,
                      cacheWidth: _homeHeroCacheWidth(context),
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => Container(
                        color: _kBg,
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: _kGrey, size: 32),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withAlpha(155), Colors.transparent],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 1.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    if (video.duration.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(video.duration,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MediaResumeThumbProgress.video(video.cleanId),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subLabel.isNotEmpty) ...[
                    Text(
                      subLabel.toUpperCase(),
                      style: HomeType.kicker.copyWith(
                        color: HomeTheme.greenBright,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  SizedBox(
                    height: 36,
                    child: Text(
                      video.title,
                      style: HomeType.title.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metaLabel,
                    style: HomeType.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
