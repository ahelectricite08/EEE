/// Catalogue d’encarts partenaires — Firestore `app_config/partner_banners`.
/// Fichiers Storage `partner_banners/{fileName}` (lecture publique, écriture admin).
///
/// Un seul format : bandeau 3:1. Pas de slot carré (les logos match restent
/// dans PARTENAIRES MATCH).
class PartnerBanner {
  static const String firestoreDocId = 'partner_banners';
  static const String storageFolder = 'partner_banners';

  /// Copie admin / brief créa.
  static const String specCopy =
      'Bandeau 1200×400 px (ratio 3:1), PNG / JPG / WebP, 800 Ko max.';

  static const int pixelWidth = 1200;
  static const int pixelHeight = 400;
  static const double aspectRatio = 3 / 1;
  static const int maxFileBytes = 800 * 1024;

  /// Emplacements = les bandeaux déjà dans l’app (DonationBanner).
  static const List<String> slots = [
    'home',
    'profile',
    'live',
    'articles',
    'prono',
  ];

  final String id;
  final String imageUrl;
  final String storagePath;
  final String linkUrl;
  final String slot;
  final int sort;
  final bool active;
  final int createdAtMillis;
  final int pixelWidthStored;
  final int pixelHeightStored;

  const PartnerBanner({
    required this.id,
    required this.imageUrl,
    this.storagePath = '',
    this.linkUrl = '',
    this.slot = 'home',
    this.sort = 0,
    this.active = true,
    this.createdAtMillis = 0,
    this.pixelWidthStored = 0,
    this.pixelHeightStored = 0,
  });

  bool get hasUrl => imageUrl.trim().isNotEmpty;

  bool get isValid => id.isNotEmpty && hasUrl;

  /// Ratio loin de 3:1 (ex. 16:9 ≈ 1,78 ou carré). On prévient, on n’interdit pas.
  static bool isWildlyOffRatio(double width, double height) {
    if (width <= 0 || height <= 0) return true;
    final r = width / height;
    return r < 2.4 || r > 3.75;
  }

  static String slotLabel(String slot) {
    return switch (slot.trim()) {
      'home' => 'Accueil',
      'profile' => 'Profil',
      'live' => 'DVCR TV / Live',
      'articles' => 'Actus',
      'prono' => 'Pronos',
      _ => slot.trim().isEmpty ? 'Accueil' : slot.trim(),
    };
  }

  static String normalizeSlot(String raw) {
    final t = raw.trim();
    if (slots.contains(t)) return t;
    return 'home';
  }

  factory PartnerBanner.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final created = m['createdAtMillis'] ?? m['createdAt'];
    return PartnerBanner(
      id: (m['id'] ?? '').toString().trim(),
      imageUrl: (m['imageUrl'] ?? m['url'] ?? '').toString().trim(),
      storagePath: (m['storagePath'] ?? m['path'] ?? '').toString().trim(),
      linkUrl: (m['linkUrl'] ?? m['ctaUrl'] ?? '').toString().trim(),
      slot: normalizeSlot((m['slot'] ?? 'home').toString()),
      sort: _asInt(m['sort']),
      active: m['active'] != false,
      createdAtMillis: created is num ? created.toInt() : 0,
      pixelWidthStored: _asInt(m['pixelWidth']),
      pixelHeightStored: _asInt(m['pixelHeight']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'imageUrl': imageUrl.trim(),
        'storagePath': storagePath.trim(),
        'linkUrl': linkUrl.trim(),
        'slot': normalizeSlot(slot),
        'sort': sort,
        'active': active,
        if (createdAtMillis > 0) 'createdAtMillis': createdAtMillis,
        if (pixelWidthStored > 0) 'pixelWidth': pixelWidthStored,
        if (pixelHeightStored > 0) 'pixelHeight': pixelHeightStored,
      };

  PartnerBanner copyWith({
    String? imageUrl,
    String? storagePath,
    String? linkUrl,
    String? slot,
    int? sort,
    bool? active,
    int? pixelWidthStored,
    int? pixelHeightStored,
  }) {
    return PartnerBanner(
      id: id,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      linkUrl: linkUrl ?? this.linkUrl,
      slot: slot ?? this.slot,
      sort: sort ?? this.sort,
      active: active ?? this.active,
      createdAtMillis: createdAtMillis,
      pixelWidthStored: pixelWidthStored ?? this.pixelWidthStored,
      pixelHeightStored: pixelHeightStored ?? this.pixelHeightStored,
    );
  }

  static int _asInt(Object? v) => v is num ? v.toInt() : 0;
}

class PartnerBannerCatalog {
  final List<PartnerBanner> items;
  final int revisionMillis;

  const PartnerBannerCatalog({
    this.items = const [],
    this.revisionMillis = 0,
  });

  static const PartnerBannerCatalog empty = PartnerBannerCatalog();

  bool get isEmpty => items.isEmpty;

  /// Premier encart actif du slot (sort croissant, puis plus récent).
  PartnerBanner? activeForSlot(String slot) {
    final needle = PartnerBanner.normalizeSlot(slot);
    final list = items
        .where((b) => b.active && b.hasUrl && b.slot == needle)
        .toList();
    if (list.isEmpty) return null;
    list.sort((a, b) {
      final s = a.sort.compareTo(b.sort);
      if (s != 0) return s;
      return b.createdAtMillis.compareTo(a.createdAtMillis);
    });
    return list.first;
  }

  List<PartnerBanner> forSlot(String slot) {
    final needle = PartnerBanner.normalizeSlot(slot);
    final list = items.where((b) => b.slot == needle).toList();
    list.sort((a, b) {
      final s = a.sort.compareTo(b.sort);
      if (s != 0) return s;
      return b.createdAtMillis.compareTo(a.createdAtMillis);
    });
    return list;
  }

  PartnerBanner? byId(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final b in items) {
      if (b.id == needle) return b;
    }
    return null;
  }

  factory PartnerBannerCatalog.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final raw = data['banners'] ?? data['items'];
    if (raw is! List) return empty;
    final list = <PartnerBanner>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final b = PartnerBanner.fromMap(Map<String, dynamic>.from(item));
      if (b.isValid) list.add(b);
    }
    list.sort((a, b) {
      final slot = a.slot.compareTo(b.slot);
      if (slot != 0) return slot;
      final s = a.sort.compareTo(b.sort);
      if (s != 0) return s;
      return b.createdAtMillis.compareTo(a.createdAtMillis);
    });
    final rev = data['updatedAtMillis'];
    return PartnerBannerCatalog(
      items: list,
      revisionMillis: rev is num ? rev.toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'banners': items.map((b) => b.toMap()).toList(),
      };
}
