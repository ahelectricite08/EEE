import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// Domain user profile for the Auth feature (Freezed).
///
/// Firestore mapping lives in data/mappers — no raw Maps in presentation.
@freezed
class AuthUser with _$AuthUser {
  const AuthUser._();

  const factory AuthUser({
    required String uid,
    required String email,
    @Default('') String firstName,
    @Default('') String lastName,
    @Default('supporter') String role,
    DateTime? createdAt,
  }) = _AuthUser;

  String get fullName => '$firstName $lastName'.trim();
}
