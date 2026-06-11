import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_controller.dart';
import 'admin_nav_model.dart';
import 'tabs/matchs/match_editor.dart';
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

  static void goToPronos(BuildContext context) =>
      goToTab(context, AdminTabIndex.pronos);

  /// Ouvre l’éditeur fiche match (onglet Match).
  static Future<void> openMatchEditor(
    BuildContext context, {
    required String matchId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId.trim())
        .get();
    if (!context.mounted) return;
    if (!snap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match introuvable')),
      );
      return;
    }
    goToMatchs(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchEditorScreen(doc: snap),
      ),
    );
  }

  /// Workbench stats du match actuellement en direct (onglet Statistiques match).
  static Future<void> openLiveStatsWorkbench(BuildContext context) async {
    final snap = await FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .get();
    if (!context.mounted) return;
    if (!snap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun match en direct')),
      );
      return;
    }
    final data = snap.data() ?? {};
    final matchId = (data['matchId'] as String? ?? '').trim();
    if (matchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Liez un match du calendrier au démarrage du live (matchId).',
          ),
        ),
      );
      goToDirect(context);
      return;
    }
    await openStatsWorkbench(
      context,
      matchId: matchId,
      team1: data['team1'] as String? ?? '',
      team2: data['team2'] as String? ?? '',
    );
  }

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
    final admin = controller(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminControllerProvider(
          controller: admin,
          child: MatchStatsWorkbenchScreen(
            matchId: matchId,
            team1: team1,
            team2: team2,
          ),
        ),
      ),
    );
  }
}
