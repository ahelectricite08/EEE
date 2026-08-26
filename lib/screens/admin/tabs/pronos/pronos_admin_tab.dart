import 'package:flutter/material.dart';

import '../../admin_module_shell.dart';
import '../../admin_module_colors.dart';
import '../../admin_controller.dart';
import '../../admin_nav_model.dart';
import '../../../../models/user_role.dart';
import '../communaute/admin_duels_leagues_section.dart';
import '../settings/extra_admin_sections.dart';
import 'best_scorer_challenge_admin_section.dart';
import 'powered_by_partner_admin_section.dart';
import 'prono_banners_admin_section.dart';
import 'prono_games_stats_section.dart';
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
      subtitle:
          'Championnat et défis, duels / ligues, puis visibilité, bannières et encart partenaire.',
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
    final isAdmin =
        AdminController.maybeOf(context)?.userRoles.contains(UserRole.admin) ??
            false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const PronosChampionshipOverview(),
        const SizedBox(height: 24),
        const PronoGamesStatsSection(),
        const SizedBox(height: 24),
        const AdminModuleSection(
          eyebrow: 'Défi saison',
          title: 'Meilleur buteur',
          subtitle:
              'Liste de joueurs pour le défi d’accueil Pronos, puis déclaration '
              'du vainqueur (+10 pts classement général).',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: BestScorerChallengeAdminSection(),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 28),
          const PronoSeasonResetCard(),
        ],
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
        const AdminModuleSection(
          eyebrow: 'Onglet app',
          title: 'Visibilité Pronos',
          subtitle: 'Active ou masque l’onglet Pronos dans l’app mobile.',
          accent: AdminModuleColors.jeux,
          child: PronoHubRolloutAdminSection(),
        ),
        const SizedBox(height: 20),
        const AdminModuleSection(
          eyebrow: 'Visuels Pronos',
          title: 'Bannières',
          subtitle:
              'Bandeaux hero (Accueil / Matchs / Progression / Social) '
              'et fonds de blocs (Ligues / Classement / Feuille de prono).',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: PronoBannersAdminSection(),
        ),
        const SizedBox(height: 20),
        const AdminModuleSection(
          eyebrow: 'Partenaire',
          title: 'Encart « Propulsé par »',
          subtitle: 'Logo et textes en bas du hub Pronos championnat.',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: PoweredByPartnerAdminSection(),
        ),
        const SizedBox(height: 20),
        const AdminModuleSection(
          eyebrow: 'Hors championnat',
          title: 'Historique des votes',
          subtitle:
              'Votes MOTM et sondages émission clos — pas le jeu Pronos.',
          accent: AdminModuleColors.jeux,
          wrapInCard: false,
          child: VoteHistorySection(),
        ),
      ],
    );
  }
}
