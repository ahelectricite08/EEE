import 'package:dvcr/core/core.dart';

import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RegisterUser {
  const RegisterUser(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _repository.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}
