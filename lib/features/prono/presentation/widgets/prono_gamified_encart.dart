import 'package:flutter/material.dart';

import 'prono_ui.dart';

/// Note éditoriale — filet or, kicker, corps discret. Jamais une carte.
///
/// Les trois fabriques portent la copie partagée du module ; d’autres écrans
/// les appellent, leur signature ne bouge pas.
class PronoGamifiedTipCard extends StatelessWidget {
  final String headline;
  final String body;
  final IconData icon;

  const PronoGamifiedTipCard({
    super.key,
    required this.headline,
    required this.body,
    this.icon = Icons.info_outline_rounded,
  });

  factory PronoGamifiedTipCard.xpRules() {
    return const PronoGamifiedTipCard(
      headline: 'Même barème partout',
      icon: Icons.rule_rounded,
      body:
          'Les pronos s’ouvrent en général 7 jours avant le coup d’envoi. '
          'Régularité, bons résultats, scores exacts et duels alimentent le même XP.',
    );
  }

  factory PronoGamifiedTipCard.matchWindow() {
    return const PronoGamifiedTipCard(
      headline: 'Fenêtre de prono',
      icon: Icons.schedule_rounded,
      body:
          'Les matchs s’ouvrent 7 jours avant le coup d’envoi. '
          'Tape sur une ligne pour placer ton score.',
    );
  }

  factory PronoGamifiedTipCard.socialArena() {
    return const PronoGamifiedTipCard(
      headline: 'Communauté',
      icon: Icons.groups_rounded,
      body:
          'Ligues privées, duels et amis : tout alimente la même XP que tes pronos.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PronoFootnote(heading: headline, text: body);
  }
}
