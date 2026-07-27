import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

/// Lightweight Firebase Auth session (uid/email only — no Firestore profile).
///
/// Used by bootstrap / `_AppEntry` parity: signed-in vs guest.
@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String uid,
    String? email,
  }) = _AuthSession;
}
