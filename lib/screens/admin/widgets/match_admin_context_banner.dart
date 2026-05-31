import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/match_stats_schema.dart';
import '../../../services/match_stats_sheet_service.dart';
import '../admin_navigation.dart';
import '../admin_palette.dart';

/// Bandeau partagé : contexte match (live, stats, publication) + liens Match · Direct · Stats.
class MatchAdminContextBanner extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;
  final bool compact;

  const MatchAdminContextBanner({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final id = matchId.trim();
    if (id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, liveSnap) {
        final live = liveSnap.data?.data();
        final liveMid = (live?['matchId'] as String? ?? '').trim();
        final isThisLive = liveSnap.data?.exists == true && liveMid == id;
        final statsEnabled = isThisLive && ((live?['statsEnabled'] as bool?) ?? false);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: MatchStatsSheetService.instance.docRef(id).snapshots(),
          builder: (context, sheetSnap) {
            final sheet = sheetSnap.data?.data() ?? {};
            final pub = MatchStatsPublicationSettings.fromSheet(sheet);
            final hasSheetStats = !MatchStatsSchema.isEmpty(
              MatchStatsSchema.normalizeMap(sheet['stats'] as Map<String, dynamic>?),
            );

            final statusParts = <String>[
              if (isThisLive) 'LIVE',
              if (statsEnabled) 'Stats affichées',
              if (pub.official) 'Officiel',
              if (!pub.official && pub.cardDisplay) 'Aperçu app',
              if (!pub.official && !pub.cardDisplay && hasSheetStats) 'Brouillon',
            ];
            if (statusParts.isEmpty) statusParts.add('Hors direct');

            return Container(
              padding: EdgeInsets.all(compact ? 10 : 12),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isThisLive
                      ? adminRed.withAlpha(120)
                      : adminBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isThisLive
                            ? Icons.sensors_rounded
                            : Icons.sports_soccer_rounded,
                        size: 18,
                        color: isThisLive ? adminRed : adminGold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$team1 · $team2',
                              style: GoogleFonts.inter(
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w800,
                                color: adminTextPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              statusParts.join(' · '),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _linkChip(
                        context,
                        'Fiche match',
                        Icons.edit_calendar_rounded,
                        adminBlue,
                        () => AdminNavigation.openMatchEditor(
                          context,
                          matchId: id,
                        ),
                      ),
                      _linkChip(
                        context,
                        'Direct',
                        Icons.live_tv_rounded,
                        adminRed,
                        () => AdminNavigation.goToDirect(context),
                      ),
                      _linkChip(
                        context,
                        'Stats',
                        Icons.bar_chart_rounded,
                        adminGold,
                        () => AdminNavigation.openStatsWorkbench(
                          context,
                          matchId: id,
                          team1: team1,
                          team2: team2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _linkChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
