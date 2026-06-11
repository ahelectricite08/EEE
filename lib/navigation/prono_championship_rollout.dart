import '../services/feature_flags_service.dart';

/// Onglet **Pronos** championnat (ligues, duels…) — séparé du chat.
///
/// Firestore : `app_config/feature_flags` → [hubFlagKey] (défaut **masqué**).
abstract final class PronoChampionshipRollout {
  static const String hubFlagKey = 'show_prono_championship_hub';

  static bool get isHubVisible => FeatureFlagsService.flagOn(hubFlagKey);
}
