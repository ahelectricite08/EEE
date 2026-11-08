import 'package:flutter/material.dart';

import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../settings/hub_heroes_admin_section.dart';
import '../settings/league_avatars_admin_section.dart';
import '../settings/profile_avatars_admin_section.dart';
import '../settings/profile_hero_backgrounds_admin_section.dart';
import 'match_partner_logos_admin_section.dart';
import 'match_ticketing_admin_section.dart';
import 'partner_banners_admin_section.dart';
import 'social_links_admin_section.dart';

class VisuelsAdminTab extends StatelessWidget {
  const VisuelsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminInteriorHub(
      title: 'Photos & réseaux',
      subtitle: 'Une rubrique à la fois — heroes, avatars, réseaux, partenaires.',
      icon: Icons.photo_library_rounded,
      accent: AdminModuleColors.contenu,
      items: [
        AdminInteriorItem(
          title: 'Photos hero',
          subtitle: 'Images des onglets Accueil, TV, Pronos…',
          icon: Icons.photo_size_select_actual_rounded,
          group: 'App',
          child: HubHeroesAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Fonds profil',
          subtitle: 'Bandeau du profil membre.',
          icon: Icons.wallpaper_rounded,
          group: 'App',
          child: ProfileHeroBackgroundsAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Avatars membres',
          subtitle: 'Catalogue des visages (pas de photo perso).',
          icon: Icons.face_rounded,
          group: 'Avatars',
          child: ProfileAvatarsAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Avatars ligues',
          subtitle: 'Emblèmes des ligues privées.',
          icon: Icons.shield_rounded,
          group: 'Avatars',
          child: LeagueAvatarsAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Nos réseaux',
          subtitle: 'YouTube, Insta, billetterie Accueil.',
          icon: Icons.link_rounded,
          group: 'Liens',
          child: Column(
            children: [
              MatchTicketingAdminSection(),
              SizedBox(height: 20),
              SocialLinksAdminSection(),
            ],
          ),
        ),
        AdminInteriorItem(
          title: 'Partenaires match',
          subtitle: 'Logos MOTM, note, souvenirs.',
          icon: Icons.handshake_rounded,
          group: 'Partenaires',
          child: MatchPartnerLogosAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Encarts partenaires',
          subtitle: 'Bandeaux 1200×400 dans l’app.',
          icon: Icons.view_carousel_rounded,
          group: 'Partenaires',
          child: PartnerBannersAdminSection(),
        ),
      ],
    );
  }
}
