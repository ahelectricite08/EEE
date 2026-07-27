import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';

/// Maps Firestore / register payloads → domain [AuthUser].
AuthUser authUserFromFirestore(String uid, Map<String, dynamic> data) {
  return AuthUser(
    uid: uid,
    email: (data['email'] as String?) ?? '',
    firstName: (data['firstName'] as String?) ?? '',
    lastName: (data['lastName'] as String?) ?? '',
    role: _primaryRole(data),
    createdAt: _readCreatedAt(data['createdAt']),
  );
}

AuthUser authUserFromRegister({
  required String uid,
  required String email,
  required String firstName,
  required String lastName,
}) {
  return AuthUser(
    uid: uid,
    email: email.trim(),
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    role: 'supporter',
    createdAt: DateTime.now(),
  );
}

AuthSession? authSessionFromFirebaseUser({
  required String? uid,
  String? email,
}) {
  if (uid == null || uid.isEmpty) return null;
  return AuthSession(uid: uid, email: email);
}

String _primaryRole(Map<String, dynamic> data) {
  final roles = data['roles'];
  if (roles is List && roles.isNotEmpty) {
    final first = roles.first;
    if (first is String && first.isNotEmpty) return first;
  }
  final role = data['role'];
  if (role is String && role.isNotEmpty) return role;
  return 'supporter';
}

DateTime? _readCreatedAt(Object? raw) {
  if (raw == null) return null;
  try {
    // Firestore Timestamp has toDate(); dynamic keeps domain free of cloud_firestore.
    return (raw as dynamic).toDate() as DateTime;
  } catch (_) {
    if (raw is DateTime) return raw;
    return null;
  }
}
