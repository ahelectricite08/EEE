part of '../home_screen.dart';

class _ResultsFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: const HomeMatchCatalogAdapter().listenable,
      builder: (context, _) {
        final raw = const HomeMatchCatalogAdapter().results.isNotEmpty
            ? const HomeMatchCatalogAdapter().results
            : MatchModel.mockResults;
        final matches = raw.where(_isSedanMatch).take(3).toList();

        return Column(
          children: matches
              .map(
                (m) => _HomeResultCard(
                  match: m,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(match: m),
                    ),
                  ),
                  onReplay: m.replayVideoId != null
                      ? () {
                          final video = VideoModel(
                            id: m.id,
                            title: '${m.team1} - ${m.team2}',
                            youtubeId: m.replayVideoId!,
                            duration: '',
                            date: m.date,
                            category: 'resume',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoWebScreen(video: video),
                            ),
                          );
                        }
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
