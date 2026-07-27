import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_form_widgets.dart';
import '../admin_module_colors.dart';
import '../admin_navigation.dart';
import '../admin_nav_model.dart';
import '../admin_palette.dart';

/// Tour de contrôle jour de match — bandeau dense, pas carte marketing.
class DashboardMatchDayCard extends StatelessWidget {
  const DashboardMatchDayCard({super.key});

  static bool _isCssaMatch(Map<String, dynamic> m) {
    final t1 = (m['team1'] as String? ?? '').toUpperCase();
    final t2 = (m['team2'] as String? ?? '').toUpperCase();
    return t1.contains('SEDAN') ||
        t1.contains('CSSA') ||
        t2.contains('SEDAN') ||
        t2.contains('CSSA');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('live').doc('current').snapshots(),
      builder: (context, liveSnap) {
        final liveData = liveSnap.data?.data() as Map<String, dynamic>?;
        final isLive = liveSnap.data?.exists == true;
        final liveMatchId = (liveData?['matchId'] as String? ?? '').trim();
        final liveTeams =
            '${liveData?['team1'] ?? ''} · ${liveData?['team2'] ?? ''}';

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

            final accent = isLive ? adminRed : AdminModuleColors.pilotage;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: adminSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isLive ? adminRed.withAlpha(70) : adminBorder,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: accent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'JOUR DE MATCH',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  isLive ? 'Live' : 'Prochain',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isLive ? adminRed : adminGrey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isLive)
                              _titleLine(
                                liveTeams.trim().isEmpty
                                    ? 'Direct en cours'
                                    : liveTeams.trim().replaceAll(' · ', ' vs '),
                              )
                            else if (nextCssa != null)
                              _NextMatchLine(doc: nextCssa)
                            else
                              Text(
                                'Aucun match CSSA à venir',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: adminGrey,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final upcoming = nextCssa;
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (isLive)
                                      _Link(
                                        'Ouvrir Direct',
                                        () => AdminNavigation.goToDirect(
                                          context,
                                        ),
                                        adminRed,
                                      ),
                                    if (isLive && liveMatchId.isNotEmpty)
                                      _Link(
                                        'Stats',
                                        () =>
                                            AdminNavigation.openStatsWorkbench(
                                          context,
                                          matchId: liveMatchId,
                                          team1: liveData?['team1']
                                                  ?.toString() ??
                                              '',
                                          team2: liveData?['team2']
                                                  ?.toString() ??
                                              '',
                                        ),
                                        AdminModuleColors.apresMatch,
                                      ),
                                    if (!isLive && upcoming != null) ...[
                                      _Link(
                                        'Fiche match',
                                        () => AdminNavigation.openMatchEditor(
                                          context,
                                          matchId: upcoming.id,
                                        ),
                                        AdminModuleColors.preparation,
                                      ),
                                      _Link(
                                        'Stats',
                                        () {
                                          final m = upcoming.data()
                                              as Map<String, dynamic>;
                                          AdminNavigation.openStatsWorkbench(
                                            context,
                                            matchId: upcoming.id,
                                            team1:
                                                m['team1']?.toString() ?? '',
                                            team2:
                                                m['team2']?.toString() ?? '',
                                          );
                                        },
                                        AdminModuleColors.apresMatch,
                                      ),
                                    ],
                                    _Link(
                                      'Matchs',
                                      () => AdminNavigation.goToTab(
                                        context,
                                        AdminTabIndex.matchs,
                                      ),
                                      AdminModuleColors.pilotage,
                                    ),
                                    _Link(
                                      'Direct',
                                      () =>
                                          AdminNavigation.goToDirect(context),
                                      AdminModuleColors.live,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _titleLine(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: adminTextPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

class _NextMatchLine extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _NextMatchLine({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${d['team1']} vs ${d['team2']}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: adminTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          dateStr,
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _Link(this.label, this.onTap, this.color);

  @override
  Widget build(BuildContext context) {
    return AdminSmallButton(label: label, onTap: onTap, color: color);
  }
}
