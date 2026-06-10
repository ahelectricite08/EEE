import '../services/feature_flags_service.dart';

import 'community_chat_rollout.dart';
import 'prono_championship_rollout.dart';
import 'world_cup_tab_rollout.dart';

/// Affiche ou masque l'onglet **ESTI'DVCR** (pronostics tournoi).
///
/// Firestore : `app_config/feature_flags` → clé booléenne [tabFlagKey].
/// Si la clé est **absente**, l'onglet est **masqué** par défaut.
abstract final class EstiDvcrRollout {
  static const String tabFlagKey = 'show_esti_dvcr_tab';

  static bool get isTabVisible {
    final m = FeatureFlagsService.notifier.value;
    if (!m.containsKey(tabFlagKey)) return false;
    return m[tabFlagKey] == true;
  }

  /// Index 0-based de l'onglet ESTI'DVCR quand il est affiché ; `null` si masqué.
  static int? mainTabIndexWhenVisible() {
    if (!isTabVisible) return null;
    var idx = 4;
    if (CommunityChatRollout.isVisible) idx++;
    if (PronoChampionshipRollout.isHubVisible) idx++;
    if (WorldCupTabRollout.isTabVisible) idx++;
    return idx;
  }

  /// Pour navigation directe : index si visible, sinon **0** (accueil).
  static int targetMainTabIndexOrHome() => mainTabIndexWhenVisible() ?? 0;
}
