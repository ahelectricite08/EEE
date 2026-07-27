import 'package:flutter/material.dart';

import '../../admin_module_shell.dart';
import '../../admin_module_colors.dart';
import '../../admin_controller.dart';
import '../../admin_nav_model.dart';
import '../communaute/admin_duels_leagues_section.dart';
import '../settings/extra_admin_sections.dart';
import 'prono_banners_admin_section.dart';
import 'prono_season_reset_card.dart';
import 'pronos_championship_overview.dart';
import 'vote_history_section.dart';

/// Pronos, duels/ligues et visibilité — page Jeux unifiée.
class PronosAdminTab extends StatefulWidget {
  const PronosAdminTab({super.key});

  @override
  State<PronosAdminTab> createState() => _PronosAdminTabState();
}

class _PronosAdminTabState extends State<PronosAdminTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  AdminController? _ctrl;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _tc.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AdminController.maybeOf(context);
    if (ctrl != null && ctrl != _ctrl) {
      _ctrl?.removeListener(_syncFromController);
      _ctrl = ctrl;
      _ctrl!.addListener(_syncFromController);
      _syncFromController();
    }
  }

  void _syncFromController() {
    if (_ctrl == null || !_tc.indexIsChanging) {
      final target = _ctrl?.pronosSubTab ?? AdminTabIndex.pronosSubChampionnat;
      if (_tc.index != target) {
        _tc.animateTo(target);
      }
    }
  }

  void _onTabChanged() {
    if (_tc.indexIsChanging) return;
    _ctrl?.setPronosSubTab(_tc.index);
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_syncFromController);
    _tc.removeListener(_onTabChanged);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabPageWithSubTabs(
      title: 'Pronos & jeux',
      subtitle: 'Championnat, duels et visibilité.',
      icon: Icons.casino_rounded,
      accent: AdminModuleColors.jeux,
      controller: _tc,
      tabs: const [
        Tab(text: 'CHAMPIONNAT'),
        Tab(text: 'DUELS & LIGUES'),
        Tab(text: 'VISIBILITÉ'),
      ],
      tabViews: const [
        _ChampionnatPanel(),
        _DuelsPanel(),
        _VisibilitePanel(),
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
        PronoSeasonResetCard(),
        SizedBox(height: 24),
        PronosChampionshipOverview(),
      ],
    );
  }
}

class _DuelsPanel extends StatelessWidget {
  const _DuelsPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        AdminDuelsLeaguesSection(),
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
        AdminModuleSection(
          eyebrow: 'Visibilité',
          title: 'Pronos championnat',
          subtitle: 'Active ou masque l\'onglet Pronos dans l\'app mobile.',
          accent: AdminModuleColors.jeux,
          child: const PronoHubRolloutAdminSection(),
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Visibilité',
          title: 'Bannières Pronos',
          subtitle:
              'URLs Wix (image directe) pour les bandeaux hero Accueil / Matchs / Progression / Social.',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: const PronoBannersAdminSection(),
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Communauté',
          title: 'Historique des votes',
          subtitle: 'Votes MOTM et sondages émission clos (hors prono championnat).',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: const VoteHistorySection(),
        ),
      ],
    );
  }
}
