import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';

/// Bottom sheet édition replay YouTube (liste Matchs).
void showMatchReplaySheet(BuildContext context, DocumentSnapshot docSnap) {
  final d = docSnap.data() as Map<String, dynamic>;
  final ctrl = TextEditingController(text: d['replayVideoId'] ?? '');
  final accent = AdminModuleColors.preparation;
  showModalBottomSheet(
    context: context,
    backgroundColor: adminCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: adminBottomSheetPadding(ctx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID VIDÉO YOUTUBE',
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${d['team1']} vs ${d['team2']}',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          ),
          const SizedBox(height: 16),
          AdminField(
            ctrl: ctrl,
            label: 'YouTube Video ID (ex: dQw4w9WgXcQ)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if ((d['replayVideoId'] ?? '').isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await docSnap.reference.update({
                        'replayVideoId': FieldValue.delete(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: adminRed,
                      side: BorderSide(color: adminRed.withAlpha(120)),
                    ),
                    child: const Text('SUPPRIMER'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    await docSnap.reference.update({
                      'replayVideoId': ctrl.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ENREGISTRER'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
