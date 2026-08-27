import 'package:flutter/material.dart';

import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../settings/hub_heroes_admin_section.dart';
import '../settings/profile_hero_backgrounds_admin_section.dart';
import 'match_partner_logos_admin_section.dart';
import 'match_ticketing_admin_section.dart';
import 'social_links_admin_section.dart';

/// Photos hero / carrousel profil / liens réseaux / partenaires match.
class VisuelsAdminTab extends StatefulWidget {
  const VisuelsAdminTab({super.key});

  @override
  State<VisuelsAdminTab> createState() => _VisuelsAdminTabState();
}

class _VisuelsAdminTabState extends State<VisuelsAdminTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabPageWithSubTabs(
      title: 'Photos & réseaux',
      subtitle:
          'Heroes des onglets, fonds du bandeau profil, liens Nos réseaux, '
          'billetterie Accueil, puis les logos partenaires de match.',
      icon: Icons.photo_library_rounded,
      accent: AdminModuleColors.contenu,
      controller: _tc,
      tabs: const [
        Tab(text: 'PHOTOS HERO'),
        Tab(text: 'FONDS PROFIL'),
        Tab(text: 'NOS RÉSEAUX'),
        Tab(text: 'PARTENAIRES MATCH'),
      ],
      tabViews: [
        const _VisuelsPane(child: HubHeroesAdminSection()),
        const _VisuelsPane(child: ProfileHeroBackgroundsAdminSection()),
        const _VisuelsPane(
          child: Column(
            children: [
              MatchTicketingAdminSection(),
              SizedBox(height: 20),
              SocialLinksAdminSection(),
            ],
          ),
        ),
        const _VisuelsPane(child: MatchPartnerLogosAdminSection()),
      ],
    );
  }
}

class _VisuelsPane extends StatelessWidget {
  const _VisuelsPane({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [child],
    );
  }
}
