import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'match_commentary_record_sheet.dart';
import 'match_highlight_attach_sheet.dart';

enum _MediaOfferChoice { skip, audio, video, both }

/// Propose audio et/ou clip vMix après un fait de jeu (tout optionnel).
Future<void> offerMatchMediaAfterEvent(
  BuildContext context, {
  required Map<String, dynamic> event,
}) async {
  final matchId = (event['matchId'] ?? '').toString().trim();
  final eventId = (event['id'] ?? '').toString().trim();
  if (matchId.isEmpty || eventId.isEmpty || !context.mounted) return;

  final choice = await showDialog<_MediaOfferChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        'Médias sur cette action ?',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      content: Text(
        'Optionnel : commentaire audio et/ou extrait vMix (10–20s) '
        'pour la fiche et le résumé du match.',
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _MediaOfferChoice.skip),
          child: Text('Passer', style: GoogleFonts.inter(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _MediaOfferChoice.audio),
          child: Text('Audio', style: GoogleFonts.inter(color: const Color(0xFFC9A84C))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _MediaOfferChoice.video),
          child: Text('Clip vMix', style: GoogleFonts.inter(color: const Color(0xFFC9A84C))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _MediaOfferChoice.both),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC9A84C)),
          child: Text(
            'Les deux',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.black),
          ),
        ),
      ],
    ),
  );

  if (choice == null || choice == _MediaOfferChoice.skip || !context.mounted) {
    return;
  }

  final type = (event['type'] ?? '').toString();
  final minute = (event['minute'] as num?)?.toInt() ?? 0;
  final player = (event['player'] ?? '').toString();
  final team = (event['team'] ?? '').toString();

  if (choice == _MediaOfferChoice.audio || choice == _MediaOfferChoice.both) {
    await showMatchCommentaryRecordSheet(
      context,
      matchId: matchId,
      eventId: eventId,
      type: type,
      minute: minute,
      player: player,
      team: team,
    );
  }
  if (!context.mounted) return;
  if (choice == _MediaOfferChoice.video || choice == _MediaOfferChoice.both) {
    await showMatchHighlightAttachSheet(
      context,
      matchId: matchId,
      eventId: eventId,
      type: type,
      minute: minute,
      player: player,
      team: team,
    );
  }
}
