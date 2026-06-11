import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sons courts quand un fait de jeu apparaît sur la bannière live (écran verrouillé).
abstract final class LiveEventSoundService {
  LiveEventSoundService._();

  /// Ne pas doubler un son si l’app est au premier plan (l’admin voit déjà l’UI).
  static bool get _ambientContext {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  static Future<void> maybePlayForEvent(String type) async {
    if (kIsWeb || type.trim().isEmpty) return;
    if (!_ambientContext) return;

    switch (type) {
      case 'goal':
      case 'own_goal':
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
        break;
      case 'red':
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.mediumImpact();
        break;
      case 'yellow':
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.lightImpact();
        break;
      case 'substitution':
      case 'goal_cancelled':
      case 'goal_disallowed':
      case 'offside':
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.selectionClick();
        break;
      default:
        break;
    }
  }

  /// Haptique seule (Live Activity iOS : le son passe par AlertConfig).
  static Future<void> maybeHapticForEvent(String type) async {
    if (kIsWeb || type.trim().isEmpty) return;
    if (!_ambientContext) return;

    switch (type) {
      case 'goal':
      case 'own_goal':
        await HapticFeedback.heavyImpact();
        break;
      case 'red':
        await HapticFeedback.mediumImpact();
        break;
      case 'yellow':
        await HapticFeedback.lightImpact();
        break;
      case 'substitution':
      case 'goal_cancelled':
      case 'goal_disallowed':
      case 'offside':
        await HapticFeedback.selectionClick();
        break;
      default:
        break;
    }
  }
}
