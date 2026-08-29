import 'package:flutter/material.dart';

import '../services/feature_flags_service.dart';

/// Kill switch App Store — masque l’adhésion / VOD adhérents / bannières
/// partenaire dans **l’app utilisateur**, sans toucher à la config Firestore.
///
/// Doc : `app_config/feature_flags` → [flagKey].
/// Clé absente ou `false` → app normale. `true` → mode review Apple.
abstract final class AppStoreSafeMode {
  static const String flagKey = 'hideMonetizationForAppStore';

  static bool hidesUserMonetization(Map<String, dynamic>? data) =>
      FeatureFlagsService.isEnabled(data, flagKey);

  static bool get isHidingNow => FeatureFlagsService.flagOn(flagKey);
}

/// Masque [child] dès que [AppStoreSafeMode.flagKey] est vrai (stream live).
/// [bypass] = aperçu admin : toujours affiché.
class AppStoreMonetizationGate extends StatelessWidget {
  final Widget child;
  final bool bypass;

  const AppStoreMonetizationGate({
    super.key,
    required this.child,
    this.bypass = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bypass) return child;
    return StreamBuilder<Map<String, dynamic>>(
      stream: FeatureFlagsService.stream(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        if (AppStoreSafeMode.hidesUserMonetization(snap.data)) {
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
