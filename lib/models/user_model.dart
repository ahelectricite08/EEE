enum UserRole { free, supporter, donor, partner, admin, communityManager }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.free:            return 'Gratuit';
      case UserRole.supporter:       return 'Supporter';
      case UserRole.donor:           return 'Donateur';
      case UserRole.partner:         return 'Partenaire';
      case UserRole.admin:           return 'Admin';
      case UserRole.communityManager:return 'CM';
    }
  }

  bool get canManageContent =>
      this == UserRole.admin || this == UserRole.communityManager;
  bool get isAdmin => this == UserRole.admin;

  static UserRole fromString(String? s) {
    switch (s) {
      case 'supporter':        return UserRole.supporter;
      case 'donor':            return UserRole.donor;
      case 'partner':          return UserRole.partner;
      case 'admin':            return UserRole.admin;
      case 'communityManager': return UserRole.communityManager;
      default:                 return UserRole.free;
    }
  }
}

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
    return UserModel(
      uid: uid,
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      email: d['email'] ?? '',
      role: UserRoleX.fromString(d['role']),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'role': role.name,
    'createdAt': createdAt,
  };
}
