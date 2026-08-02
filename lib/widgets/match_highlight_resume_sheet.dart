import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../services/match_highlight_service.dart';
import '../services/match_media_stats_service.dart';

/// Lecteur séquentiel des clips vMix du match (« résumé »).
Future<void> showMatchHighlightResume(
  BuildContext context, {
  required String matchId,
  required List<MatchHighlightClip> clips,
}) async {
  if (clips.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.78,
      child: _MatchHighlightResumePlayer(
        matchId: matchId,
        clips: clips,
      ),
    ),
  );
}

class _MatchHighlightResumePlayer extends StatefulWidget {
  final String matchId;
  final List<MatchHighlightClip> clips;

  const _MatchHighlightResumePlayer({
    required this.matchId,
    required this.clips,
  });

  @override
  State<_MatchHighlightResumePlayer> createState() =>
      _MatchHighlightResumePlayerState();
}

class _MatchHighlightResumePlayerState
    extends State<_MatchHighlightResumePlayer> {
  late int _index;
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _index = 0;
    _loadCurrent();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  MatchHighlightClip get _clip => widget.clips[_index];

  Future<void> _loadCurrent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final old = _controller;
    old?.removeListener(_onTick);
    await old?.dispose();
    _controller = null;

    final clip = _clip;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(clip.videoUrl));
    try {
      await ctrl.initialize();
      ctrl.addListener(_onTick);
      await ctrl.play();
      // Compte 1 play par clip au démarrage du résumé / lecture.
      MatchMediaStatsService.instance.incrementVideoPlay(
        matchId: widget.matchId,
        eventId: clip.eventId,
      );
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _loading = false;
      });
    } catch (e) {
      await ctrl.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Lecture impossible';
        });
      }
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos >= dur - const Duration(milliseconds: 350)) {
      c.removeListener(_onTick);
      _next();
    }
  }

  Future<void> _next() async {
    if (_index >= widget.clips.length - 1) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _index++);
    await _loadCurrent();
  }

  Future<void> _prev() async {
    if (_index <= 0) return;
    setState(() => _index--);
    await _loadCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    final title = [
      if (clip.minute > 0) "${clip.minute}'",
      if (clip.player.isNotEmpty) clip.player,
      if (clip.type.isNotEmpty) clip.type,
    ].join(' · ');

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÉSUMÉ DU MATCH',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFC9A84C),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${_index + 1} / ${widget.clips.length}'
                        '${title.isEmpty ? '' : ' · $title'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Color(0xFFC9A84C))
                  : _error != null
                      ? Text(_error!,
                          style: GoogleFonts.inter(color: Colors.orangeAccent))
                      : _controller == null
                          ? const SizedBox.shrink()
                          : AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio == 0
                                  ? 16 / 9
                                  : _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _index > 0 ? _prev : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final c = _controller;
                      if (c == null) return;
                      if (c.value.isPlaying) {
                        await c.pause();
                      } else {
                        await c.play();
                      }
                      setState(() {});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      (_controller?.value.isPlaying ?? false)
                          ? 'Pause'
                          : 'Lecture',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _next,
                  icon: const Icon(Icons.skip_next_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
