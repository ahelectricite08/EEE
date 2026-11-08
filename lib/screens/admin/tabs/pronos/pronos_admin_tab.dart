import 'package:flutter/material.dart';

import '../../../../models/user_role.dart';
import '../../admin_controller.dart';
import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../../admin_nav_model.dart';
import '../communaute/admin_duels_leagues_section.dart';
import '../settings/extra_admin_sections.dart';
import 'best_scorer_challenge_admin_section.dart';
import 'first_scorer_bet_admin_section.dart';
import 'powered_by_partner_admin_section.dart';
import 'prono_banners_admin_section.dart';
import 'prono_games_stats_section.dart';
import 'prono_season_reset_card.dart';
import 'pronos_championship_overview.dart';
import 'vote_history_section.dart';

/// Pronos, duels/ligues et visibilité — une rubrique à la fois.
class PronosAdminTab extends StatelessWidget {
  const PronosAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AdminController.maybeOf(context);
    final isAdmin = ctrl?.userRoles.contains(UserRole.admin) ?? false;

    return AdminInteriorHub(
      title: 'Pronos & jeux',
      subtitle: 'Une rubrique à la fois — championnat, duels, visibilité.',
      icon: Icons.casino_rounded,
      accent: AdminModuleColors.jeux,
      onOpen: (i) {
        final duelsIndex = isAdmin ? 4 : 3;
        if (i < duelsIndex) {
          ctrl?.setPronosSubTab(AdminTabIndex.pronosSubChampionnat);
        } else if (i == duelsIndex) {
          ctrl?.setPronosSubTab(AdminTabIndex.pronosSubDuels);
        } else {
          ctrl?.setPronosSubTab(AdminTabIndex.pronosSubVisibilite);
        }
      },
      items: [
        const AdminInteriorItem(
          title: 'Championnat',
          subtitle: 'Vue d’ensemble du jeu Pronos en cours.',
          icon: Icons.emoji_events_rounded,
          group: 'Championnat',
          child: PronosChampionshipOverview(),
        ),
        const AdminInteriorItem(
          title: 'Stats des jeux',
          subtitle: 'Participation, scores, activité.',
          icon: Icons.insights_rounded,
          group: 'Championnat',
          child: PronoGamesStatsSection(),
        ),
        const AdminInteriorItem(
          title: 'Meilleur buteur',
          subtitle: 'Défi saison : liste de joueurs et vainqueur.',
          icon: Icons.sports_soccer_rounded,
          group: 'Championnat',
          child: BestScorerChallengeAdminSection(),
        ),
        if (isAdmin)
          const AdminInteriorItem(
            title: 'Reset saison',
            subtitle: 'Remise à zéro admin — irréversible.',
            icon: Icons.restart_alt_rounded,
            group: 'Championnat',
            child: PronoSeasonResetCard(),
          ),
        const AdminInteriorItem(
          title: 'Duels & ligues',
          subtitle: 'Ligues privées, codes, recherche, suppression.',
          icon: Icons.groups_rounded,
          group: 'Social',
          child: AdminDuelsLeaguesSection(),
        ),
        const AdminInteriorItem(
          title: 'Visibilité Pronos',
          subtitle: 'Afficher ou masquer l’onglet Pronos dans l’app.',
          icon: Icons.visibility_rounded,
          group: 'Visibilité',
          child: PronoHubRolloutAdminSection(),
        ),
        const AdminInteriorItem(
          title: '1er buteur',
          subtitle: 'Pari 1er buteur sur les feuilles Sedan / CSSA.',
          icon: Icons.flag_rounded,
          group: 'Visibilité',
          child: FirstScorerBetAdminSection(),
        ),
        const AdminInteriorItem(
          title: 'Bannières Pronos',
          subtitle: 'Hero Accueil / Matchs / Progression / Social.',
          icon: Icons.image_rounded,
          group: 'Visibilité',
          child: PronoBannersAdminSection(),
        ),
        const AdminInteriorItem(
          title: 'Encart partenaire',
          subtitle: 'Logo « Propulsé par » en bas du hub.',
          icon: Icons.handshake_rounded,
          group: 'Visibilité',
          child: PoweredByPartnerAdminSection(),
        ),
        const AdminInteriorItem(
          title: 'Historique des votes',
          subtitle: 'MOTM et sondages émission — pas le jeu Pronos.',
          icon: Icons.how_to_vote_rounded,
          group: 'Visibilité',
          child: VoteHistorySection(),
        ),
      ],
    );
  }
}
