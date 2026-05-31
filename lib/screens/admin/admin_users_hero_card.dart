import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';
import 'admin_shared_widgets.dart';

class AdminUsersHeroCard extends StatelessWidget {
  /// Total réel (`users.count()`), aligné sur le pilotage.
  final int total;
  /// Nombre de fiches chargées dans la liste.
  final int displayed;
  final int admins;
  final int teamDvcr;
  final int supporters;

  const AdminUsersHeroCard({
    super.key,
    required this.total,
    required this.displayed,
    required this.admins,
    required this.teamDvcr,
    required this.supporters,
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
            'Tu pilotes ici les rôles (Supporter / Team DVCR), les badges et les accès.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: adminGrey,
              height: 1.45,
            ),
          ),
          if (displayed < total) ...[
            const SizedBox(height: 8),
            Text(
              '$displayed affichés sur $total comptes — tire vers le bas pour tout recharger.',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: adminGold,
                height: 1.35,
              ),
            ),
          ],
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
                icon: Icons.cloud_download_rounded,
                label: 'Tire pour actualiser',
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
                  label: 'SUPPORTERS',
                  value: '$supporters',
                  color: adminGreyLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
