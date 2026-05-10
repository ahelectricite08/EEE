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

  /// Mapping erreurs Firebase → message lisible
  static String errorMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':    return 'Aucun compte avec cet email.';
        case 'wrong-password':    return 'Mot de passe incorrect.';
        case 'email-already-in-use': return 'Cet email est déjà utilisé.';
        case 'weak-password':    return 'Mot de passe trop faible (6 caractères min).';
        case 'invalid-email':    return 'Email invalide.';
        default: return 'Erreur : ${e.message}';
      }
    }
    return 'Une erreur est survenue.';
  }
}
