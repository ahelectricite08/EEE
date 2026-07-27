import 'package:dvcr/core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Maps Firebase Auth (and related) errors to [AppFailure] with FR messages.
///
/// Parity with legacy `AuthService.errorMessage` — same codes and English hints.
AppFailure mapAuthException(Object error) {
  if (error is AppFailure) return error;

  if (error is FirebaseAuthException) {
    final byCode = _messageForAuthCode(error.code);
    if (byCode != null) {
      return _failureForCode(error.code, byCode, error);
    }
    final byHint = _messageFromEnglishHint(error.message);
    if (byHint != null) {
      return AuthFailure(message: byHint, cause: error);
    }
    return AuthFailure(message: _echecConnexion, cause: error);
  }

  final byHint = _messageFromEnglishHint(error.toString());
  if (byHint != null) {
    return AuthFailure(message: byHint, cause: error);
  }
  return UnexpectedFailure(
    message: 'Une erreur inattendue s’est produite. Réessaie dans un instant.',
    cause: error,
  );
}

/// French user-facing string (legacy `AuthService.errorMessage` API).
String mapAuthExceptionToFr(Object error) => mapAuthException(error).messageFr;

const _echecConnexion =
    'Connexion impossible. Vérifie ton e-mail et ton mot de passe, puis réessaie.';

AppFailure _failureForCode(String code, String message, Object cause) {
  if (code == 'network-request-failed') {
    return NetworkFailure(message: message, cause: cause);
  }
  return AuthFailure(message: message, cause: cause);
}

String? _messageForAuthCode(String code) {
  switch (code) {
    case 'invalid-email':
      return 'L’adresse e-mail n’est pas valide.';
    case 'user-disabled':
      return 'Ce compte a été désactivé. Contacte l’équipe DVCR si besoin.';
    case 'user-not-found':
      return 'Aucun compte n’est associé à cette adresse e-mail.';
    case 'wrong-password':
      return 'Mot de passe incorrect.';
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'E-mail ou mot de passe incorrect. Vérifie tes identifiants '
          'ou appuie sur « Mot de passe oublié ».';
    case 'email-already-in-use':
      return 'Un compte existe déjà avec cet e-mail. Connecte-toi ou '
          'réinitialise ton mot de passe.';
    case 'weak-password':
      return 'Mot de passe trop court : au moins 6 caractères.';
    case 'operation-not-allowed':
      return 'La connexion par e-mail n’est pas disponible pour le moment.';
    case 'too-many-requests':
      return 'Trop de tentatives. Attends quelques minutes avant de réessayer.';
    case 'network-request-failed':
      return 'Pas de connexion Internet. Vérifie ton réseau et réessaie.';
    case 'requires-recent-login':
      return 'Pour ta sécurité, reconnecte-toi avant de faire cette action.';
    case 'credential-already-in-use':
      return 'Ces identifiants sont déjà utilisés par un autre compte.';
    case 'account-exists-with-different-credential':
      return 'Un compte existe déjà avec cet e-mail via une autre méthode de connexion.';
    default:
      return null;
  }
}

String? _messageFromEnglishHint(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final t = text.toLowerCase();
  if (t.contains('auth credential') ||
      t.contains('invalid credential') ||
      t.contains('invalid login') ||
      t.contains('wrong password') ||
      t.contains('user not found') ||
      t.contains('malformed') ||
      t.contains('has expired') ||
      t.contains('supplied auth')) {
    return 'E-mail ou mot de passe incorrect. Vérifie tes identifiants '
        'ou appuie sur « Mot de passe oublié ».';
  }
  if (t.contains('network')) {
    return 'Pas de connexion Internet. Vérifie ton réseau et réessaie.';
  }
  if (t.contains('too many')) {
    return 'Trop de tentatives. Attends quelques minutes avant de réessayer.';
  }
  if (t.contains('email') && t.contains('already')) {
    return 'Un compte existe déjà avec cet e-mail.';
  }
  if (t.contains('weak password')) {
    return 'Mot de passe trop court : au moins 6 caractères.';
  }
  return null;
}
