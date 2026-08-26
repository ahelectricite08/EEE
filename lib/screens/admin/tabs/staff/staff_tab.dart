import 'package:flutter/material.dart';

import '../../admin_module_shell.dart';
import '../../admin_module_colors.dart';
import '../settings/staff_permissions_panel.dart';
import '../settings/staff_role_badges_panel.dart';

/// Staff & permissions : matrice RBAC et badges (sponsors → Association / Marque).
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
    _tc = TabController(length: 2, vsync: this);
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
      subtitle: 'Matrice RBAC et badges visuels des rôles. Catalogue sponsors : Association → Marque.',
      icon: Icons.admin_panel_settings_rounded,
      accent: AdminModuleColors.administration,
      controller: _tc,
      tabs: const [
        Tab(text: 'PERMISSIONS'),
        Tab(text: 'BADGES RÔLES'),
      ],
      tabViews: const [
        StaffPermissionsPanel(),
        StaffRoleBadgesPanel(),
      ],
    );
  }
}
