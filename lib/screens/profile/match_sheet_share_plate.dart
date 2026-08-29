import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/match_rating_service.dart';
import '../../services/match_sheet_share_service.dart';
import 'match_sheet_share_visual.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

/// Plaque profil bénévole : visuel score + buteurs 9:16 (même famille que la note).
class MatchSheetSharePlate extends StatefulWidget {
  const MatchSheetSharePlate({super.key});

  @override
  State<MatchSheetSharePlate> createState() => _MatchSheetSharePlateState();
}

class _MatchSheetSharePlateState extends State<MatchSheetSharePlate> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MatchRatingService.watchRecentStoppedMatches(_now),
      builder: (context, snap) {
        QueryDocumentSnapshot<Map<String, dynamic>>? chosen;
        for (final doc in snap.data?.docs ?? const []) {
          if (MatchSheetShareService.hasShareVisual(doc.data(), _now)) {
            chosen = doc;
            break;
          }
        }

        final payload = chosen == null
            ? null
            : MatchSheetSharePayload.fromDoc(
                chosen.id,
                chosen.data(),
                now: _now,
              );

        if (payload == null) {
          return const _SheetPaper(ready: false);
        }

        final remaining = MatchRatingService.socialVisualRemaining(
          payload.liveEndedAt,
          _now,
        );

        return _SheetPaper(
          ready: true,
          payload: payload,
          remainingLabel: MatchRatingService.socialVisualRemainingLabel(
            remaining,
          ),
        );
      },
    );
  }
}

class _SheetPaper extends StatelessWidget {
  final bool ready;
  final MatchSheetSharePayload? payload;
  final String remainingLabel;

  const _SheetPaper({
    required this.ready,
    this.payload,
    this.remainingLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: profilePaper(
        edge: ready ? profileGreenBright.withValues(alpha: 0.35) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !ready || payload == null
              ? null
              : () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MatchSheetShareVisualScreen(payload: payload!),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_soccer_rounded,
                      size: 14,
                      color: profileGreenBright,
                    ),
                    const SizedBox(width: 6),
                    Text('FEUILLE DE MATCH', style: ProfileType.kicker),
                    const Spacer(),
                    Text(
                      'PORTRAIT 9:16',
                      style: ProfileType.kicker.copyWith(
                        color: profileGreenBright,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: profileHairline),
                const SizedBox(height: 10),
                if (ready && payload != null) ...[
                  Text(
                    payload!.scoreLabel,
                    style: ProfileType.title.copyWith(fontSize: 32, height: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${payload!.team1}  —  ${payload!.team2}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileType.label,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$remainingLabel · visuel vertical pour les réseaux',
                    style: ProfileType.caption,
                  ),
                  const SizedBox(height: 10),
                  const _DownloadCta(enabled: true),
                ] else ...[
                  Text(
                    'Visuel vertical pour les réseaux',
                    style: ProfileType.title.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disponible 48 h après l’arrêt du live, dès la fin de match. '
                    'Enregistre ou partage le format portrait 9:16.',
                    style: ProfileType.caption,
                  ),
                  const SizedBox(height: 10),
                  const _DownloadCta(enabled: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadCta extends StatelessWidget {
  final bool enabled;

  const _DownloadCta({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? profileGreen : profileSurfaceMuted,
        border: Border.all(
          color: enabled ? profileGreenDeep : profileHairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.download_rounded : Icons.hourglass_empty_rounded,
              size: 16,
              color: enabled ? Colors.white : profileMutedText,
            ),
            const SizedBox(width: 6),
            Text(
              enabled ? 'Enregistrer / Partager' : 'En attente du live',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : profileMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
