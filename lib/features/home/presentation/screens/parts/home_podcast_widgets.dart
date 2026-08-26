part of '../home_screen.dart';

class _PodcastSection extends StatefulWidget {
  const _PodcastSection();

  @override
  State<_PodcastSection> createState() => _PodcastSectionState();
}

class _PodcastSectionState extends State<_PodcastSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playingEdge;

  @override
  void initState() {
    super.initState();
    _playingEdge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    PodcastController.instance.addListener(_syncPlayingEdge);
    _syncPlayingEdge();
  }

  void _syncPlayingEdge() {
    final c = PodcastController.instance;
    if (c.isPlaying) {
      if (!_playingEdge.isAnimating) {
        _playingEdge.repeat(reverse: true);
      }
    } else {
      _playingEdge.stop();
      _playingEdge.value = 0;
    }
  }

  @override
  void dispose() {
    PodcastController.instance.removeListener(_syncPlayingEdge);
    _playingEdge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        if (ctrl.isLoading) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: homeGreen,
                ),
              ),
            ),
          );
        }
        if (ctrl.episodes.isEmpty) return const SizedBox();

        return SizedBox(
          height: 148,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 4, 6, 8),
            physics: const BouncingScrollPhysics(),
            itemCount: ctrl.episodes.length,
            itemBuilder: (context, i) {
              final ep = ctrl.episodes[i];
              final isActive = ctrl.currentIndex == i;
              final playingHere = isActive && ctrl.isPlaying;

              Widget playIconBox() => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isActive ? homeGreen : homeBg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      playingHere
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: isActive ? Colors.white : homeGreen,
                      size: 22,
                    ),
                  );

              final iconLeading = playingHere
                  ? AnimatedBuilder(
                      animation: _playingEdge,
                      builder: (_, __) => Transform.scale(
                        scale: 1 + 0.04 * _playingEdge.value,
                        child: playIconBox(),
                      ),
                    )
                  : playIconBox();

              return HomeScaleOnPress(
                minScale: 0.982,
                child: GestureDetector(
                  onTap: () => ctrl.togglePlay(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: 238,
                    margin: const EdgeInsets.only(right: 10, bottom: 2),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: HomeTheme.paper(
                      edge: isActive ? homeGreen.withAlpha(90) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            iconLeading,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _relDate(ep.pubDate),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? homeGreen
                                      : homeText.withAlpha(120),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            ep.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: homeText,
                              height: 1.05,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ep.duration,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? homeGreen : homeMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
