import 'package:flutter/material.dart';

import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../settings/adherent_vod_admin_section.dart';
import '../settings/tv_featured_video_section.dart';
import '../settings/tv_next_live_section.dart';
import '../settings/tv_settings_panel.dart';
import '../settings/tv_shorts_admin_section.dart';

class TvAdminTab extends StatelessWidget {
  const TvAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminInteriorHub(
      title: 'TV / vidéos',
      subtitle: 'Une rubrique à la fois — VOD, HLS, Shorts, next live.',
      icon: Icons.tv_rounded,
      accent: AdminModuleColors.contenu,
      items: [
        AdminInteriorItem(
          title: 'VOD adhérents',
          subtitle: 'Replays réservés aux adhérents HelloAsso.',
          icon: Icons.workspace_premium_rounded,
          group: 'Vidéos',
          child: AdherentVodAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Flux HLS & direct TV',
          subtitle: 'URL MediaMTX et lancement / arrêt du flux TV.',
          icon: Icons.sensors_rounded,
          group: 'Live',
          child: TvSettingsPanel(),
        ),
        AdminInteriorItem(
          title: 'Prochain live',
          subtitle: 'Carte « next live » sur la TV.',
          icon: Icons.upcoming_rounded,
          group: 'Live',
          child: TvNextLiveSection(),
        ),
        AdminInteriorItem(
          title: 'Shorts YouTube',
          subtitle: 'Grille de shorts sur l’app / TV.',
          icon: Icons.movie_filter_rounded,
          group: 'Vidéos',
          child: TvShortsAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Vidéo mise en avant',
          subtitle: 'Spot unique en tête de TV.',
          icon: Icons.star_rounded,
          group: 'Vidéos',
          child: TvFeaturedVideoSection(),
        ),
      ],
    );
  }
}
