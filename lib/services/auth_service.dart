import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Connexion avec email + mot de passe
  static Future<UserModel?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user == null) return null;
    return _fetchUser(cred.user!.uid);
  }

  /// Inscription avec prénom, nom, email, mot de passe
  static Future<UserModel?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user == null) return null;

    await _db.collection('users').doc(cred.user!.uid).set({
      'uid':            cred.user!.uid,
      'email':          email.trim(),
      'emailLower':     email.trim().toLowerCase(),
      'firstName':      firstName.trim(),
      'lastName':       lastName.trim(),
      'displayName':    '${firstName.trim()} ${lastName.trim()}',
      'role':           'supporter',
      'roles':          ['supporter'],
      'isActive':       true,
      'canAccessChat':  true,
      'totalDonations': 0.0,
      'createdAt':      FieldValue.serverTimestamp(),
      'lastLogin':      FieldValue.serverTimestamp(),
    });

    return UserModel(
      uid:       cred.user!.uid,
      firstName: firstName.trim(),
      lastName:  lastName.trim(),
      email:     email.trim(),
      role:      UserRole.supporter,
      createdAt: DateTime.now(),
    );
  }

  /// Déconnexion
  static Future<void> signOut() => _auth.signOut();

  /// Récupérer le profil utilisateur depuis Firestore
  static Future<UserModel?> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  /// Récupérer l'utilisateur courant avec son rôle
  static Future<UserModel?> getCurrentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _fetchUser(u.uid);
  }

  /// Réinitialisation du mot de passe
  static Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static const String _echecConnexion =
      'Connexion impossible. Vérifie ton e-mail et ton mot de passe, puis réessaie.';

  /// Messages d’erreur Firebase Auth — toujours en français, jamais le texte brut Firebase.
  static String errorMessage(Object e) {
    if (e is FirebaseAuthException) {
      final byCode = _messageForAuthCode(e.code);
      if (byCode != null) return byCode;
      final byHint = _messageFromEnglishHint(e.message);
      if (byHint != null) return byHint;
      return _echecConnexion;
    }
    final byHint = _messageFromEnglishHint(e.toString());
    if (byHint != null) return byHint;
    return 'Une erreur inattendue s’est produite. Réessaie dans un instant.';
  }

  static String? _messageForAuthCode(String code) {
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

  /// Dernier filet si Firebase renvoie encore un libellé en anglais dans [message].
  static String? _messageFromEnglishHint(String? text) {
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
}
