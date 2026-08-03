import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/matches/match_detail_palette.dart';
import '../services/match_coach_audio_service.dart';
import 'match_event_audio_play_button.dart';

/// Carte fan « Parole du coach » — visible uniquement si un audio est publié.
class MatchCoachAudioCard extends StatelessWidget {
  final String matchId;
  final EdgeInsetsGeometry margin;

  const MatchCoachAudioCard({
    super.key,
    required this.matchId,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          decoration: BoxDecoration(
            color: MatchDetailPalette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MatchDetailPalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MatchDetailPalette.gold.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MatchDetailPalette.gold.withAlpha(80),
                  ),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: MatchDetailPalette.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAROLE DU COACH',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: MatchDetailPalette.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MatchDetailPalette.text,
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
                color: MatchDetailPalette.gold.withAlpha(playing ? 55 : 28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MatchDetailPalette.gold.withAlpha(100),
                ),
              ),
              child: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: MatchDetailPalette.gold,
                size: 26,
              ),
            ),
          ),
        );
      },
    );
  }
}
