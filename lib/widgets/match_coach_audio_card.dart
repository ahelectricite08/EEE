import 'package:flutter/material.dart';

import '../screens/matches/match_detail_theme.dart';
import '../screens/matches/match_detail_type.dart';
import '../services/match_coach_audio_service.dart';
import 'match_event_audio_play_button.dart';

/// Carte fan « Parole du coach » — visible uniquement si un audio est publié.
class MatchCoachAudioCard extends StatelessWidget {
  final String matchId;
  final EdgeInsetsGeometry margin;

  const MatchCoachAudioCard({
    super.key,
    required this.matchId,
    this.margin = const EdgeInsets.only(bottom: MatchDetailTheme.chapterGap),
  });

  @override
  Widget build(BuildContext context) {
    final id = matchId.trim();
    if (id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<MatchCoachAudio?>(
      stream: MatchCoachAudioService.instance.watch(id),
      builder: (context, snap) {
        final audio = snap.data;
        if (audio == null || !audio.isReady) {
          return const SizedBox.shrink();
        }

        final subtitle = audio.title.trim().isNotEmpty
            ? audio.title.trim()
            : (audio.durationSec > 0
                ? '${audio.durationSec} s'
                : 'Écouter le discours');

        return Container(
          margin: margin,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: MatchDetailTheme.paper(),
          child: Row(
            children: [
              Container(
                width: MatchDetailTheme.filet,
                height: 28,
                color: MatchDetailTheme.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAROLE DU COACH',
                      style: MatchDetailType.kicker.copyWith(
                        color: MatchDetailTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MatchDetailType.caption.copyWith(
                        color: MatchDetailTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CoachAudioPlayButton(url: audio.audioUrl),
            ],
          ),
        );
      },
    );
  }
}

class _CoachAudioPlayButton extends StatelessWidget {
  final String url;

  const _CoachAudioPlayButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MatchCommentaryPlayer.instance.playingListenable,
      builder: (context, _, __) {
        final playing =
            MatchCommentaryPlayer.instance.playingUrl == url.trim();
        return Tooltip(
          message: playing ? 'Arrêter' : 'Écouter',
          child: InkWell(
            onTap: () => MatchCommentaryPlayer.instance.toggle(url),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: playing
                    ? MatchDetailTheme.ink
                    : MatchDetailTheme.surface,
                border: Border.all(
                  color: playing
                      ? MatchDetailTheme.ink
                      : MatchDetailTheme.green,
                ),
              ),
              child: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: playing ? Colors.white : MatchDetailTheme.green,
                size: 26,
              ),
            ),
          ),
        );
      },
    );
  }
}
