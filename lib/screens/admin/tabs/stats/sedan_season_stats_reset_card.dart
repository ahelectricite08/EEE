import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_palette.dart';

/// Remise à zéro des cumuls saison (moyennes + buteurs/cartons) — admin uniquement.
class SedanSeasonStatsResetCard extends StatefulWidget {
  const SedanSeasonStatsResetCard({
    super.key,
    required this.seasonLabel,
    required this.activeSeasonLabel,
    required this.implicitLegacySeasonLabel,
  });

  final String seasonLabel;
  final String activeSeasonLabel;
  final String implicitLegacySeasonLabel;

  @override
  State<SedanSeasonStatsResetCard> createState() =>
      _SedanSeasonStatsResetCardState();
}

class _SedanSeasonStatsResetCardState extends State<SedanSeasonStatsResetCard> {
  bool _loading = false;

  Future<void> _runReset() async {
    final season = widget.seasonLabel.trim();
    if (season.isEmpty) return;

    final ok = await adminConfirm(
      context,
      'Réinitialiser les moyennes & buteurs saison « $season » ?\n\n'
      'Seront effacés pour tous les matchs Sedan/CSSA de cette saison :\n'
      '• stats chiffrées (possession, tirs, passes, corners, fautes, duels…)\n'
      '• buteurs, cartons et événements de jeu saisis\n'
      '• fiches stats match (collection match_stats)\n\n'
      'Seront conservés : calendrier, scores FFF officiels (score1/score2), '
      'compositions, notes spectateurs.\n\n'
      'Action irréversible — les cumuls repartiront à zéro au prochain match saisi.',
    );
    if (!ok || !mounted) return;

    setState(() => _loading = true);
    try {
      final data = await MatchStatsSheetService.instance.resetSedanSeasonStats(
        seasonLabel: season,
        activeSeasonLabel: widget.activeSeasonLabel,
        implicitLegacySeasonLabel: widget.implicitLegacySeasonLabel,
      );
      if (!mounted) return;

      final matches = (data['resetMatches'] as num?)?.toInt() ?? 0;
      final sheets = (data['resetSheets'] as num?)?.toInt() ?? 0;
      final summary = matches == 0
          ? 'Aucune stat à effacer pour cette saison.'
          : '$matches match(s) · $sheets fiche(s) stats';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Saison $season : $summary',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: adminRed,
          content: Text('Erreur reset stats : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: adminSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: adminRed.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RÉINITIALISER MOYENNES & BUTEURS SAISON',
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: adminRed,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Saison « ${widget.seasonLabel} » — remet à zéro les encarts '
              'Moyennes Sedan et Buteurs & cartons (toutes compétitions).',
              style: GoogleFonts.inter(
                fontSize: 10,
                height: 1.4,
                color: adminGrey,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _runReset,
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: adminRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminRed.withAlpha(180)),
                    ),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: adminOnAccent,
                              ),
                            ),
                          )
                        : Text(
                            'RÉINITIALISER MOYENNES & BUTEURS SAISON',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: adminOnAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
