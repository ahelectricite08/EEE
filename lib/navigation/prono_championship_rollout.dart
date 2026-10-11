import '../services/feature_flags_service.dart';

/// Onglet **Pronos** championnat (ligues, duels…) — séparé du chat.
///
/// Firestore : `app_config/feature_flags` → [hubFlagKey].
/// Clé absente → onglet activé **après connexion** ; `false` pour masquer.
abstract final class PronoChampionshipRollout {
  static const String hubFlagKey = 'show_prono_championship_hub';

  static bool get isHubVisible {
    final m = FeatureFlagsService.notifier.value;
    if (!m.containsKey(hubFlagKey)) return true;
    return m[hubFlagKey] == true;
  }
}
