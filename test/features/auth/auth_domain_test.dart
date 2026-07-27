import 'dart:async';

import 'package:dvcr/core/core.dart';
import 'package:dvcr/features/auth/domain/entities/auth_session.dart';
import 'package:dvcr/features/auth/domain/entities/auth_user.dart';
import 'package:dvcr/features/auth/domain/repositories/auth_repository.dart';
import 'package:dvcr/features/auth/domain/usecases/register_user.dart';
import 'package:dvcr/features/auth/domain/usecases/reset_password.dart';
import 'package:dvcr/features/auth/domain/usecases/sign_in.dart';
import 'package:dvcr/features/auth/domain/usecases/sign_out.dart';
import 'package:dvcr/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:dvcr/features/auth/data/mappers/auth_user_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth_error_mapper', () {
    test('maps wrong-password to French AuthFailure', () {
      final f = mapAuthException(
        FirebaseAuthException(code: 'wrong-password'),
      );
      expect(f, isA<AuthFailure>());
      expect(f.messageFr, 'Mot de passe incorrect.');
    });

    test('maps network-request-failed to NetworkFailure', () {
      final f = mapAuthException(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(f, isA<NetworkFailure>());
      expect(f.messageFr, contains('Internet'));
    });

    test('maps English credential hint', () {
      final f = mapAuthException(
        FirebaseAuthException(
          code: 'unknown',
          message: 'The supplied auth credential is incorrect',
        ),
      );
      expect(f.messageFr, contains('Mot de passe oublié'));
    });

    test('mapAuthExceptionToFr matches messageFr', () {
      final e = FirebaseAuthException(code: 'user-not-found');
      expect(mapAuthExceptionToFr(e), mapAuthException(e).messageFr);
    });
  });

  group('auth_user_mapper', () {
    test('authUserFromFirestore reads profile fields', () {
      final user = authUserFromFirestore('uid1', {
        'email': 'a@b.c',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'role': 'supporter',
        'roles': ['supporter'],
      });
      expect(user.uid, 'uid1');
      expect(user.email, 'a@b.c');
      expect(user.firstName, 'Ada');
      expect(user.fullName, 'Ada Lovelace');
      expect(user.role, 'supporter');
    });

    test('authSessionFromFirebaseUser null when no uid', () {
      expect(authSessionFromFirebaseUser(uid: null), isNull);
      expect(
        authSessionFromFirebaseUser(uid: 'x', email: 'e@e.e')?.email,
        'e@e.e',
      );
    });
  });

  group('use cases with FakeAuthRepository', () {
    late FakeAuthRepository fake;
    late SignIn signIn;
    late RegisterUser registerUser;
    late ResetPassword resetPassword;
    late SignOut signOut;

    setUp(() {
      fake = FakeAuthRepository();
      signIn = SignIn(fake);
      registerUser = RegisterUser(fake);
      resetPassword = ResetPassword(fake);
      signOut = SignOut(fake);
    });

    test('SignIn success', () async {
      fake.signInResult = const Success(
        AuthUser(uid: '1', email: 'a@b.c', firstName: 'A', lastName: 'B'),
      );
      final r = await signIn(email: 'a@b.c', password: 'secret1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull?.uid, '1');
      expect(fake.lastSignInEmail, 'a@b.c');
    });

    test('SignIn failure', () async {
      fake.signInResult = const Failure(
        AuthFailure(message: 'Mot de passe incorrect.'),
      );
      final r = await signIn(email: 'a@b.c', password: 'bad');
      expect(r.isFailure, isTrue);
      expect(r.failureOrNull?.messageFr, 'Mot de passe incorrect.');
    });

    test('RegisterUser success', () async {
      fake.registerResult = const Success(
        AuthUser(uid: '2', email: 'n@e.w', firstName: 'N', lastName: 'W'),
      );
      final r = await registerUser(
        firstName: 'N',
        lastName: 'W',
        email: 'n@e.w',
        password: 'secret1',
      );
      expect(r.isSuccess, isTrue);
      expect(fake.lastRegisterEmail, 'n@e.w');
    });

    test('ResetPassword success', () async {
      fake.resetResult = const Success(null);
      final r = await resetPassword(email: 'a@b.c');
      expect(r.isSuccess, isTrue);
      expect(fake.lastResetEmail, 'a@b.c');
    });

    test('SignOut success', () async {
      fake.signOutResult = const Success(null);
      final r = await signOut();
      expect(r.isSuccess, isTrue);
      expect(fake.signOutCalled, isTrue);
    });
  });
}

class FakeAuthRepository implements AuthRepository {
  Result<AuthUser>? signInResult;
  Result<AuthUser>? registerResult;
  Result<void>? resetResult;
  Result<void>? signOutResult;

  String? lastSignInEmail;
  String? lastRegisterEmail;
  String? lastResetEmail;
  bool signOutCalled = false;

  AuthSession? session;
  final _sessionController = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => session;

  @override
  Stream<AuthSession?> watchSession() => _sessionController.stream;

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    return signInResult ??
        const Failure(UnexpectedFailure(message: 'not stubbed'));
  }

  @override
  Future<Result<AuthUser>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    lastRegisterEmail = email;
    return registerResult ??
        const Failure(UnexpectedFailure(message: 'not stubbed'));
  }

  @override
  Future<Result<void>> resetPassword({required String email}) async {
    lastResetEmail = email;
    return resetResult ??
        const Failure(UnexpectedFailure(message: 'not stubbed'));
  }

  @override
  Future<Result<void>> signOut() async {
    signOutCalled = true;
    return signOutResult ?? const Success(null);
  }
}
