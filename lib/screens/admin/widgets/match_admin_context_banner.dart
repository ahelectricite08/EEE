import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/match_stats_schema.dart';
import '../../../services/match_stats_sheet_service.dart';
import '../admin_module_colors.dart';
import '../admin_navigation.dart';
import '../admin_palette.dart';

/// Bandeau partagé : contexte match + liens Fiche · Direct · Stats.
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
        final statsEnabled =
            isThisLive && ((live?['statsEnabled'] as bool?) ?? false);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: MatchStatsSheetService.instance.docRef(id).snapshots(),
          builder: (context, sheetSnap) {
            final sheet = sheetSnap.data?.data() ?? {};
            final pub = MatchStatsPublicationSettings.fromSheet(sheet);
            final hasSheetStats = !MatchStatsSchema.isEmpty(
              MatchStatsSchema.normalizeMap(
                sheet['stats'] as Map<String, dynamic>?,
              ),
            );

            final statusParts = <String>[
              if (isThisLive) 'LIVE',
              if (statsEnabled) 'Stats affichées',
              if (pub.official) 'Officiel',
              if (!pub.official && pub.cardDisplay) 'Aperçu app',
              if (!pub.official && !pub.cardDisplay && hasSheetStats)
                'Brouillon',
            ];
            if (statusParts.isEmpty) statusParts.add('Hors direct');

            final borderColor =
                isThisLive ? AdminModuleColors.live : adminBorder;
            final statusColor = isThisLive
                ? AdminModuleColors.live
                : AdminModuleColors.preparation;

            return Container(
              padding: EdgeInsets.all(compact ? 10 : 12),
              decoration: BoxDecoration(
                color: adminSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 32,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isThisLive
                            ? Icons.sensors_rounded
                            : Icons.sports_soccer_rounded,
                        size: 18,
                        color: statusColor,
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
                  Row(
                    children: [
                      Expanded(
                        child: _NavLink(
                          label: 'Fiche',
                          icon: Icons.edit_calendar_rounded,
                          color: AdminModuleColors.preparation,
                          onTap: () => AdminNavigation.openMatchEditor(
                            context,
                            matchId: id,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _NavLink(
                          label: 'Direct',
                          icon: Icons.live_tv_rounded,
                          color: AdminModuleColors.live,
                          onTap: () => AdminNavigation.goToDirect(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _NavLink(
                          label: 'Stats',
                          icon: Icons.bar_chart_rounded,
                          color: AdminModuleColors.apresMatch,
                          onTap: () => AdminNavigation.openStatsWorkbench(
                            context,
                            matchId: id,
                            team1: team1,
                            team2: team2,
                          ),
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
}

class _NavLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
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
