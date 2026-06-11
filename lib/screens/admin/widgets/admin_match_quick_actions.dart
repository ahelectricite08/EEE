import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_nav_model.dart';
import '../admin_navigation.dart';
import '../admin_palette.dart';

/// Boutons rapides : Direct · Stats · Diffusion (rappel).
class AdminMatchQuickActions extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;
  final bool compact;

  const AdminMatchQuickActions({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
  final chips = [
      _ChipDef(
        'Fiche',
        Icons.edit_calendar_rounded,
        adminBlue,
        () => AdminNavigation.openMatchEditor(context, matchId: matchId),
      ),
      _ChipDef(
        'Stats',
        Icons.bar_chart_rounded,
        adminGold,
        () => AdminNavigation.openStatsWorkbench(
          context,
          matchId: matchId,
          team1: team1,
          team2: team2,
        ),
      ),
      _ChipDef(
        'Direct',
        Icons.live_tv_rounded,
        adminRed,
        () => AdminNavigation.goToDirect(context),
      ),
      _ChipDef(
        'Rappel',
        Icons.campaign_rounded,
        adminPurple,
        () => AdminNavigation.goToDiffusion(context, subTab: 1),
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: chips
            .map((c) => _actionChip(context, c, dense: true))
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _actionChip(context, chips[i])),
        ],
      ],
    );
  }

  Widget _actionChip(BuildContext context, _ChipDef c, {bool dense = false}) {
    return Material(
      color: c.color.withAlpha(18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: c.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 10,
            vertical: dense ? 5 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(c.icon, size: dense ? 13 : 15, color: c.color),
              SizedBox(width: dense ? 4 : 6),
              Text(
                c.label,
                style: GoogleFonts.inter(
                  fontSize: dense ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  color: c.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDef {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ChipDef(this.label, this.icon, this.color, this.onTap);
}
