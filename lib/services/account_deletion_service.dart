import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Suppression de compte côté client (RGPD — droit à l’effacement).
/// [emailPassword] requis pour les comptes e-mail / mot de passe (re-auth Firebase).
class AccountDeletionService {
  AccountDeletionService._();

  static final _db = FirebaseFirestore.instance;

  static Future<void> deleteAllFavorites(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('favorites').get();
    if (snap.docs.isEmpty) return;
    var batch = _db.batch();
    var n = 0;
    for (final d in snap.docs) {
      batch.delete(d.reference);
      n++;
      if (n >= 400) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
  }

  static Future<void> deleteUserDocument(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  static bool get currentUserHasPasswordProvider {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }

  /// Re-authentifie puis supprime le compte Auth. Sans mot de passe si pas provider password.
  static Future<void> deleteFirebaseAuthAccount({String? emailPassword}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Non connecté');

    final needsPassword = currentUserHasPasswordProvider;
    if (needsPassword) {
      final email = user.email;
      final pwd = emailPassword?.trim() ?? '';
      if (email == null || email.isEmpty || pwd.isEmpty) {
        throw ArgumentError('Mot de passe requis pour confirmer la suppression.');
      }
      final cred = EmailAuthProvider.credential(email: email, password: pwd);
      await user.reauthenticateWithCredential(cred);
    }
    await user.delete();
  }
}
