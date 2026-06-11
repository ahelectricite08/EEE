import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_palette.dart';

/// Rappel des 3 onglets Match · Live · Stats — évite de tout mélanger.
class AdminMatchFlowGuide extends StatelessWidget {
  /// Onglet courant : `match` | `live` | `stats`
  final String active;

  const AdminMatchFlowGuide({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUI FAIT QUOI ?',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: adminGold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _row(
            'Match',
            'Calendrier, fiche, buteurs & cartons (hors live)',
            adminBlue,
            active == 'match',
          ),
          const SizedBox(height: 6),
          _row(
            'Live',
            'Score, chrono, buts en direct, bandeau stats ON/OFF',
            adminRed,
            active == 'live',
          ),
          const SizedBox(height: 6),
          _row(
            'Stats match',
            'Chiffres (tirs, possession…) + publier / terminer',
            adminGold,
            active == 'stats',
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String desc, Color color, bool isActive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? color : adminBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isActive ? color : adminGrey,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: adminGrey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
