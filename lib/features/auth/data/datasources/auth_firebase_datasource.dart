import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thin Firebase Auth + Firestore users ACL for Auth.
///
/// Presentation must not call this directly — go through [AuthRepository].
class AuthFirebaseDatasource {
  AuthFirebaseDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates `users/{uid}` with the same fields as legacy [AuthService.register].
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
  }) {
    final trimmedEmail = email.trim();
    final trimmedFirst = firstName.trim();
    final trimmedLast = lastName.trim();
    final displayName = '$trimmedFirst $trimmedLast'.trim();
    return _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': trimmedEmail,
      'emailLower': trimmedEmail.toLowerCase(),
      'firstName': trimmedFirst,
      'lastName': trimmedLast,
      'firstNameLower': trimmedFirst.toLowerCase(),
      'lastNameLower': trimmedLast.toLowerCase(),
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
      'role': 'supporter',
      'roles': ['supporter'],
      'isActive': true,
      'canAccessChat': true,
      'totalDonations': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
