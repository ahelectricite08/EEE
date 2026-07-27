import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_module_colors.dart';
import '../admin_navigation.dart';
import '../admin_palette.dart';

/// Bandeau santé compact — régie, pas carte KPI.
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
              .where('status', whereIn: ['pending', 'processing'])
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
                    'Notifs',
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
                    runSpacing: 6,
                    children: items.map(_chip).toList(),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: adminSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'SANTÉ',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AdminModuleColors.pilotage,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 22, color: adminBorder),
                      for (final i in items) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _stripCell(i)),
                      ],
                      if (isLive) ...[
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => AdminNavigation.goToDirect(context),
                          style: TextButton.styleFrom(
                            foregroundColor: adminRed,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Direct →',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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

  Widget _stripCell(_HealthItem i) {
    return Row(
      children: [
        Icon(i.icon, size: 13, color: i.color),
        const SizedBox(width: 5),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${i.label} ',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: adminGrey,
                  ),
                ),
                TextSpan(
                  text: i.value,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _chip(_HealthItem i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i.icon, size: 12, color: i.color),
          const SizedBox(width: 5),
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
