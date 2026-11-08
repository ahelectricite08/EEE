import 'package:flutter/material.dart';

import '../../admin_controller.dart';
import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../notifs/match_reminder_tab.dart';
import '../notifs/notifs_tab.dart';

/// Push manuelle + rappel match (un seul onglet sidebar).
class DiffusionTab extends StatelessWidget {
  const DiffusionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AdminControllerProvider.of(context);
    return AdminInteriorHub(
      title: 'Notifications',
      subtitle: 'Une rubrique à la fois — push manuelle ou rappel match.',
      icon: Icons.send_rounded,
      accent: AdminModuleColors.administration,
      onOpen: ctrl.setDiffusionSubTab,
      items: const [
        AdminInteriorItem(
          title: 'Push manuelle',
          subtitle: 'Envoyer une notif à tout le monde ou un groupe.',
          icon: Icons.campaign_rounded,
          group: 'Diffusion',
          fill: true,
          child: NotifsTab(embedded: true),
        ),
        AdminInteriorItem(
          title: 'Rappel match',
          subtitle: 'Rappel auto avant le coup d’envoi Sedan.',
          icon: Icons.alarm_rounded,
          group: 'Diffusion',
          fill: true,
          child: MatchReminderTab(embedded: true),
        ),
      ],
    );
  }
}
