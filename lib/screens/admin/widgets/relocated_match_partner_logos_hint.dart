import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_navigation.dart';
import '../admin_nav_model.dart';
import '../admin_palette.dart';

/// Ancien emplacement (Après-match / MARQUE) — source unique Photos & réseaux.
class RelocatedMatchPartnerLogosHint extends StatelessWidget {
  const RelocatedMatchPartnerLogosHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOGOS PARTENAIRES',
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Déplacé vers Photos & réseaux → Partenaires match. '
            'Note du match, homme du match et souvenir se règlent au même '
            'endroit.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                AdminNavigation.goToTab(context, AdminTabIndex.visuels),
            child: Text(
              'Ouvrir Photos & réseaux',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: adminGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
