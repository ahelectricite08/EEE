import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Actions admin sur les comptes Firebase (Auth + données liées).
class AdminUserFirebaseActionsService {
  AdminUserFirebaseActionsService._();

  static final _fn = FirebaseFunctions.instance;

  /// Envoie l’email officiel Firebase de réinitialisation du mot de passe.
  static Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw ArgumentError('Email vide');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
  }

  /// Supprime le compte Auth + doc `users/{uid}` (callable `adminDeleteAuthUser`).
  static Future<void> deleteAuthUserAndFirestoreData(String uid) async {
    final u = uid.trim();
    if (u.isEmpty) {
      throw ArgumentError('uid vide');
    }
    await _fn.httpsCallable('adminDeleteAuthUser').call(<String, dynamic>{'uid': u});
  }
}
