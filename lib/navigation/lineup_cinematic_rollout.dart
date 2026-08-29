import '../services/feature_flags_service.dart';

/// Cinématique composition (XI + banc) — `app_config/feature_flags`.
///
/// Défaut **off** : aucune overlay tant que l’admin n’active pas le switch.
abstract final class LineupCinematicRollout {
  static const String flagKey = 'show_lineup_cinematic';

  static bool get isEnabled => FeatureFlagsService.flagOn(flagKey);
}
