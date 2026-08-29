import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../navigation/lineup_cinematic_rollout.dart';
import '../../../../services/feature_flags_service.dart';
import '../../../../services/lineup_cinematic_service.dart';
import '../../../../widgets/lineup_cinematic_overlay.dart';
import '../../admin_components.dart';
import '../../admin_palette.dart';

/// Direct → Composition : switch + TEST (rendu immédiat).
class LineupCinematicAdminSection extends StatelessWidget {
  const LineupCinematicAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        final on = FeatureFlagsService.isEnabled(
          snap.data?.data(),
          LineupCinematicRollout.flagKey,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CINÉMATIQUE COMPOSITION',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminGold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch = cinématique du vrai XI pendant le direct '
              '(ouverture / retour dans l’app, une fois par compo). '
              'TEST = XI au hasard sur le téléphone déjà ouvert, 3 min max '
              '(même si le switch est off). Un TEST oublié ne rejoue plus '
              'à chaque lancement.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(adminPaperRadius),
                border: Border.all(color: adminHairline, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cinématique XI (app ouverte)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LineupCinematicRollout.flagKey,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: adminGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: on,
                    onChanged: snap.hasData
                        ? (v) => FeatureFlagsService.setFlag(
                              LineupCinematicRollout.flagKey,
                              v,
                            )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AdminPrimaryButton(
              label: 'TEST — voir la cinématique',
              icon: Icons.play_circle_outline_rounded,
              height: 52,
              color: adminGold,
              textColor: adminInk,
              onTap: () => _runTest(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runTest(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
    try {
      await LineupCinematicService.instance.requestAdminTestCue();
      final show = await LineupCinematicService.instance.loadLatestForTest();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Envoyé au téléphone — laisse l’app ouverte (rebuild si l’écran reste vide).',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      await showLineupCinematicOverlay(context, show);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de lancer le TEST : $e',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }
}
