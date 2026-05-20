import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/share_template_settings.dart';

class SupportSettings {
  final String supportUrl;

  const SupportSettings({required this.supportUrl});

  factory SupportSettings.fromMap(Map<String, dynamic>? data) {
    return SupportSettings(
      supportUrl: (data?['supportUrl'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'supportUrl': supportUrl};
  }
}

class RoleBadgeSettings {
  final Map<String, String> badges;

  const RoleBadgeSettings({required this.badges});

  factory RoleBadgeSettings.fromMap(Map<String, dynamic>? data) {
    return RoleBadgeSettings(
      badges: (data ?? const <String, dynamic>{}).map(
        (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return badges.map((key, value) => MapEntry(key, value.trim()));
  }
}

/// Encart « Propulsé par » configurable admin — document `app_config/powered_by_partner`.
/// Utilisé sur **prono** et **Coupe du monde** ; le **profil** reste sur l’asset fixe
/// [PoweredByPartnerSettings.fallbackAssetPath] + valeurs par défaut ci-dessous.
///
/// Champs `worldCup*` vides = réutiliser la valeur « prono » (image, titres, etc.).
///
/// **Dimensions image (paysage, type carte / bannière)** : viser **1200 × 800 px**
/// (ratio **3:2**), JPEG ou WebP ~150–350 Ko. **Minimum** : **900 × 600 px**.
/// Au-delà de ~1600 px de large le gain sur mobile est faible.
/// L’app affiche la zone en **3:2** avec `BoxFit.cover` : une image carrée ou trop
/// haute sera **légèrement rognée** sur les bords pour remplir sans bandes grises.
class PoweredByPartnerSettings {
  static const String fallbackAssetPath =
      'assets/images/Cartevisiteaxel08.jpg';
  static const String defaultTagline =
      'Électricité · dépannage · installations';
  static const String defaultBadgeLabel = 'PARTENAIRE OFFICIEL';
  static const String defaultSectionLabel = 'PRONOSTIC';
  static const String defaultPoweredByTitle = 'PROPULSÉ PAR';
  static const String defaultWorldCupPrizeBanner =
      'Le 1er du classement remporte un ballon officiel de la Coupe du Monde 2026.';
  static const String defaultWorldCupHeroSubtitle =
      'Pronostique les matchs, grimpe au classement.';

  final String imageUrl;
  final String tagline;
  final String badgeLabel;
  final String sectionLabel;
  final String poweredByTitle;
  /// Sous le sous-titre partenaire sur l’onglet prono (ex. lot classement).
  final String pronoPrizeHint;

  final String worldCupSectionLabel;
  final String worldCupPoweredByTitle;
  final String worldCupTagline;
  final String worldCupImageUrl;
  final String worldCupBadgeLabel;
  final String worldCupPrizeBannerText;
  final bool worldCupPrizeBannerEnabled;
  /// Ligne sous « COUPE DU MONDE » sur le hero vert CdM (texte clair).
  final String worldCupHeroSubtitle;

  /// Dérivé de `updatedAt` Firestore — invalide le cache image côté app.
  final int revisionMillis;

  const PoweredByPartnerSettings({
    required this.imageUrl,
    required this.tagline,
    this.badgeLabel = defaultBadgeLabel,
    this.sectionLabel = defaultSectionLabel,
    this.poweredByTitle = defaultPoweredByTitle,
    this.pronoPrizeHint = '',
    this.worldCupSectionLabel = '',
    this.worldCupPoweredByTitle = '',
    this.worldCupTagline = '',
    this.worldCupImageUrl = '',
    this.worldCupBadgeLabel = '',
    this.worldCupPrizeBannerText = '',
    this.worldCupPrizeBannerEnabled = true,
    this.worldCupHeroSubtitle = '',
    this.revisionMillis = 0,
  });

  static const PoweredByPartnerSettings defaults = PoweredByPartnerSettings(
    imageUrl: '',
    tagline: defaultTagline,
  );

  factory PoweredByPartnerSettings.fromMap(Map<String, dynamic>? data) {
    final rawTag = (data?['tagline'] ?? '').toString().trim();
    String s(String key, String fallback) {
      final v = data?[key]?.toString().trim() ?? '';
      return v.isEmpty ? fallback : v;
    }

    return PoweredByPartnerSettings(
      imageUrl: (data?['imageUrl'] ?? '').toString().trim(),
      tagline: rawTag.isEmpty ? defaultTagline : rawTag,
      badgeLabel: s('badgeLabel', defaultBadgeLabel),
      sectionLabel: s('sectionLabel', defaultSectionLabel),
      poweredByTitle: s('poweredByTitle', defaultPoweredByTitle),
      pronoPrizeHint: (data?['pronoPrizeHint'] ?? '').toString().trim(),
      worldCupSectionLabel:
          (data?['worldCupSectionLabel'] ?? '').toString().trim(),
      worldCupPoweredByTitle:
          (data?['worldCupPoweredByTitle'] ?? '').toString().trim(),
      worldCupTagline: (data?['worldCupTagline'] ?? '').toString().trim(),
      worldCupImageUrl: (data?['worldCupImageUrl'] ?? '').toString().trim(),
      worldCupBadgeLabel: (data?['worldCupBadgeLabel'] ?? '').toString().trim(),
      worldCupPrizeBannerText:
          (data?['worldCupPrizeBannerText'] ?? '').toString().trim(),
      worldCupPrizeBannerEnabled: data?['worldCupPrizeBannerEnabled'] != false,
      worldCupHeroSubtitle:
          (data?['worldCupHeroSubtitle'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'imageUrl': imageUrl.trim(),
        'tagline': tagline.trim(),
        'badgeLabel': badgeLabel.trim(),
        'sectionLabel': sectionLabel.trim(),
        'poweredByTitle': poweredByTitle.trim(),
        'pronoPrizeHint': pronoPrizeHint.trim(),
        'worldCupSectionLabel': worldCupSectionLabel.trim(),
        'worldCupPoweredByTitle': worldCupPoweredByTitle.trim(),
        'worldCupTagline': worldCupTagline.trim(),
        'worldCupImageUrl': worldCupImageUrl.trim(),
        'worldCupBadgeLabel': worldCupBadgeLabel.trim(),
        'worldCupPrizeBannerText': worldCupPrizeBannerText.trim(),
        'worldCupPrizeBannerEnabled': worldCupPrizeBannerEnabled,
        'worldCupHeroSubtitle': worldCupHeroSubtitle.trim(),
      };

  /// Texte bandeau or au-dessus des matchs CDM.
  String get effectiveWorldCupPrizeBanner {
    final t = worldCupPrizeBannerText.trim();
    if (t.isEmpty) return defaultWorldCupPrizeBanner;
    return t;
  }

  String get effectiveWorldCupHeroSubtitle {
    final t = worldCupHeroSubtitle.trim();
    if (t.isEmpty) return defaultWorldCupHeroSubtitle;
    return t;
  }

  /// Visuel encart CDM : URL dédiée si renseignée, sinon image prono.
  String get effectiveWorldCupImageUrl =>
      worldCupImageUrl.trim().isNotEmpty ? worldCupImageUrl.trim() : imageUrl;

  PoweredByPartnerSettings copyForWorldCupEncart() {
    return PoweredByPartnerSettings(
      imageUrl: effectiveWorldCupImageUrl,
      tagline: worldCupTagline.trim().isNotEmpty ? worldCupTagline.trim() : tagline,
      badgeLabel:
          worldCupBadgeLabel.trim().isNotEmpty ? worldCupBadgeLabel.trim() : badgeLabel,
      sectionLabel: worldCupSectionLabel.trim().isNotEmpty
          ? worldCupSectionLabel.trim()
          : sectionLabel,
      poweredByTitle: worldCupPoweredByTitle.trim().isNotEmpty
          ? worldCupPoweredByTitle.trim()
          : poweredByTitle,
      pronoPrizeHint: pronoPrizeHint,
      worldCupSectionLabel: worldCupSectionLabel,
      worldCupPoweredByTitle: worldCupPoweredByTitle,
      worldCupTagline: worldCupTagline,
      worldCupImageUrl: worldCupImageUrl,
      worldCupBadgeLabel: worldCupBadgeLabel,
      worldCupPrizeBannerText: worldCupPrizeBannerText,
      worldCupPrizeBannerEnabled: worldCupPrizeBannerEnabled,
      worldCupHeroSubtitle: worldCupHeroSubtitle,
      revisionMillis: revisionMillis,
    );
  }
}

/// Visuel optionnel joint aux partages réseaux (app_config/share_card).
/// Format conseillé : 1200×630 (Open Graph), JPEG/WebP léger ; carré 1080×1080 OK.
class ShareCardSettings {
  final String imageUrl;
  final int revisionMillis;

  const ShareCardSettings({
    required this.imageUrl,
    this.revisionMillis = 0,
  });

  static const ShareCardSettings defaults = ShareCardSettings(imageUrl: '');

  factory ShareCardSettings.fromMap(Map<String, dynamic>? data) {
    return ShareCardSettings(
      imageUrl: (data?['imageUrl'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {'imageUrl': imageUrl.trim()};
}

/// Trois fonds d’écran du bandeau profil — `app_config/profile_hero`.
/// URL vide = image locale par défaut dans l’app.
class ProfileHeroBackgroundSettings {
  static const String firestoreDocId = 'profile_hero';
  static const String defaultAssetPath =
      'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg';

  final String imageUrl1;
  final String imageUrl2;
  final String imageUrl3;
  final int revisionMillis;

  const ProfileHeroBackgroundSettings({
    required this.imageUrl1,
    required this.imageUrl2,
    required this.imageUrl3,
    this.revisionMillis = 0,
  });

  static const ProfileHeroBackgroundSettings defaults =
      ProfileHeroBackgroundSettings(
    imageUrl1: '',
    imageUrl2: '',
    imageUrl3: '',
  );

  List<String> get urls => [imageUrl1, imageUrl2, imageUrl3];

  factory ProfileHeroBackgroundSettings.fromMap(Map<String, dynamic>? data) {
    return ProfileHeroBackgroundSettings(
      imageUrl1: (data?['imageUrl1'] ?? '').toString().trim(),
      imageUrl2: (data?['imageUrl2'] ?? '').toString().trim(),
      imageUrl3: (data?['imageUrl3'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'imageUrl1': imageUrl1.trim(),
        'imageUrl2': imageUrl2.trim(),
        'imageUrl3': imageUrl3.trim(),
      };
}

int _revisionMillisFromMap(Map<String, dynamic>? data) {
  final v = data?['updatedAt'];
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  return 0;
}

class ChatEmojiSettings {
  final String id;
  final String label;
  final String value;
  final String imageUrl;
  final bool enabled;

  const ChatEmojiSettings({
    required this.id,
    required this.label,
    required this.value,
    required this.imageUrl,
    required this.enabled,
  });

  factory ChatEmojiSettings.fromMap(Map<String, dynamic>? data) {
    return ChatEmojiSettings(
      id: (data?['id'] ?? '').toString(),
      label: (data?['label'] ?? '').toString().trim(),
      value: (data?['value'] ?? '').toString().trim(),
      imageUrl: (data?['imageUrl'] ?? '').toString().trim(),
      enabled: data?['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'imageUrl': imageUrl,
      'enabled': enabled,
    };
  }
}

class ChatSettings {
  final bool autoModerationEnabled;
  final List<String> blockedWords;
  final String notice;
  final List<ChatEmojiSettings> customEmojis;

  const ChatSettings({
    required this.autoModerationEnabled,
    required this.blockedWords,
    required this.notice,
    required this.customEmojis,
  });

  factory ChatSettings.fromMap(Map<String, dynamic>? data) {
    final auto =
        (data?['autoModeration'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final emojis = ((data?['customEmojis'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => ChatEmojiSettings.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();

    return ChatSettings(
      autoModerationEnabled: auto['enabled'] == true,
      blockedWords: ((auto['blockedWords'] as List?) ?? const [])
          .map((word) => word.toString().trim())
          .where((word) => word.isNotEmpty)
          .toList(),
      notice:
          (auto['notice'] ??
                  'Attention {user}, merci de respecter les regles du chat et de garder un ton correct.')
              .toString(),
      customEmojis: emojis,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoModeration': {
        'enabled': autoModerationEnabled,
        'blockedWords': blockedWords,
        'notice': notice,
      },
      'customEmojis': customEmojis.map((emoji) => emoji.toMap()).toList(),
    };
  }
}

class AppSettingsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> appConfigDoc(String docId) {
    return _db.collection('app_config').doc(docId);
  }

  static DocumentReference<Map<String, dynamic>> configDoc(String docId) {
    return _db.collection('config').doc(docId);
  }

  static Stream<Map<String, dynamic>> appConfigStream(String docId) {
    return appConfigDoc(
      docId,
    ).snapshots(includeMetadataChanges: true).map((snap) => snap.data() ?? {});
  }

  static Stream<Map<String, dynamic>> configStream(String docId) {
    return configDoc(
      docId,
    ).snapshots(includeMetadataChanges: true).map((snap) => snap.data() ?? {});
  }

  static Stream<SupportSettings> supportStream() {
    return appConfigStream('support').map(SupportSettings.fromMap);
  }

  static Future<void> saveSupport(SupportSettings settings) async {
    await appConfigDoc('support').set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<RoleBadgeSettings> roleBadgesStream() {
    return configStream('role_badges').map(RoleBadgeSettings.fromMap);
  }

  static Future<void> saveRoleBadges(Map<String, String> badges) async {
    await configDoc('role_badges').set({
      ...RoleBadgeSettings(badges: badges).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<ChatSettings> chatStream() {
    return appConfigStream('chat').map(ChatSettings.fromMap);
  }

  static Future<void> saveChat(ChatSettings settings) async {
    await appConfigDoc('chat').set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<PoweredByPartnerSettings> poweredByPartnerStream() {
    return appConfigStream('powered_by_partner')
        .map(PoweredByPartnerSettings.fromMap);
  }

  static Future<void> savePoweredByPartner(PoweredByPartnerSettings settings) async {
    await appConfigDoc('powered_by_partner').set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<ShareCardSettings> shareCardStream() {
    return appConfigStream('share_card').map(ShareCardSettings.fromMap);
  }

  static Future<void> saveShareCard(ShareCardSettings settings) async {
    await appConfigDoc('share_card').set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<ShareCardSettings> getShareCardOnce() async {
    final snap = await appConfigDoc('share_card').get();
    return ShareCardSettings.fromMap(snap.data());
  }

  /// Textes des boîtes de partage (actu / vidéo par catégorie, matchs, prono…).
  static Stream<ShareTemplateSettings> shareTemplatesStream() {
    return appConfigStream('share_text_templates')
        .map(ShareTemplateSettings.fromMap);
  }

  static Future<void> saveShareTemplates(ShareTemplateSettings settings) async {
    await appConfigDoc('share_text_templates').set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<ShareTemplateSettings> getShareTemplatesOnce() async {
    final snap = await appConfigDoc('share_text_templates').get();
    return ShareTemplateSettings.fromMap(snap.data());
  }

  static Stream<ProfileHeroBackgroundSettings> profileHeroBackgroundsStream() {
    return appConfigStream(ProfileHeroBackgroundSettings.firestoreDocId)
        .map(ProfileHeroBackgroundSettings.fromMap);
  }

  static Future<void> saveProfileHeroBackgrounds(
    ProfileHeroBackgroundSettings settings,
  ) async {
    await appConfigDoc(ProfileHeroBackgroundSettings.firestoreDocId).set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
