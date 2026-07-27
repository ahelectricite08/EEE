import 'package:flutter/material.dart';

import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../settings/tv_settings_panel.dart';

/// Onglet admin dédié Android TV (sidebar → Système).
class TvAdminTab extends StatelessWidget {
  const TvAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: 'Android TV',
            subtitle:
                'Flux HLS, direct TV, récaps audience — visible selon la permission « admin.tv ».',
            icon: Icons.live_tv_rounded,
            accent: AdminModuleColors.administration,
          ),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TvSettingsPanel(),
          ),
        ),
      ],
    );
  }
}
