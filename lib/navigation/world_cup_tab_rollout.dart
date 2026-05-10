import '../services/feature_flags_service.dart';

import 'prono_championship_rollout.dart';

/// Affiche ou masque l’onglet principal **CdM 2026** (barre du bas + raccourcis qui y mènent).
///
/// Firestore : `app_config/feature_flags` → clé booléenne [tabFlagKey].
///
/// **Rétrocompat** : si la clé est **absente**, l’onglet CdM reste visible (comportement
/// d’origine). Mettre explicitement `false` pour le masquer.
abstract final class WorldCupTabRollout {
  static const String tabFlagKey = 'show_world_cup_tab';

  static bool get isTabVisible {
    final m = FeatureFlagsService.notifier.value;
    if (!m.containsKey(tabFlagKey)) return true;
    return m[tabFlagKey] == true;
  }

  /// Index 0-based de l’onglet CdM quand il est affiché ; `null` si masqué par le flag.
  static int? mainTabIndexWhenVisible() {
    if (!isTabVisible) return null;
    return 5 + (PronoChampionshipRollout.isHubVisible ? 1 : 0);
  }

  /// Pour [onSwitchTab] : index CdM si visible, sinon **0** (accueil).
  static int targetMainTabIndexOrHome() =>
      mainTabIndexWhenVisible() ?? 0;
}
