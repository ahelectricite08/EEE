import 'package:flutter/material.dart';

import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import 'app_store_safe_mode_admin_section.dart';
import 'app_version_admin_section.dart';
import 'extra_admin_sections.dart';
import 'fff_season_settings_panel.dart';
import 'season_lifecycle_admin_section.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const AdminInteriorHub(
      title: 'Application',
      subtitle: 'Une rubrique à la fois — store, version, saisons FFF.',
      icon: Icons.settings_rounded,
      accent: AdminModuleColors.administration,
      items: [
        AdminInteriorItem(
          title: 'Passage App Store',
          subtitle: 'Mode review : masquer dons, adhésion, contenus sensibles.',
          icon: Icons.phone_iphone_rounded,
          group: 'Store',
          child: AppStoreSafeModeAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Maintenance & version',
          subtitle: 'Numéro d’app, message de maintenance.',
          icon: Icons.build_rounded,
          group: 'Store',
          child: AppVersionAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Saisons & fonctionnalités',
          subtitle: 'Cycle de saison, flags de features.',
          icon: Icons.flag_rounded,
          group: 'Saison',
          child: SeasonLifecycleAdminSection(),
        ),
        AdminInteriorItem(
          title: 'Saisons de compétition',
          subtitle: 'Liste des saisons et archivage.',
          icon: Icons.inventory_2_rounded,
          group: 'Saison',
          child: CompetitionSeasonsSection(),
        ),
        AdminInteriorItem(
          title: 'Saison FFF',
          subtitle: 'Calendrier, poules R1/R2, synchro classement.',
          icon: Icons.sports_soccer_rounded,
          group: 'Saison',
          fill: true,
          child: FffSeasonSettingsPanel(),
        ),
      ],
    );
  }
}
