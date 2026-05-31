import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';

/// Stats rapides championnat prono (duels, ligues).
class PronosChampionshipOverview extends StatelessWidget {
  const PronosChampionshipOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminStatRow(
          stats: [
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
              label: 'LIGUES',
              icon: Icons.groups_rounded,
              color: adminGold,
              future: FirebaseFirestore.instance
                  .collection('private_leagues')
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
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('private_leagues')
              .orderBy('updatedAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ligues privées récentes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Text(
                      '${d['name'] ?? 'Ligue'} · code ${d['code'] ?? '-'} · '
                      '${d['memberCount'] ?? 0} membre(s)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}
