import 'package:dvcr/core/core.dart';

import '../entities/auth_session.dart';
import '../entities/auth_user.dart';

/// Auth port — implemented in data/, consumed by use cases / providers.
abstract class AuthRepository {
  /// Cold-start / live session (Firebase Auth only).
  AuthSession? get currentSession;

  Stream<AuthSession?> watchSession();

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<Result<void>> resetPassword({required String email});

  Future<Result<void>> signOut();
}
