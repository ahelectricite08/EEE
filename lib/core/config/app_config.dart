/// Non-secret app-level constants for modernized modules.
///
/// Product branding / theme stay in `lib/theme/`. Tenant-specific config
/// (club id, flags) will land here or as Riverpod providers when Auth/Home
/// need them — not as new static métier services.
abstract final class AppConfig {
  static const String appName = 'DVCR';

  /// Package name (`pubspec.yaml` → `name:`).
  static const String packageName = 'dvcr';
}
