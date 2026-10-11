part of '../home_screen.dart';

class _ResultsFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: const HomeMatchCatalogAdapter().listenable,
      builder: (context, _) {
        final raw = const HomeMatchCatalogAdapter().results;
        final matches = raw.where(_isSedanMatch).take(3).toList();

        if (matches.isEmpty) {
          return const _HomeResultsEmpty();
        }

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

class _HomeResultsEmpty extends StatelessWidget {
  const _HomeResultsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        'Aucun score en cache. Les résultats officiels s’affichent ici après synchro FFF — on n’invente rien.',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          color: _kGrey,
        ),
      ),
    );
  }
}
