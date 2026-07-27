import 'package:dvcr/core/core.dart';

import '../repositories/auth_repository.dart';

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.signOut();
}
