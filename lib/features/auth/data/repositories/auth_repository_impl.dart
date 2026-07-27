import 'package:dvcr/core/core.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_firebase_datasource.dart';
import '../mappers/auth_error_mapper.dart';
import '../mappers/auth_user_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final AuthFirebaseDatasource _datasource;

  @override
  AuthSession? get currentSession {
    final user = _datasource.currentUser;
    return authSessionFromFirebaseUser(uid: user?.uid, email: user?.email);
  }

  @override
  Stream<AuthSession?> watchSession() {
    return _datasource.authStateChanges().map(
          (user) => authSessionFromFirebaseUser(
            uid: user?.uid,
            email: user?.email,
          ),
        );
  }

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _datasource.signInWithEmail(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return const Failure(AuthFailure(message: _echecConnexion));
      }
      final profile = await _datasource.fetchUserProfile(user.uid);
      if (profile == null) {
        return Success(
          AuthUser(uid: user.uid, email: user.email ?? email.trim()),
        );
      }
      return Success(authUserFromFirestore(user.uid, profile));
    } catch (e) {
      return Failure(mapAuthException(e));
    }
  }

  @override
  Future<Result<AuthUser>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _datasource.createUserWithEmail(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return const Failure(
          AuthFailure(
            message:
                'Une erreur inattendue s’est produite. Réessaie dans un instant.',
          ),
        );
      }
      await _datasource.createUserProfile(
        uid: user.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
      return Success(
        authUserFromRegister(
          uid: user.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
        ),
      );
    } catch (e) {
      return Failure(mapAuthException(e));
    }
  }

  @override
  Future<Result<void>> resetPassword({required String email}) async {
    try {
      await _datasource.sendPasswordResetEmail(email);
      return const Success(null);
    } catch (e) {
      return Failure(mapAuthException(e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(mapAuthException(e));
    }
  }
}

const _echecConnexion =
    'Connexion impossible. Vérifie ton e-mail et ton mot de passe, puis réessaie.';
