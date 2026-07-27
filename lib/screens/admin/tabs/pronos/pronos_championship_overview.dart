import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';

/// Aperçu rapide des données championnat prono (avant reset ou en cours de saison).
class PronosChampionshipOverview extends StatelessWidget {
  const PronosChampionshipOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAT ACTUEL',
          style: GoogleFonts.barlowCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Compteurs Firestore — utile pour vérifier qu\'un reset a bien tout vidé.',
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.35,
            color: adminGrey,
          ),
        ),
        const SizedBox(height: 12),
        AdminStatRow(
          stats: [
            AdminStatFuture(
              label: 'PRONOS',
              icon: Icons.sports_soccer_rounded,
              color: adminGold,
              future: FirebaseFirestore.instance
                  .collection('predictions')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'CLASSEMENT',
              icon: Icons.leaderboard_rounded,
              color: adminGold,
              future: FirebaseFirestore.instance
                  .collection('prono_leaderboard')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'DUELS',
              icon: Icons.emoji_events_rounded,
              color: Colors.orange,
              future: FirebaseFirestore.instance
                  .collection('prono_duels')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'LIGUES',
              icon: Icons.groups_rounded,
              color: adminBlue,
              future: FirebaseFirestore.instance
                  .collection('private_leagues')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
          ],
        ),
      ],
    );
  }
}
