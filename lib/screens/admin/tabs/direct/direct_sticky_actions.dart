import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_controller.dart';
import '../../admin_nav_model.dart';
import '../../admin_navigation.dart';
import '../../admin_palette.dart';
import 'direct_poste_desk.dart';

/// Bandeau sticky : score + START/STOP et raccourcis du poste.
class DirectStickyActionsBar extends StatelessWidget {
  final bool isLive;
  final Map<String, dynamic>? data;
  final bool loading;
  final VoidCallback onToggleLive;
  final DirectPosteDesk desk;

  const DirectStickyActionsBar({
    super.key,
    required this.isLive,
    required this.data,
    required this.loading,
    required this.onToggleLive,
    required this.desk,
  });

  @override
  Widget build(BuildContext context) {
    final team1 = (data?['team1'] as String? ?? '').trim();
    final team2 = (data?['team2'] as String? ?? '').trim();
    final home = (data?['scoreHome'] as int?) ?? 0;
    final away = (data?['scoreAway'] as int?) ?? 0;
    final title = isLive && team1.isNotEmpty
        ? '$team1 $home – $away $team2'
        : (isLive ? 'Match en direct' : 'Aucun live');
    final canStart = desk.allows(DirectLivePart.startStop);

    return Material(
      color: adminCard,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: adminBorder)),
          color: adminCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLive ? adminRed : adminGreyLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canStart)
                  TextButton(
                    onPressed: loading ? null : onToggleLive,
                    style: TextButton.styleFrom(
                      foregroundColor: isLive ? adminRed : adminGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isLive ? 'STOP' : 'START',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            if (isLive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (desk.allows(DirectLivePart.stats)) ...[
                    _QuickLink(
                      label: 'Stats',
                      onTap: () =>
                          AdminNavigation.openLiveStatsWorkbench(context),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (desk.allows(DirectLivePart.push)) ...[
                    _QuickLink(
                      label: 'Push',
                      onTap: () => AdminController.of(context)
                          .navigateToDiffusion(subTab: 0),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (desk.allows(DirectLivePart.modo))
                    _QuickLink(
                      label: 'Modo',
                      onTap: () => AdminController.of(context)
                          .navigateTo(AdminTabIndex.communaute),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: adminGreen,
          ),
        ),
      ),
    );
  }
}

/// Stream helper pour le doc `live/current`.
Stream<DocumentSnapshot<Map<String, dynamic>>> liveCurrentStream() {
  return FirebaseFirestore.instance
      .collection('live')
      .doc('current')
      .snapshots();
}
