import '../services/feature_flags_service.dart';

/// Onglet **Communauté** (chat) — visible **uniquement pour les comptes connectés**
/// (pas en mode invité : invité = Actus seules).
///
/// Firestore : `app_config/feature_flags` → [flagKey].
/// Clé absente → onglet activé **après connexion** ; `false` pour masquer.
abstract final class CommunityChatRollout {
  static const String flagKey = 'show_community_chat_tab';

  static bool get isVisible {
    final m = FeatureFlagsService.notifier.value;
    if (!m.containsKey(flagKey)) return true;
    return m[flagKey] == true;
  }
}
