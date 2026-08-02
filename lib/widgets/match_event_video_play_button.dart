import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../services/match_highlight_service.dart';
import '../services/match_media_stats_service.dart';

/// Ouvre le lecteur d’un clip highlight (fiche / but du match).
Future<void> playMatchHighlightClip(
  BuildContext context, {
  required String matchId,
  required MatchHighlightClip clip,
}) async {
  if (!clip.isReady) return;
  MatchMediaStatsService.instance.incrementVideoPlay(
    matchId: matchId,
    eventId: clip.eventId,
  );
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _SingleHighlightDialog(clip: clip),
  );
}

/// Bouton ▶ vidéo sur une ligne de fait de jeu.
class MatchEventVideoPlayButton extends StatelessWidget {
  final String matchId;
  final MatchHighlightClip? clip;
  final Color accent;
  final bool compact;

  const MatchEventVideoPlayButton({
    super.key,
    required this.matchId,
    required this.clip,
    this.accent = const Color(0xFFC9A84C),
    this.compact = false,
  });

  Future<void> _open(BuildContext context) async {
    final c = clip;
    if (c == null || !c.isReady) return;
    await playMatchHighlightClip(context, matchId: matchId, clip: c);
  }

  @override
  Widget build(BuildContext context) {
    final c = clip;
    if (c == null || !c.isReady) return const SizedBox.shrink();
    final size = compact ? 28.0 : 32.0;
    return Tooltip(
      message: c.durationSec > 0 ? 'Clip ${c.durationSec}s' : 'Voir le clip',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withAlpha(22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withAlpha(90)),
          ),
          child: Icon(
            Icons.videocam_rounded,
            size: compact ? 15 : 17,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class MatchEventVideoAttachButton extends StatelessWidget {
  final Color accent;
  final Future<void> Function()? onAttach;

  const MatchEventVideoAttachButton({
    super.key,
    this.accent = const Color(0xFFC9A84C),
    this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Joindre clip vMix',
      child: InkWell(
        onTap: onAttach,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withAlpha(22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withAlpha(70)),
          ),
          child: Icon(Icons.movie_creation_outlined, color: accent, size: 14),
        ),
      ),
    );
  }
}

class _SingleHighlightDialog extends StatefulWidget {
  final MatchHighlightClip clip;
  const _SingleHighlightDialog({required this.clip});

  @override
  State<_SingleHighlightDialog> createState() => _SingleHighlightDialogState();
}

class _SingleHighlightDialogState extends State<_SingleHighlightDialog> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.clip.videoUrl),
    );
    try {
      await c.initialize();
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _ctrl = c;
        _ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = [
      if (widget.clip.minute > 0) "${widget.clip.minute}'",
      if (widget.clip.player.isNotEmpty) widget.clip.player,
    ].join(' · ');
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.isEmpty ? 'Clip' : label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (!_ready || _ctrl == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
            )
          else
            AspectRatio(
              aspectRatio: _ctrl!.value.aspectRatio == 0
                  ? 16 / 9
                  : _ctrl!.value.aspectRatio,
              child: VideoPlayer(_ctrl!),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
