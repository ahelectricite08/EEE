import '../services/feature_flags_service.dart';

/// Mise en ligne progressive du hub **pronos championnat** (onglet barre, prono ligue, duels…).
/// L’onglet **CdM 2026** est piloté séparément (`world_cup_tab_rollout.dart`).
///
/// Admin : document Firestore `app_config/feature_flags`, clé booléenne [hubFlagKey].
/// Tant que la clé est absente ou `false`, le hub championnat est masqué.
abstract final class PronoChampionshipRollout {
  static const String hubFlagKey = 'show_prono_championship_hub';

  static bool get isHubVisible => FeatureFlagsService.flagOn(hubFlagKey);
}
