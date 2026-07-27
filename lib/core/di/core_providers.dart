import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global utility providers live here.
///
/// Conventions (Feature First + Riverpod):
/// - **DI** = Riverpod providers only. Do not add new métier singletons.
/// - Feature repositories / use cases → `features/<name>/presentation/*_providers.dart`
/// - Override in tests via [ProviderContainer] / [ProviderScope] overrides.
/// - Keep this file free of feature imports (`features/*` forbidden in `core/`).
///
/// Foundation ships an empty utility surface on purpose: Auth (next module)
/// will introduce the first real providers (session, auth repository).

/// Marker that Riverpod DI is available. Useful for smoke / override tests.
final foundationReadyProvider = Provider<bool>((ref) => true);
