import 'package:flutter/material.dart';

import '../../admin_module_shell.dart';
import '../../admin_module_colors.dart';
import '../settings/staff_permissions_panel.dart';
import '../settings/staff_role_badges_panel.dart';
import 'staff_sponsors_section.dart';

/// Staff & permissions : matrice RBAC, badges rôles, sponsors (admin uniquement).
class StaffTab extends StatefulWidget {
  const StaffTab({super.key});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> with SingleTickerProviderStateMixin {
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
    return AdminTabPageWithSubTabs(
      title: 'Staff & permissions',
      subtitle: 'Matrice RBAC, badges visuels des rôles et catalogue sponsors.',
      icon: Icons.admin_panel_settings_rounded,
      accent: AdminModuleColors.administration,
      controller: _tc,
      tabs: const [
        Tab(text: 'PERMISSIONS'),
        Tab(text: 'BADGES RÔLES'),
        Tab(text: 'SPONSORS'),
      ],
      tabViews: const [
        StaffPermissionsPanel(),
        StaffRoleBadgesPanel(),
        StaffSponsorsSection(),
      ],
    );
  }
}
