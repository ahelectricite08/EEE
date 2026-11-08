import 'package:flutter/material.dart';

import '../../../../models/user_role.dart';
import '../../admin_module_colors.dart';
import '../../staff_postes.dart';

/// Outils du Direct — chacun appartient à un poste.
enum DirectLivePart {
  startStop,
  score,
  radio,
  stories,
  cinematic,
  dugauguez,
  votes,
  salon,
  emission,
  quiz,
  stats,
  postMedia,
  push,
  modo,
}

/// Ce que le compte connecté a le droit de faire dans Direct.
class DirectPosteDesk {
  final Set<DirectLivePart> parts;
  final String posteLabel;
  final String posteMission;
  final Color accent;
  final IconData icon;
  final bool adminView;

  const DirectPosteDesk({
    required this.parts,
    required this.posteLabel,
    required this.posteMission,
    required this.accent,
    required this.icon,
    this.adminView = false,
  });

  bool allows(DirectLivePart part) => parts.contains(part);

  /// Panneau profil « Démarrer / piloter le match » — sans ouvrir le back.
  bool get showsProfileLivePanel =>
      allows(DirectLivePart.startStop) ||
      allows(DirectLivePart.score) ||
      allows(DirectLivePart.radio) ||
      allows(DirectLivePart.stats) ||
      allows(DirectLivePart.stories) ||
      allows(DirectLivePart.votes);

  /// Score, chrono, XI, START/STOP — CM et admin, pas commentateur / stats.
  bool get profileCanPilot =>
      allows(DirectLivePart.startStop) || allows(DirectLivePart.score);

  String groupOf(DirectLivePart part) {
    if (!adminView) {
      switch (part) {
        case DirectLivePart.startStop:
        case DirectLivePart.score:
        case DirectLivePart.stories:
        case DirectLivePart.cinematic:
          return 'Match';
        case DirectLivePart.dugauguez:
        case DirectLivePart.votes:
          return 'Tribune';
        case DirectLivePart.radio:
        case DirectLivePart.emission:
          return 'Studio';
        case DirectLivePart.salon:
        case DirectLivePart.modo:
          return 'Chat';
        case DirectLivePart.quiz:
        case DirectLivePart.push:
          return 'Diffusion';
        case DirectLivePart.stats:
          return 'Stats';
        case DirectLivePart.postMedia:
          return 'Après';
      }
    }
    switch (part) {
      case DirectLivePart.startStop:
      case DirectLivePart.score:
      case DirectLivePart.stories:
      case DirectLivePart.cinematic:
      case DirectLivePart.dugauguez:
      case DirectLivePart.votes:
      case DirectLivePart.push:
      case DirectLivePart.quiz:
        return 'Régie · CM';
      case DirectLivePart.radio:
      case DirectLivePart.emission:
      case DirectLivePart.postMedia:
        return 'Studio · Commentateur';
      case DirectLivePart.salon:
      case DirectLivePart.modo:
        return 'Chat';
      case DirectLivePart.stats:
        return 'Stats · Statisticien';
    }
  }

  static const _cm = {
    DirectLivePart.startStop,
    DirectLivePart.score,
    DirectLivePart.stories,
    DirectLivePart.cinematic,
    DirectLivePart.dugauguez,
    DirectLivePart.votes,
    DirectLivePart.salon,
    DirectLivePart.quiz,
    DirectLivePart.postMedia,
    DirectLivePart.push,
    DirectLivePart.modo,
  };

  static const _commentateur = {
    DirectLivePart.radio,
    DirectLivePart.salon,
    DirectLivePart.emission,
    DirectLivePart.postMedia,
  };

  static const _statisticien = {
    DirectLivePart.stats,
  };

  factory DirectPosteDesk.of(Set<UserRole> roles) {
    final primary = StaffPostes.primaryOf(roles);
    if (roles.contains(UserRole.admin)) {
      return DirectPosteDesk(
        parts: DirectLivePart.values.toSet(),
        posteLabel: primary?.label ?? 'Admin',
        posteMission:
            'Tout le Direct, trié par poste — régie CM, studio, stats.',
        accent: primary?.color ?? const Color(0xFFEF5350),
        icon: primary?.icon ?? Icons.workspace_premium_rounded,
        adminView: true,
      );
    }

    final parts = <DirectLivePart>{};
    if (roles.contains(UserRole.communityManager)) parts.addAll(_cm);
    if (roles.contains(UserRole.commentateur)) parts.addAll(_commentateur);
    if (roles.contains(UserRole.statisticien)) parts.addAll(_statisticien);

    return DirectPosteDesk(
      parts: parts,
      posteLabel: primary?.label ?? 'Staff',
      posteMission: primary?.mission ?? 'Tes outils live selon ton poste.',
      accent: primary?.color ?? AdminModuleColors.live,
      icon: primary?.icon ?? Icons.sensors_rounded,
    );
  }
}
