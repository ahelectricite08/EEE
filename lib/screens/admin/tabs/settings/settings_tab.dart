import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import 'app_version_admin_section.dart';
import 'app_store_safe_mode_admin_section.dart';
import 'extra_admin_sections.dart';
import 'fff_season_settings_panel.dart';
import 'season_lifecycle_admin_section.dart';

/// Réglages application — plus un fourre-tout (visuels, asso, chat, pronos ailleurs).
class SettingsTab extends StatefulWidget {
  const SettingsTab();

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
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
    const accent = AdminModuleColors.administration;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: 'Application',
            subtitle:
                'Version, maintenance, saisons FFF. Photos, Soutenez, chat et pronos sont dans leurs sections.',
            icon: Icons.settings_rounded,
            accent: accent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AdminSubTabBar(
            controller: _tc,
            accent: accent,
            tabs: const [
              Tab(text: 'APPLICATION'),
              Tab(text: 'SAISON FFF'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _AppSettingsPanel(),
              FffSeasonSettingsPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppSettingsPanel extends StatelessWidget {
  const _AppSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const _SettingsGroupTitle('Passage App Store'),
        AppStoreSafeModeAdminSection(),
        const SizedBox(height: 20),
        const _SettingsGroupTitle('Maintenance & version'),
        AppVersionAdminSection(),
        const SizedBox(height: 20),
        const _SettingsGroupTitle('Saisons & fonctionnalités'),
        const SeasonLifecycleAdminSection(),
        const SizedBox(height: 20),
        const CompetitionSeasonsSection(),
      ],
    );
  }
}

class _SettingsGroupTitle extends StatelessWidget {
  final String title;

  const _SettingsGroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: adminOrange,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
