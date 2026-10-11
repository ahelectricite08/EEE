/// Catalogue d’avatars profil — Firestore `app_config/profile_avatars`.
/// Fichiers Storage `profile_avatars/{fileName}` (lecture publique, écriture admin).
class ProfileAvatar {
  static const String firestoreDocId = 'profile_avatars';
  static const String storageFolder = 'profile_avatars';
  static const String publicCollection = 'user_avatars';

  /// Copie admin / préparation des fichiers.
  static const String specCopy =
      'Carré 512×512, PNG ou WebP, 500 Ko max.';

  static const int maxFileBytes = 500 * 1024;
  static const double displayLogicalMin = 64;
  static const double displayLogicalMax = 96;

  final String id;
  final String url;
  final String storagePath;
  final int createdAtMillis;

  const ProfileAvatar({
    required this.id,
    required this.url,
    required this.storagePath,
    this.createdAtMillis = 0,
  });

  bool get hasUrl => url.trim().isNotEmpty;

  factory ProfileAvatar.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final url = (m['url'] ?? '').toString().trim();
    final path = (m['storagePath'] ?? m['path'] ?? '').toString().trim();
    final created = m['createdAtMillis'];
    return ProfileAvatar(
      id: (m['id'] ?? '').toString().trim(),
      url: url,
      storagePath: path,
      createdAtMillis: created is num ? created.toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url.trim(),
        'storagePath': storagePath.trim(),
        if (createdAtMillis > 0) 'createdAtMillis': createdAtMillis,
      };

  bool get isValid => id.isNotEmpty && url.trim().isNotEmpty;
}

class ProfileAvatarCatalog {
  final List<ProfileAvatar> avatars;

  const ProfileAvatarCatalog({this.avatars = const []});

  static const ProfileAvatarCatalog empty = ProfileAvatarCatalog();

  bool get isEmpty => avatars.isEmpty;

  ProfileAvatar? byId(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final a in avatars) {
      if (a.id == needle) return a;
    }
    return null;
  }

  factory ProfileAvatarCatalog.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final raw = data['avatars'] ?? data['items'];
    if (raw is! List) return empty;
    final list = <ProfileAvatar>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final a = ProfileAvatar.fromMap(Map<String, dynamic>.from(item));
      if (a.isValid) list.add(a);
    }
    list.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    return ProfileAvatarCatalog(avatars: list);
  }

  Map<String, dynamic> toMap() => {
        'avatars': avatars.map((a) => a.toMap()).toList(),
      };
}

/// Lecture `users/{uid}` ou `user_avatars/{uid}`.
String? profileAvatarUrlFromData(Map<String, dynamic>? data) {
  final u = (data?['avatarUrl'] ?? '').toString().trim();
  return u.isEmpty ? null : u;
}

String profileAvatarIdFromData(Map<String, dynamic>? data) {
  return (data?['avatarId'] ?? '').toString().trim();
}
