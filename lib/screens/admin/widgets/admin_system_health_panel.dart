import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_palette.dart';

/// Indicateurs santé : live, file notifs, signalements.
class AdminSystemHealthPanel extends StatelessWidget {
  final bool compact;

  const AdminSystemHealthPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('live').doc('current').snapshots(),
      builder: (context, liveSnap) {
        final isLive = liveSnap.data?.exists == true;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications_queue')
              .where('status', isEqualTo: 'pending')
              .limit(5)
              .snapshots(),
          builder: (context, notifSnap) {
            final pendingNotifs = notifSnap.data?.docs.length ?? 0;
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'pending')
                  .limit(5)
                  .snapshots(),
              builder: (context, repSnap) {
                final pendingReports = repSnap.data?.docs.length ?? 0;
                final items = [
                  _HealthItem(
                    'Live',
                    isLive ? 'Actif' : 'Inactif',
                    isLive ? adminRed : adminGrey,
                    Icons.live_tv_rounded,
                  ),
                  _HealthItem(
                    'Notifs en file',
                    '$pendingNotifs',
                    pendingNotifs > 0 ? adminOrange : adminGreenAccent,
                    Icons.pending_actions_rounded,
                  ),
                  _HealthItem(
                    'Signalements',
                    '$pendingReports',
                    pendingReports > 0 ? adminOrange : adminGreenAccent,
                    Icons.flag_rounded,
                  ),
                ];

                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((i) => _chip(i)).toList(),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SANTÉ SYSTÈME',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminOrange,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _tile(items[i])),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tile(_HealthItem i) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: i.color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: i.color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i.icon, size: 16, color: i.color),
          const SizedBox(height: 6),
          Text(
            i.value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
            ),
          ),
          Text(
            i.label,
            style: GoogleFonts.inter(fontSize: 9, color: adminGrey),
          ),
        ],
      ),
    );
  }

  Widget _chip(_HealthItem i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: i.color.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: i.color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i.icon, size: 14, color: i.color),
          const SizedBox(width: 6),
          Text(
            '${i.label}: ${i.value}',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _HealthItem(this.label, this.value, this.color, this.icon);
}
