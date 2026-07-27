/// Typed application failures for modernized modules (Feature First + Riverpod).
///
/// Prefer mapping SDK / HTTP exceptions to [AppFailure] at the data layer,
/// then surface [messageFr] (or a feature-specific message) in presentation.
/// Do not put Flutter / Firebase imports in this file.
sealed class AppFailure implements Exception {
  const AppFailure({this.message, this.cause});

  /// Optional technical / debug message (not always user-facing).
  final String? message;

  /// Original error when wrapped (logging / diagnostics).
  final Object? cause;

  /// Default French user-facing message. Features may override in mappers.
  String get messageFr;

  @override
  String toString() => '$runtimeType(${message ?? messageFr})';
}

/// Network / connectivity / unreachable backend.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.message, super.cause});

  @override
  String get messageFr =>
      message ?? 'Connexion impossible. Vérifiez votre réseau.';
}

/// Authentication / session issues (credentials, expired session, etc.).
final class AuthFailure extends AppFailure {
  const AuthFailure({super.message, super.cause});

  @override
  String get messageFr =>
      message ?? 'Authentification impossible. Réessayez.';
}

/// Permission / role denied.
final class PermissionFailure extends AppFailure {
  const PermissionFailure({super.message, super.cause});

  @override
  String get messageFr =>
      message ?? 'Vous n’avez pas les droits pour cette action.';
}

/// Expected business rule violation (validation, conflict, not found).
final class DomainFailure extends AppFailure {
  const DomainFailure({super.message, super.cause});

  @override
  String get messageFr =>
      message ?? 'Impossible de poursuivre cette action.';
}

/// Unexpected / unmapped errors.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.message, super.cause});

  @override
  String get messageFr =>
      message ?? 'Une erreur inattendue s’est produite.';
}
