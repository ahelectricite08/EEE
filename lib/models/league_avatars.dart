/// Emblèmes de ligue : catalogue admin Firestore `app_config/league_avatars`
/// (Storage `league_avatars/`).
///
/// Les 5 mascottes `assets/league_avatars/` (sanglier, supporter, etc.)
/// ne sont **pas** des choix de ligue — ce sont des avatars profil. Une
/// ligue qui a déjà un `avatarId` pack peut continuer à l’afficher.
/// Grille Créer ma ligue / Changer l’emblème : catalogue admin seulement.
/// `avatarId` + `avatarUrl` sur `private_leagues/{id}`.
class LeagueAvatar {
  static const String assetFolder = 'assets/league_avatars';

  final String id;
  final String label;
  final String fileName;

  const LeagueAvatar({
    required this.id,
    required this.label,
    required this.fileName,
  });

  String get assetPath => '$assetFolder/$fileName';

  Map<String, String> toLeagueFields() => {
        'avatarId': id,
        'avatarUrl': assetPath,
      };
}

/// Entrée du catalogue admin (`app_config/league_avatars`).
class LeagueCatalogAvatar {
  static const String firestoreDocId = 'league_avatars';
  static const String storageFolder = 'league_avatars';

  /// Copie admin (Photos & réseaux → AVATARS LIGUES).
  static const String specCopy =
      'Carré 512×512, PNG ou WebP, 500 Ko max. Ces emblèmes apparaissent '
      'dans Créer ma ligue (créateur seulement).';

  static const int maxFileBytes = 500 * 1024;

  final String id;
  final String url;
  final String storagePath;
  final int createdAtMillis;

  const LeagueCatalogAvatar({
    required this.id,
    required this.url,
    required this.storagePath,
    this.createdAtMillis = 0,
  });

  bool get hasUrl => url.trim().isNotEmpty;

  bool get isValid => id.isNotEmpty && url.trim().isNotEmpty;

  factory LeagueCatalogAvatar.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final created = m['createdAtMillis'];
    return LeagueCatalogAvatar(
      id: (m['id'] ?? '').toString().trim(),
      url: (m['url'] ?? '').toString().trim(),
      storagePath: (m['storagePath'] ?? m['path'] ?? '').toString().trim(),
      createdAtMillis: created is num ? created.toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url.trim(),
        'storagePath': storagePath.trim(),
        if (createdAtMillis > 0) 'createdAtMillis': createdAtMillis,
      };

  Map<String, String> toLeagueFields() => {
        'avatarId': id,
        'avatarUrl': url.trim(),
      };
}

class LeagueAvatarCatalog {
  final List<LeagueCatalogAvatar> avatars;

  const LeagueAvatarCatalog({this.avatars = const []});

  static const LeagueAvatarCatalog empty = LeagueAvatarCatalog();

  bool get isEmpty => avatars.isEmpty;

  LeagueCatalogAvatar? byId(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final a in avatars) {
      if (a.id == needle) return a;
    }
    return null;
  }

  factory LeagueAvatarCatalog.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final raw = data['avatars'] ?? data['items'];
    if (raw is! List) return empty;
    final list = <LeagueCatalogAvatar>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final a = LeagueCatalogAvatar.fromMap(Map<String, dynamic>.from(item));
      if (a.isValid) list.add(a);
    }
    list.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    return LeagueAvatarCatalog(avatars: list);
  }

  Map<String, dynamic> toMap() => {
        'avatars': avatars.map((a) => a.toMap()).toList(),
      };
}

/// Choix affiché dans le picker (catalogue admin ligue uniquement).
class LeagueEmblemOption {
  final String id;
  final String src;
  final String label;

  const LeagueEmblemOption({
    required this.id,
    required this.src,
    this.label = '',
  });
}

/// Source profil — jamais dans le picker ligue.
bool isProfileAvatarSource(String? src, {String? storagePath}) {
  final url = (src ?? '').trim().toLowerCase();
  final path = (storagePath ?? '').trim().toLowerCase();
  if (url.startsWith('assets/avatars/') || path.startsWith('assets/avatars/')) {
    return true;
  }
  if (path.startsWith('profile_avatars/') || path.contains('/profile_avatars/')) {
    return true;
  }
  return url.contains('profile_avatars');
}

/// Pack bundlé `assets/league_avatars/` ou Storage / URL `league_avatars/`.
bool isLeagueEmblemSource(String? src, {String? storagePath}) {
  if (isProfileAvatarSource(src, storagePath: storagePath)) return false;
  final url = (src ?? '').trim().toLowerCase();
  final path = (storagePath ?? '').trim().toLowerCase();
  if (url.startsWith('${LeagueAvatar.assetFolder}/')) return true;
  if (path.startsWith('${LeagueCatalogAvatar.storageFolder}/')) return true;
  return url.contains('league_avatars');
}

bool isLeagueEmblemCatalogEntry(LeagueCatalogAvatar avatar) =>
    isLeagueEmblemSource(avatar.url, storagePath: avatar.storagePath);

/// Entrée admin utilisable dans la **grille** (pas pack bundlé, pas profil).
bool isAdminLeagueEmblem(LeagueCatalogAvatar avatar) {
  if (LeagueAvatarPack.isKnownId(avatar.id)) return false;
  if (isBundledAssetKey(avatar.url) || isBundledAssetKey(avatar.storagePath)) {
    return false;
  }
  return isLeagueEmblemCatalogEntry(avatar);
}

