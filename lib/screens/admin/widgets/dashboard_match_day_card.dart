import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_navigation.dart';
import '../admin_nav_model.dart';
import '../admin_palette.dart';

/// Tour de contrôle « jour de match » : live, stats, prochain match, alertes.
class DashboardMatchDayCard extends StatelessWidget {
  const DashboardMatchDayCard({super.key});

  static bool _isCssaMatch(Map<String, dynamic> m) {
    final t1 = (m['team1'] as String? ?? '').toUpperCase();
    final t2 = (m['team2'] as String? ?? '').toUpperCase();
    return t1.contains('SEDAN') || t1.contains('CSSA') ||
        t2.contains('SEDAN') || t2.contains('CSSA');
  }

  @override
  Widget build(BuildContext context) {
    final liveRef = FirebaseFirestore.instance.collection('live').doc('current');
    final reportsRef = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending');

    return StreamBuilder<DocumentSnapshot>(
      stream: liveRef.snapshots(),
      builder: (context, liveSnap) {
        final liveData = liveSnap.data?.data() as Map<String, dynamic>?;
        final isLive = liveSnap.data?.exists == true;
        final liveMatchId = (liveData?['matchId'] as String? ?? '').trim();
        final liveTeams =
            '${liveData?['team1'] ?? ''} · ${liveData?['team2'] ?? ''}';

        return StreamBuilder<QuerySnapshot>(
          stream: reportsRef.snapshots(),
          builder: (context, repSnap) {
            final pendingReports = repSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('status', isEqualTo: 'upcoming')
                  .orderBy('date')
                  .limit(12)
                  .snapshots(),
              builder: (context, matchSnap) {
                QueryDocumentSnapshot? nextCssa;
                if (matchSnap.hasData) {
                  for (final d in matchSnap.data!.docs) {
                    final m = d.data() as Map<String, dynamic>;
                    if (_isCssaMatch(m)) {
                      nextCssa = d;
                      break;
                    }
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLive ? adminRed.withAlpha(80) : adminBorder,
                    ),
                    boxShadow: adminCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'JOUR DE MATCH',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: adminGold,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const Spacer(),
                          if (pendingReports > 0)
                            _badge('$pendingReports signalement(s)', adminOrange),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _row(
                        icon: Icons.live_tv_rounded,
                        color: isLive ? adminRed : adminGrey,
                        title: isLive ? 'Live en cours' : 'Pas de live',
                        subtitle: isLive
                            ? liveTeams.trim().replaceAll(' · ', ' vs ')
                            : 'Lance le direct depuis l’onglet Live',
                      ),
                      if (isLive && liveMatchId.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _actions(context, liveMatchId, liveData?['team1']?.toString() ?? '', liveData?['team2']?.toString() ?? ''),
                      ],
                      const Divider(height: 22, color: adminBorder),
                      if (nextCssa != null) ...[
                        _NextMatchBlock(doc: nextCssa),
                        const SizedBox(height: 10),
                        _actions(
                          context,
                          nextCssa.id,
                          (nextCssa.data() as Map)['team1']?.toString() ?? '',
                          (nextCssa.data() as Map)['team2']?.toString() ?? '',
                        ),
                      ] else
                        Text(
                          'Aucun match CSSA à venir dans les 12 prochains.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: adminGrey,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _quickBtn(context, 'Direct', Icons.live_tv_rounded, adminRed, AdminTabIndex.direct),
                          _quickBtn(context, 'Stats', Icons.bar_chart_rounded, adminGold, AdminTabIndex.stats),
                          _quickBtn(context, 'Matchs', Icons.sports_soccer_rounded, adminBlue, AdminTabIndex.matchs),
                          _quickBtn(context, 'Diffusion', Icons.send_rounded, adminPurple, AdminTabIndex.notifs),
                          if (pendingReports > 0)
                            _quickBtn(context, 'Signalements', Icons.flag_rounded, adminOrange, AdminTabIndex.communaute),
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

  Widget _badge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withAlpha(90)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: adminTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    String matchId,
    String t1,
    String t2,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => AdminNavigation.openStatsWorkbench(
              context,
              matchId: matchId,
              team1: t1,
              team2: t2,
            ),
            icon: const Icon(Icons.bar_chart_rounded, size: 16),
            label: const Text('Saisir stats'),
            style: OutlinedButton.styleFrom(
              foregroundColor: adminGold,
              side: BorderSide(color: adminGold.withAlpha(100)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => AdminNavigation.openMatchEditor(
              context,
              matchId: matchId,
            ),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Fiche match'),
            style: OutlinedButton.styleFrom(
              foregroundColor: adminTextPrimary,
              side: const BorderSide(color: adminBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    int tab,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: adminTextPrimary,
      ),
      backgroundColor: color.withAlpha(16),
      side: BorderSide(color: color.withAlpha(60)),
      onPressed: () => AdminNavigation.goToTab(context, tab),
    );
  }
}

class _NextMatchBlock extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _NextMatchBlock({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';
    final statsState = d['statsState']?.toString() ?? 'none';

    String statsLabel;
    Color statsColor;
    switch (statsState) {
      case 'published':
        statsLabel = 'Stats clôturées';
        statsColor = adminGreenAccent;
      case 'preview':
        statsLabel = 'Stats preview';
        statsColor = const Color(0xFF4A90D9);
      default:
        statsLabel = 'Stats non publiées';
        statsColor = adminGrey;
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('match_stats')
          .doc(doc.id)
          .snapshots(),
      builder: (context, sheetSnap) {
        final sheet = sheetSnap.data?.data() as Map<String, dynamic>?;
        final sheetState = sheet?['state']?.toString();
        if (sheetState == 'preview') {
          statsLabel = 'Stats en preview (sync 5 min)';
          statsColor = const Color(0xFF4A90D9);
        } else if (sheetState == 'published') {
          statsLabel = 'Stats clôturées';
          statsColor = adminGreenAccent;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer_rounded, size: 18, color: adminBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['team1']} vs ${d['team2']}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                        ),
                      ),
                      Text(
                        '$dateStr · $statsLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: statsColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
