import 'package:flutter/material.dart';

import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../settings/staff_permissions_panel.dart';
import '../settings/staff_role_badges_panel.dart';

/// Staff & permissions : postes RBAC et badges.
class StaffTab extends StatelessWidget {
  const StaffTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminInteriorHub(
      title: 'Staff & postes',
      subtitle: 'Une rubrique à la fois — qui voit quoi, puis badges.',
      icon: Icons.admin_panel_settings_rounded,
      accent: AdminModuleColors.administration,
      items: [
        AdminInteriorItem(
          title: 'Postes',
          subtitle: 'Admin, CM, commentateur, éditeur, statisticien.',
          icon: Icons.badge_rounded,
          group: 'Accès',
          fill: true,
          child: StaffPermissionsPanel(),
        ),
        AdminInteriorItem(
          title: 'Badges rôles',
          subtitle: 'Pastilles chat / profil par rôle.',
          icon: Icons.military_tech_rounded,
          group: 'Apparence',
          fill: true,
          child: StaffRoleBadgesPanel(),
        ),
      ],
    );
  }
}
