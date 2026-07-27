import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/auth_firebase_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/register_user.dart';
import '../domain/usecases/reset_password.dart';
import '../domain/usecases/sign_in.dart';
import '../domain/usecases/sign_out.dart';

/// Firebase Auth + Firestore datasource (overridable in tests).
final authFirebaseDatasourceProvider = Provider<AuthFirebaseDatasource>((ref) {
  return AuthFirebaseDatasource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authFirebaseDatasourceProvider));
});

final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.watch(authRepositoryProvider));
});

final registerUserProvider = Provider<RegisterUser>((ref) {
  return RegisterUser(ref.watch(authRepositoryProvider));
});

final resetPasswordProvider = Provider<ResetPassword>((ref) {
  return ResetPassword(ref.watch(authRepositoryProvider));
});

final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

/// Live session stream (Firebase Auth). Replaces direct `authStateChanges`
/// inside the Auth perimeter (`_AppEntry`, auth screens).
final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});
