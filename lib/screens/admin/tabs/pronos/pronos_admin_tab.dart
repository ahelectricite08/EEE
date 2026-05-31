import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../communaute/admin_duels_leagues_section.dart';
import '../settings/extra_admin_sections.dart';
import '../tournament/tournament_tab.dart';
import 'prono_season_reset_card.dart';
import 'pronos_championship_overview.dart';
import 'world_cup_partner_admin_section.dart';

/// Pronos championnat, duels/ligues et Coupe du monde 2026 (admin dédié).
class PronosAdminTab extends StatefulWidget {
  const PronosAdminTab({super.key});

  @override
  State<PronosAdminTab> createState() => _PronosAdminTabState();
}

class _PronosAdminTabState extends State<PronosAdminTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

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
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: TabBar(
            controller: _tc,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: AdminUniverse.jeux.color.withAlpha(25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AdminUniverse.jeux.color.withAlpha(70)),
            ),
            labelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
            labelColor: AdminUniverse.jeux.color,
            unselectedLabelColor: adminGrey,
            tabs: const [
              Tab(text: 'CHAMPIONNAT'),
              Tab(text: 'COUPE DU MONDE'),
              Tab(text: 'VISIBILITÉ APP'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _ChampionnatPanel(),
              _CoupeDuMondePanel(),
              _VisibilitePanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChampionnatPanel extends StatelessWidget {
  const _ChampionnatPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        PronosChampionshipOverview(),
        SizedBox(height: 20),
        PronoSeasonResetCard(),
        SizedBox(height: 24),
        AdminDuelsLeaguesSection(),
      ],
    );
  }
}

class _CoupeDuMondePanel extends StatelessWidget {
  const _CoupeDuMondePanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: const [
              WorldCupTabAdminSection(),
              SizedBox(height: 16),
              WorldCupPartnerAdminSection(),
            ],
          ),
        ),
        const Expanded(child: TournamentTab()),
      ],
    );
  }
}

class _VisibilitePanel extends StatelessWidget {
  const _VisibilitePanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Onglets dans l’app mobile',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le chat Communauté se configure dans Réglages → Application. '
          'Les textes de partage prono sont dans Réglages → modèles de partage.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 16),
        const PronoHubRolloutAdminSection(),
      ],
    );
  }
}
