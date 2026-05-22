import '../services/feature_flags_service.dart';

/// Onglet **Communauté** (chat tribune) — piloté depuis l’admin.
///
/// Firestore : `app_config/feature_flags` → [flagKey].
/// **Rétrocompat** : clé absente → onglet **visible** ; `false` explicite pour masquer.
abstract final class CommunityChatRollout {
  static const String flagKey = 'show_community_chat_tab';

  static bool get isVisible {
    final m = FeatureFlagsService.notifier.value;
    if (!m.containsKey(flagKey)) return true;
    return m[flagKey] == true;
  }
}
