import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';
import 'admin_shared_widgets.dart';

class AdminUsersHeroCard extends StatelessWidget {
  final int total;
  final int admins;
  final int teamDvcr;
  final int partenaires;
  final int donateurs;

  const AdminUsersHeroCard({
    super.key,
    required this.total,
    required this.admins,
    required this.teamDvcr,
    required this.partenaires,
    required this.donateurs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [adminGold.withAlpha(30), adminCard],
        ),
        border: Border.all(color: adminGold.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CENTRE UTILISATEURS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu pilotes ici les roles, les badges, les partenaires et les acces avec synchronisation immediate sur les ecrans concernes.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: adminGrey,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              AdminMiniInfoPill(
                icon: Icons.sync_rounded,
                label: 'Propagation auto',
              ),
              AdminMiniInfoPill(
                icon: Icons.storage_rounded,
                label: 'Cache local actif',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AdminStatPill(
                  label: 'TOTAL',
                  value: '$total',
                  color: adminGreyLight,
                ),
                const SizedBox(width: 8),
                AdminStatPill(
                  label: 'ADMINS',
                  value: '$admins',
                  color: adminRed,
                ),
                const SizedBox(width: 8),
                AdminStatPill(
                  label: 'TEAM DVCR',
                  value: '$teamDvcr',
                  color: adminGold,
                ),
                const SizedBox(width: 8),
                AdminStatPill(
                  label: 'PARTENAIRES',
                  value: '$partenaires',
                  color: const Color(0xFFFF9100),
                ),
                const SizedBox(width: 8),
                AdminStatPill(
                  label: 'DONATEURS',
                  value: '$donateurs',
                  color: const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
