import 'package:flutter/material.dart';

import 'admin_controller.dart';
import 'admin_nav_model.dart';
import 'tabs/stats/match_stats_workbench_screen.dart';

/// Navigation inter-modules admin (onglets + workbench stats).
abstract final class AdminNavigation {
  static AdminController controller(BuildContext context) =>
      AdminControllerProvider.of(context);

  static void goToTab(BuildContext context, int tabIndex) {
    controller(context).navigateTo(tabIndex);
  }

  static void goToDirect(BuildContext context) =>
      goToTab(context, AdminTabIndex.direct);

  static void goToMatchs(BuildContext context) =>
      goToTab(context, AdminTabIndex.matchs);

  static void goToStats(BuildContext context) =>
      goToTab(context, AdminTabIndex.stats);

  static void goToDiffusion(BuildContext context, {int subTab = 0}) {
    controller(context).navigateToDiffusion(subTab: subTab);
  }

  static void goToCommunaute(BuildContext context) =>
      goToTab(context, AdminTabIndex.communaute);

  static void goToLogs(BuildContext context) =>
      goToTab(context, AdminTabIndex.logs);

  static Future<void> openStatsWorkbench(
    BuildContext context, {
    required String matchId,
    required String team1,
    required String team2,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchStatsWorkbenchScreen(
          matchId: matchId,
          team1: team1,
          team2: team2,
        ),
      ),
    );
  }
}
