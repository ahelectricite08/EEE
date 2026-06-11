import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../communaute/admin_duels_leagues_section.dart';
import '../settings/extra_admin_sections.dart';
import 'prono_season_reset_card.dart';
import 'pronos_championship_overview.dart';

/// Pronos championnat — stats, duels/ligues, visibilité.
class PronosAdminTab extends StatelessWidget {
  const PronosAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AdminUniverse.jeux.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PRONOS & JEUX',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: const [
              PronosChampionshipOverview(),
              SizedBox(height: 20),
              PronoSeasonResetCard(),
              SizedBox(height: 24),
              AdminDuelsLeaguesSection(),
              SizedBox(height: 32),
              _VisibiliteSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section visibilité intégrée ───────────────────────────────────────────────
class _VisibiliteSection extends StatelessWidget {
  const _VisibiliteSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AdminUniverse.jeux.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'VISIBILITÉ APP',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Active ou masque l\'onglet Pronos dans l\'app mobile. '
          'Le chat Communauté se configure dans Réglages → Application.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        const PronoHubRolloutAdminSection(),
      ],
    );
  }
}
