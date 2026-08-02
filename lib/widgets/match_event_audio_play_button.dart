import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/match_commentary_service.dart';
import '../services/match_media_stats_service.dart';

/// Lecteur singleton pour ne jouer qu’un clip à la fois sur la fiche.
class MatchCommentaryPlayer {
  MatchCommentaryPlayer._() {
    _player.onPlayerComplete.listen((_) {
      _playingUrl = null;
      _playingNotify.value++;
    });
  }
  static final instance = MatchCommentaryPlayer._();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<int> _playingNotify = ValueNotifier(0);
  String? _playingUrl;

  String? get playingUrl => _playingUrl;
  ValueNotifier<int> get playingListenable => _playingNotify;

  Future<void> toggle(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_playingUrl == u) {
      await stop();
      return;
    }
    await stop();
    _playingUrl = u;
    _playingNotify.value++;
    await _player.play(UrlSource(u));
  }

  Future<void> stop() async {
    _playingUrl = null;
    _playingNotify.value++;
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// Bouton ▶ sur une ligne de fait de jeu (fan) ou micro (admin).
class MatchEventAudioPlayButton extends StatefulWidget {
  final String matchId;
  final MatchCommentaryClip? clip;
  final Color accent;
  final bool compact;

  const MatchEventAudioPlayButton({
    super.key,
    required this.matchId,
    required this.clip,
    this.accent = const Color(0xFFC9A84C),
    this.compact = false,
  });

  @override
  State<MatchEventAudioPlayButton> createState() =>
      _MatchEventAudioPlayButtonState();
}

class _MatchEventAudioPlayButtonState extends State<MatchEventAudioPlayButton> {
  Future<void> _tap() async {
    final clip = widget.clip;
    if (clip == null || !clip.isReady) return;
    final starting =
        MatchCommentaryPlayer.instance.playingUrl != clip.audioUrl;
    await MatchCommentaryPlayer.instance.toggle(clip.audioUrl);
    if (starting) {
      MatchMediaStatsService.instance.incrementAudioPlay(
        matchId: widget.matchId,
        eventId: clip.eventId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    if (clip == null || !clip.isReady) return const SizedBox.shrink();

    final size = widget.compact ? 28.0 : 32.0;
    return ValueListenableBuilder<int>(
      valueListenable: MatchCommentaryPlayer.instance.playingListenable,
      builder: (context, _, __) {
        final playing =
            MatchCommentaryPlayer.instance.playingUrl == clip.audioUrl;
        return Tooltip(
          message: clip.durationSec > 0 ? '${clip.durationSec}s' : 'Écouter',
          child: InkWell(
            onTap: _tap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: widget.accent.withAlpha(playing ? 50 : 22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.accent.withAlpha(90)),
              ),
              child: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: widget.compact ? 16 : 18,
                color: widget.accent,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton micro admin pour (re)enregistrer un commentaire sur un event.
class MatchEventAudioRecordButton extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> event;
  final Color accent;
  final Future<void> Function()? onRecord;

  const MatchEventAudioRecordButton({
    super.key,
    required this.matchId,
    required this.event,
    this.accent = const Color(0xFFC9A84C),
    this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final eventId = (event['id'] ?? '').toString().trim();
    if (matchId.trim().isEmpty || eventId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: 'Commentaire audio',
      child: InkWell(
        onTap: onRecord,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withAlpha(22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withAlpha(70)),
          ),
          child: Icon(Icons.mic_rounded, color: accent, size: 14),
        ),
      ),
    );
  }
}

/// Petite pastille durée sous le play (optionnel).
class MatchEventAudioDurationLabel extends StatelessWidget {
  final MatchCommentaryClip clip;
  final Color color;

  const MatchEventAudioDurationLabel({
    super.key,
    required this.clip,
    this.color = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    if (clip.durationSec <= 0) return const SizedBox.shrink();
    return Text(
      '${clip.durationSec}"',
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