bool isLeagueEmblemPickerOption(LeagueEmblemOption option) {
  if (LeagueAvatarPack.isKnownId(option.id)) return false;
  if (isBundledAssetKey(option.src)) return false;
  return isLeagueEmblemSource(option.src);
}

/// Catalogue **ligue** admin seulement. Jamais le pack `assets/league_avatars/`,
/// ni `profile_avatars`, ni `assets/avatars/`.
List<LeagueEmblemOption> leagueEmblemPickerOptions(
  LeagueAvatarCatalog catalog,
) {
  return [
    for (final a in catalog.avatars)
      if (isAdminLeagueEmblem(a)) LeagueEmblemOption(id: a.id, src: a.url),
  ];
}

/// Stream KO / catalogue vide / liste filtrée → [] (état vide UI, pas les 5
/// mascottes).
List<LeagueEmblemOption> resolveLeagueEmblemPickerOptions({
  LeagueAvatarCatalog? catalog,
  bool streamFailed = false,
}) {
  if (streamFailed) return const [];
  return leagueEmblemPickerOptions(catalog ?? LeagueAvatarCatalog.empty);
}

/// Création : id catalogue admin, sinon 1er du catalogue si l’id est vide
/// ou un ancien pack, sinon aucun emblème (pas de défaut sanglier).
Map<String, String> resolveLeagueEmblemFields({
  required String? avatarId,
  required LeagueAvatarCatalog catalog,
}) {
  final needle = (avatarId ?? '').trim();
  final entries = [
    for (final a in catalog.avatars)
      if (isAdminLeagueEmblem(a)) a,
  ];
  final found = catalog.byId(needle);
  if (found != null && isAdminLeagueEmblem(found)) {
    return found.toLeagueFields();
  }
  if (entries.isNotEmpty &&
      (needle.isEmpty || LeagueAvatarPack.isKnownId(needle))) {
    return entries.first.toLeagueFields();
  }
  return const {};
}

/// Changement d’emblème (créateur) : id catalogue admin seulement.
Map<String, String>? resolveLeagueEmblemUpdateFields({
  required String avatarId,
  required LeagueAvatarCatalog catalog,
}) {
  final needle = avatarId.trim();
  if (needle.isEmpty) return null;
  final found = catalog.byId(needle);
  if (found != null && isAdminLeagueEmblem(found)) {
    return found.toLeagueFields();
  }
  return null;
}

/// Conserve l’emblème déjà stocké (catalogue **ou** ancien pack). Vide si rien.
Map<String, String> leagueEmblemPersistFields(Map<String, dynamic>? data) {
  final id = (data?['avatarId'] ?? '').toString().trim();
  final url = (data?['avatarUrl'] ?? '').toString().trim();
  if (id.isNotEmpty && url.isNotEmpty) {
    return {'avatarId': id, 'avatarUrl': url};
  }
  return const {};
}

abstract final class LeagueAvatarPack {
  static const String defaultId = 'sanglier';

  static const List<LeagueAvatar> all = [
    LeagueAvatar(
      id: 'sanglier',
      label: 'Sanglier',
      fileName: 'sanglier.png',
    ),
    LeagueAvatar(
      id: 'supporter',
      label: 'Supporter',
      fileName: 'supporter.png',
    ),
    LeagueAvatar(
      id: 'tacticien',
      label: 'Tacticien',
      fileName: 'tacticien.png',
    ),
    LeagueAvatar(
      id: 'arbitre',
      label: 'Arbitre',
      fileName: 'arbitre.png',
    ),
    LeagueAvatar(
      id: 'commentateur',
      label: 'Commentateur',
      fileName: 'commentateur.png',
    ),
  ];

  static const List<String> ids = [
    'sanglier',
    'supporter',
    'tacticien',
    'arbitre',
    'commentateur',
  ];

  static LeagueAvatar get defaultAvatar => all.first;

  static LeagueAvatar get defaultEmblem => defaultAvatar;

  static LeagueAvatar? byId(String? id) {
    final needle = (id ?? '').trim();
    if (needle.isEmpty) return null;
    for (final a in all) {
      if (a.id == needle) return a;
    }
    return null;
  }

  static bool isKnownId(String? id) => byId(id) != null;

  /// Création : id inconnu → premier du pack.
  static LeagueAvatar resolve(String? id) => byId(id) ?? defaultAvatar;

  static String? displayPathFromData(Map<String, dynamic>? data) =>
      leagueAvatarSrcFromData(data);

  static String idFromData(Map<String, dynamic>? data) =>
      leagueAvatarIdFromData(data);
}

/// `avatarId` du pack, sinon id catalogue / brut, sinon déduit de `avatarUrl`.
String leagueAvatarIdFromData(Map<String, dynamic>? data) {
  final id = (data?['avatarId'] ?? '').toString().trim();
  final known = LeagueAvatarPack.byId(id)?.id;
  if (known != null) return known;
  final url = (data?['avatarUrl'] ?? '').toString().trim();
  if (url.isNotEmpty) {
    for (final a in LeagueAvatarPack.all) {
      if (a.assetPath == url || a.fileName == url) return a.id;
    }
  }
  return id;
}

/// Chemin asset du pack, sinon `avatarUrl` brut (réseau), sinon `null`.
String? leagueAvatarSrcFromData(Map<String, dynamic>? data) {
  final fromPack = LeagueAvatarPack.byId(leagueAvatarIdFromData(data));
  if (fromPack != null) return fromPack.assetPath;
  final url = (data?['avatarUrl'] ?? '').toString().trim();
  return url.isEmpty ? null : url;
}

bool isBundledAssetKey(String? src) {
  final s = (src ?? '').trim();
  return s.startsWith('assets/');
}
