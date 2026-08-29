import 'package:flutter/material.dart';

import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import 'quiz_raffle_admin_section.dart';

/// Onglet Reward — quiz antenne + tirage.
class RewardTab extends StatelessWidget {
  const RewardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminTabPage(
      title: 'Reward',
      subtitle:
          'Titre Live, quiz antenne, tirage parmi les bonnes réponses, historique des gagnants.',
      icon: Icons.emoji_events_rounded,
      accent: AdminModuleColors.jeux,
      children: [
        QuizRaffleAdminSection(),
      ],
    );
  }
}
