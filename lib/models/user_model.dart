import 'user_role.dart';

class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  factory UserModel.fromMap(String uid, Map<String, dynamic> d) {
    final rolesSet = parseUserRolesFromDoc(d);
    return UserModel(
      uid: uid,
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      email: d['email'] ?? '',
      role: primaryUserRole(rolesSet),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'role': role.firestoreRole,
    'createdAt': createdAt,
  };
}
