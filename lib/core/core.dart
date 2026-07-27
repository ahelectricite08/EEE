/// Public barrel for `lib/core/` (Foundation).
///
/// Import rules:
/// - Features may import `package:dvcr/core/core.dart` (or specific core files).
/// - `core/` must **never** import `features/*`.
/// - Prefer typed [AppFailure] / [Result] at domain/data boundaries.
///
/// Freezed / json_serializable: dependencies are prepared in `pubspec.yaml`
/// for Auth+. No Freezed model in Foundation (avoid empty codegen noise).
library;

export 'config/app_config.dart';
export 'di/core_providers.dart';
export 'errors/app_failure.dart';
export 'errors/result.dart';
