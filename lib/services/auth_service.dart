import 'package:dvcr/core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/auth/data/datasources/auth_firebase_datasource.dart';
import '../features/auth/data/mappers/auth_error_mapper.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/entities/auth_user.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

/// Legacy static façade over [AuthRepositoryImpl].
///
/// **Dette acceptée (Auth 2026-07-26):** new code should use
/// `package:dvcr/features/auth/auth.dart` providers. This façade keeps
/// profile / admin / portal call sites compiling until a later migrate.
class AuthService {
  static final AuthFirebaseDatasource _datasource = AuthFirebaseDatasource();
  static final AuthRepository _repository = AuthRepositoryImpl(_datasource);

  static User? get currentUser => _datasource.currentUser;
  static Stream<User?> get authStateChanges => _datasource.authStateChanges();

  static Future<UserModel?> signIn(String email, String password) async {
    final result = await _repository.signIn(email: email, password: password);
    return _unwrapUser(result);
  }

  static Future<UserModel?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final result = await _repository.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    return _unwrapUser(result);
  }

  static Future<void> signOut() async {
    final result = await _repository.signOut();
    result.when(
      success: (_) {},
      failure: (e) => throw _AuthFacadeException(e),
    );
  }

  static Future<UserModel?> getCurrentUser() async {
    final u = _datasource.currentUser;
    if (u == null) return null;
    final data = await _datasource.fetchUserProfile(u.uid);
    if (data == null) return null;
    return UserModel.fromMap(u.uid, data);
  }

  static Future<void> resetPassword(String email) async {
    final result = await _repository.resetPassword(email: email);
    result.when(
      success: (_) {},
      failure: (e) => throw _AuthFacadeException(e),
    );
  }

  /// Messages d’erreur Firebase Auth — toujours en français.
  static String errorMessage(Object e) {
    if (e is _AuthFacadeException) return e.failure.messageFr;
    return mapAuthExceptionToFr(e);
  }

  static UserModel? _unwrapUser(Result<AuthUser> result) {
    return result.when(
      success: (user) => UserModel(
        uid: user.uid,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        role: parseUserRoleFromFirestore(user.role),
        createdAt: user.createdAt ?? DateTime.now(),
      ),
      failure: (e) => throw _AuthFacadeException(e),
    );
  }
}

class _AuthFacadeException implements Exception {
  _AuthFacadeException(this.failure);
  final AppFailure failure;
}
