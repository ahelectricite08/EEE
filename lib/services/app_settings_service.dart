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

/// Emplacements des bannières « Soutenez DVCR » dans l’app.
enum SoutenezDvcrBannerSlot { home, profile, live, articles }

/// Contenu d’une bannière par emplacement — `app_config/soutenez_dvcr_banners`.
class SoutenezDvcrBannerSlotConfig {
  final bool enabled;
  final String imageUrl;
  final String badgeLabel;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String ctaUrl;
  final String sponsorName;

  const SoutenezDvcrBannerSlotConfig({
    this.enabled = true,
    this.imageUrl = '',
    this.badgeLabel = '',
    this.title = '',
    this.subtitle = '',
    this.ctaLabel = '',
    this.ctaUrl = '',
    this.sponsorName = '',
  });

  static const String defaultPhotoAsset =
      'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg';

  static const SoutenezDvcrBannerSlotConfig homeDefaults =
      SoutenezDvcrBannerSlotConfig(
    enabled: true,
    badgeLabel: 'DVCR',
    title: 'SOUTENEZ DVCR',
    subtitle: 'Chaque don nous aide à grandir',
  );

  static const SoutenezDvcrBannerSlotConfig profileDefaults =
      SoutenezDvcrBannerSlotConfig(
    enabled: true,
    badgeLabel: 'DVCR',
    title: 'Association',
  );

  static const SoutenezDvcrBannerSlotConfig liveDefaults =
      SoutenezDvcrBannerSlotConfig(
    enabled: true,
    badgeLabel: 'DVCR',
    title: 'Association',
  );

  static const SoutenezDvcrBannerSlotConfig articlesDefaults =
      SoutenezDvcrBannerSlotConfig(
    enabled: true,
    badgeLabel: 'DVCR',
    title: 'Association',
  );

  static SoutenezDvcrBannerSlotConfig defaultsFor(SoutenezDvcrBannerSlot slot) {
    switch (slot) {
      case SoutenezDvcrBannerSlot.home:
        return homeDefaults;
      case SoutenezDvcrBannerSlot.profile:
        return profileDefaults;
      case SoutenezDvcrBannerSlot.live:
        return liveDefaults;
      case SoutenezDvcrBannerSlot.articles:
        return articlesDefaults;
    }
  }

  /// Fusionne Firestore + défauts d’emplacement (champs vides → défaut).
  SoutenezDvcrBannerSlotConfig resolvedFor(SoutenezDvcrBannerSlot slot) {
    final d = defaultsFor(slot);
    return SoutenezDvcrBannerSlotConfig(
      enabled: enabled,
      imageUrl: imageUrl.trim(),
      badgeLabel: badgeLabel.trim().isNotEmpty ? badgeLabel.trim() : d.badgeLabel,
      title: title.trim().isNotEmpty ? title.trim() : d.title,
      subtitle: subtitle.trim().isNotEmpty ? subtitle.trim() : d.subtitle,
      ctaLabel: ctaLabel.trim(),
      ctaUrl: ctaUrl.trim(),
      sponsorName: sponsorName.trim(),
    );
  }

  factory SoutenezDvcrBannerSlotConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const SoutenezDvcrBannerSlotConfig();
    return SoutenezDvcrBannerSlotConfig(
      enabled: data['enabled'] != false,
      imageUrl: (data['imageUrl'] ??
              data['bannerUrl'] ??
              data['photoUrl'] ??
              '')
          .toString()
          .trim(),
      badgeLabel: (data['badgeLabel'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
      subtitle: (data['subtitle'] ?? '').toString().trim(),
      ctaLabel: (data['ctaLabel'] ?? '').toString().trim(),
      ctaUrl: (data['ctaUrl'] ?? '').toString().trim(),
      sponsorName: (data['sponsorName'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'imageUrl': imageUrl.trim(),
        'badgeLabel': badgeLabel.trim(),
        'title': title.trim(),
        'subtitle': subtitle.trim(),
        'ctaLabel': ctaLabel.trim(),
        'ctaUrl': ctaUrl.trim(),
        'sponsorName': sponsorName.trim(),
      };

  SoutenezDvcrBannerSlotConfig copyWith({
    bool? enabled,
    String? imageUrl,
    String? badgeLabel,
    String? title,
    String? subtitle,
    String? ctaLabel,
    String? ctaUrl,
    String? sponsorName,
  }) {
    return SoutenezDvcrBannerSlotConfig(
      enabled: enabled ?? this.enabled,
      imageUrl: imageUrl ?? this.imageUrl,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaUrl: ctaUrl ?? this.ctaUrl,
      sponsorName: sponsorName ?? this.sponsorName,
    );
  }
}

/// Bannières « Soutenez DVCR » / sponsors — `app_config/soutenez_dvcr_banners`.
/// Distinct de [PronoBannersSettings] (hero Pronos).
class SoutenezDvcrBannersSettings {
  static const String firestoreDocId = 'soutenez_dvcr_banners';

  final SoutenezDvcrBannerSlotConfig home;
  final SoutenezDvcrBannerSlotConfig profile;
  final SoutenezDvcrBannerSlotConfig live;
  final SoutenezDvcrBannerSlotConfig articles;
  final int revisionMillis;

  const SoutenezDvcrBannersSettings({
    this.home = SoutenezDvcrBannerSlotConfig.homeDefaults,
    this.profile = SoutenezDvcrBannerSlotConfig.profileDefaults,
    this.live = SoutenezDvcrBannerSlotConfig.liveDefaults,
    this.articles = SoutenezDvcrBannerSlotConfig.articlesDefaults,
    this.revisionMillis = 0,
  });

  static const SoutenezDvcrBannersSettings defaults =
      SoutenezDvcrBannersSettings();

  SoutenezDvcrBannerSlotConfig forSlot(SoutenezDvcrBannerSlot slot) {
    switch (slot) {
      case SoutenezDvcrBannerSlot.home:
        return home;
      case SoutenezDvcrBannerSlot.profile:
        return profile;
      case SoutenezDvcrBannerSlot.live:
        return live;
      case SoutenezDvcrBannerSlot.articles:
        return articles;
    }
  }

  SoutenezDvcrBannerSlotConfig resolved(SoutenezDvcrBannerSlot slot) =>
      forSlot(slot).resolvedFor(slot);

  factory SoutenezDvcrBannersSettings.fromMap(Map<String, dynamic>? data) {
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    return SoutenezDvcrBannersSettings(
      home: SoutenezDvcrBannerSlotConfig.fromMap(asMap(data?['home'])),
      profile: SoutenezDvcrBannerSlotConfig.fromMap(asMap(data?['profile'])),
      live: SoutenezDvcrBannerSlotConfig.fromMap(asMap(data?['live'])),
      articles: SoutenezDvcrBannerSlotConfig.fromMap(asMap(data?['articles'])),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'home': home.toMap(),
        'profile': profile.toMap(),
        'live': live.toMap(),
        'articles': articles.toMap(),
      };

  SoutenezDvcrBannersSettings copyWith({
    SoutenezDvcrBannerSlotConfig? home,
    SoutenezDvcrBannerSlotConfig? profile,
    SoutenezDvcrBannerSlotConfig? live,
    SoutenezDvcrBannerSlotConfig? articles,
    int? revisionMillis,
  }) {
    return SoutenezDvcrBannersSettings(
      home: home ?? this.home,
      profile: profile ?? this.profile,
      live: live ?? this.live,
      articles: articles ?? this.articles,
      revisionMillis: revisionMillis ?? this.revisionMillis,
    );
  }
}

class RoleBadgeSettings {
  final Map<String, String> badges;
  final Map<String, String> labels;

  const RoleBadgeSettings({
    required this.badges,
    this.labels = const {},
  });

  static const _legacyTeamDvcrLabels = {
    'membre dvcr',
    'membres dvcr',
    'bénévole dvcr',
    'benevole dvcr',
    'bénévoles dvcr',
    'benevoles dvcr',
  };

  /// Anciens libellés Firestore → affichage actuel « Team DVCR ».
  static String normalizeTeamDvcrLabel(String? value, {required String fallback}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return fallback;
    if (_legacyTeamDvcrLabels.contains(v.toLowerCase())) return 'Team DVCR';
    return v;
  }

  factory RoleBadgeSettings.fromMap(Map<String, dynamic>? data) {
    final raw = data ?? const <String, dynamic>{};
    final labelsRaw = raw['labels'];
    final labels = <String, String>{};
    if (labelsRaw is Map) {
      for (final e in labelsRaw.entries) {
        var label = e.value?.toString().trim() ?? '';
        final key = e.key.toString();
        if (key == 'team_dvcr') {
          label = normalizeTeamDvcrLabel(label, fallback: 'Team DVCR');
        }
        labels[key] = label;
      }
    }
    final badges = <String, String>{};
    for (final e in raw.entries) {
      if (e.key == 'labels' || e.key == 'updatedAt') continue;
      badges[e.key] = e.value?.toString().trim() ?? '';
    }
    return RoleBadgeSettings(badges: badges, labels: labels);
  }

  Map<String, dynamic> toMap() {
    return {
      ...badges.map((key, value) => MapEntry(key, value.trim())),
      if (labels.isNotEmpty)
        'labels': labels.map((key, value) => MapEntry(key, value.trim())),
    };
  }

  String labelForKey(String roleKey, String fallback) {
    final custom = labels[roleKey]?.trim();
    if (roleKey == 'team_dvcr') {
      return normalizeTeamDvcrLabel(custom, fallback: fallback);
    }
    if (custom != null && custom.isNotEmpty) return custom;
    return fallback;
  }
}

/// Encart « Propulsé par » configurable admin — document `app_config/powered_by_partner`.
/// Utilisé pour le partenaire **prono championnat** (réglages admin) ; le **profil** reste
/// sur l’asset fixe [PoweredByPartnerSettings.fallbackAssetPath] + valeurs par défaut.
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

  final String imageUrl;
  final String tagline;
  final String badgeLabel;
  final String sectionLabel;
  final String poweredByTitle;
  /// Sous le sous-titre partenaire sur l’onglet prono (ex. lot classement).
  final String pronoPrizeHint;

  /// Affiche ou masque l'encart « propulsé par » sur l'onglet Pronos.
  /// Défaut : visible. Piloté par le switch admin (sans rebuild une fois la
  /// version qui lit ce flag déployée).
  final bool pronoPartnerEncartEnabled;

  /// Dérivé de `updatedAt` Firestore — invalide le cache image côté app.
  final int revisionMillis;

  const PoweredByPartnerSettings({
    required this.imageUrl,
    required this.tagline,
    this.badgeLabel = defaultBadgeLabel,
    this.sectionLabel = defaultSectionLabel,
    this.poweredByTitle = defaultPoweredByTitle,
    this.pronoPrizeHint = '',
    this.pronoPartnerEncartEnabled = true,
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
      pronoPartnerEncartEnabled: data?['pronoPartnerEncartEnabled'] != false,
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
        'pronoPartnerEncartEnabled': pronoPartnerEncartEnabled,
      };
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

/// Bannières hero des onglets Pronos — `app_config/prono_banners`.
/// URL vide = photo locale par défaut dans l’app.
///
/// Les trois derniers emplacements ne sont pas des hero de page mais des
/// **fonds de dalle** (ligues, classement, feuille de prono) : URL vide =
/// matière d’encre du design system, jamais un rectangle cassé.
class PronoBannersSettings {
  static const String firestoreDocId = 'prono_banners';

  final String homeHeroUrl;
  final String matchesHeroUrl;
  final String progressHeroUrl;
  final String socialHeroUrl;
  final String leaguesSlabUrl;
  final String standingSlabUrl;
  final String predictSlabUrl;
  final String xiSlabUrl;
  final int revisionMillis;

  const PronoBannersSettings({
    required this.homeHeroUrl,
    required this.matchesHeroUrl,
    required this.progressHeroUrl,
    required this.socialHeroUrl,
    this.leaguesSlabUrl = '',
    this.standingSlabUrl = '',
    this.predictSlabUrl = '',
    this.xiSlabUrl = '',
    this.revisionMillis = 0,
  });

  static const PronoBannersSettings defaults = PronoBannersSettings(
    homeHeroUrl: '',
    matchesHeroUrl: '',
    progressHeroUrl: '',
    socialHeroUrl: '',
  );

  String urlForSlot(PronoBannerSlot slot) {
    switch (slot) {
      case PronoBannerSlot.home:
        return homeHeroUrl;
      case PronoBannerSlot.matches:
        return matchesHeroUrl;
      case PronoBannerSlot.progress:
        return progressHeroUrl;
      case PronoBannerSlot.social:
        return socialHeroUrl;
      case PronoBannerSlot.leaguesSlab:
        return leaguesSlabUrl;
      case PronoBannerSlot.standingSlab:
        return standingSlabUrl;
      case PronoBannerSlot.predictSlab:
        return predictSlabUrl;
      case PronoBannerSlot.xiSlab:
        return xiSlabUrl;
    }
  }

  factory PronoBannersSettings.fromMap(Map<String, dynamic>? data) {
    return PronoBannersSettings(
      homeHeroUrl: (data?['homeHeroUrl'] ?? '').toString().trim(),
      matchesHeroUrl: (data?['matchesHeroUrl'] ?? '').toString().trim(),
      progressHeroUrl: (data?['progressHeroUrl'] ?? '').toString().trim(),
      socialHeroUrl: (data?['socialHeroUrl'] ?? '').toString().trim(),
      leaguesSlabUrl: (data?['leaguesSlabUrl'] ?? '').toString().trim(),
      standingSlabUrl: (data?['standingSlabUrl'] ?? '').toString().trim(),
      predictSlabUrl: (data?['predictSlabUrl'] ?? '').toString().trim(),
      xiSlabUrl: (data?['xiSlabUrl'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'homeHeroUrl': homeHeroUrl.trim(),
        'matchesHeroUrl': matchesHeroUrl.trim(),
        'progressHeroUrl': progressHeroUrl.trim(),
        'socialHeroUrl': socialHeroUrl.trim(),
        'leaguesSlabUrl': leaguesSlabUrl.trim(),
        'standingSlabUrl': standingSlabUrl.trim(),
        'predictSlabUrl': predictSlabUrl.trim(),
        'xiSlabUrl': xiSlabUrl.trim(),
      };

  // Égalité par valeur : le flux Firestore écoute `includeMetadataChanges`, donc
  // il ré-émet à chaque bascule cache/serveur. Sans `==`, le `distinct()` du
  // service laisserait passer ces doublons et les dalles photo se
  // reconstruiraient à chaque scroll.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PronoBannersSettings &&
        other.homeHeroUrl == homeHeroUrl &&
        other.matchesHeroUrl == matchesHeroUrl &&
        other.progressHeroUrl == progressHeroUrl &&
        other.socialHeroUrl == socialHeroUrl &&
        other.leaguesSlabUrl == leaguesSlabUrl &&
        other.standingSlabUrl == standingSlabUrl &&
        other.predictSlabUrl == predictSlabUrl &&
        other.xiSlabUrl == xiSlabUrl &&
        other.revisionMillis == revisionMillis;
  }

  @override
  int get hashCode => Object.hash(
        homeHeroUrl,
        matchesHeroUrl,
        progressHeroUrl,
        socialHeroUrl,
        leaguesSlabUrl,
        standingSlabUrl,
        predictSlabUrl,
        xiSlabUrl,
        revisionMillis,
      );
}

enum PronoBannerSlot {
  home,
  matches,
  progress,
  social,
  leaguesSlab,
  standingSlab,
  predictSlab,
  xiSlab,
}

/// Photos hero des onglets principaux — `app_config/hub_heroes`.
/// URL vide = image actuelle (asset ou Wix hardcodée) dans l’app.
enum HubHeroSlot {
  home,
  tv,
  calendar,
  articles,
  community,
  auth,
  guest,
  matchDetail,
  emission,
  profile,
  reseaux,
}

class HubHeroBannersSettings {
  static const String firestoreDocId = 'hub_heroes';

  final String homeHeroUrl;
  final String tvHeroUrl;
  final String calendarHeroUrl;
  final String articlesHeroUrl;
  final String communityHeroUrl;
  final String authHeroUrl;
  final String guestHeroUrl;
  final String matchDetailHeroUrl;
  final String emissionHeroUrl;
  final String profileHeroUrl;
  final String reseauxHeroUrl;
  final int revisionMillis;

  const HubHeroBannersSettings({
    required this.homeHeroUrl,
    required this.tvHeroUrl,
    required this.calendarHeroUrl,
    required this.articlesHeroUrl,
    required this.communityHeroUrl,
    required this.authHeroUrl,
    required this.guestHeroUrl,
    required this.matchDetailHeroUrl,
    required this.emissionHeroUrl,
    this.profileHeroUrl = '',
    this.reseauxHeroUrl = '',
    this.revisionMillis = 0,
  });

  static const HubHeroBannersSettings defaults = HubHeroBannersSettings(
    homeHeroUrl: '',
    tvHeroUrl: '',
    calendarHeroUrl: '',
    articlesHeroUrl: '',
    communityHeroUrl: '',
    authHeroUrl: '',
    guestHeroUrl: '',
    matchDetailHeroUrl: '',
    emissionHeroUrl: '',
    profileHeroUrl: '',
    reseauxHeroUrl: '',
  );

  String urlForSlot(HubHeroSlot slot) {
    switch (slot) {
      case HubHeroSlot.home:
        return homeHeroUrl;
      case HubHeroSlot.tv:
        return tvHeroUrl;
      case HubHeroSlot.calendar:
        return calendarHeroUrl;
      case HubHeroSlot.articles:
        return articlesHeroUrl;
      case HubHeroSlot.community:
        return communityHeroUrl;
      case HubHeroSlot.auth:
        return authHeroUrl;
      case HubHeroSlot.guest:
        return guestHeroUrl;
      case HubHeroSlot.matchDetail:
        return matchDetailHeroUrl;
      case HubHeroSlot.emission:
        return emissionHeroUrl;
      case HubHeroSlot.profile:
        return profileHeroUrl;
      case HubHeroSlot.reseaux:
        return reseauxHeroUrl;
    }
  }

  factory HubHeroBannersSettings.fromMap(Map<String, dynamic>? data) {
    return HubHeroBannersSettings(
      homeHeroUrl: (data?['homeHeroUrl'] ?? '').toString().trim(),
      tvHeroUrl: (data?['tvHeroUrl'] ?? '').toString().trim(),
      calendarHeroUrl: (data?['calendarHeroUrl'] ?? '').toString().trim(),
      articlesHeroUrl: (data?['articlesHeroUrl'] ?? '').toString().trim(),
      communityHeroUrl: (data?['communityHeroUrl'] ?? '').toString().trim(),
      authHeroUrl: (data?['authHeroUrl'] ?? '').toString().trim(),
      guestHeroUrl: (data?['guestHeroUrl'] ?? '').toString().trim(),
      matchDetailHeroUrl: (data?['matchDetailHeroUrl'] ?? '').toString().trim(),
      emissionHeroUrl: (data?['emissionHeroUrl'] ?? '').toString().trim(),
      profileHeroUrl: (data?['profileHeroUrl'] ?? '').toString().trim(),
      reseauxHeroUrl: (data?['reseauxHeroUrl'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'homeHeroUrl': homeHeroUrl.trim(),
        'tvHeroUrl': tvHeroUrl.trim(),
        'calendarHeroUrl': calendarHeroUrl.trim(),
        'articlesHeroUrl': articlesHeroUrl.trim(),
        'communityHeroUrl': communityHeroUrl.trim(),
        'authHeroUrl': authHeroUrl.trim(),
        'guestHeroUrl': guestHeroUrl.trim(),
        'matchDetailHeroUrl': matchDetailHeroUrl.trim(),
        'emissionHeroUrl': emissionHeroUrl.trim(),
        'profileHeroUrl': profileHeroUrl.trim(),
        'reseauxHeroUrl': reseauxHeroUrl.trim(),
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

  static Future<void> saveRoleBadges(
    Map<String, String> badges, {
    Map<String, String>? labels,
  }) async {
    final normalizedLabels = <String, String>{};
    for (final e in (labels ?? const {}).entries) {
      var v = e.value.trim();
      if (e.key == 'team_dvcr') {
        v = RoleBadgeSettings.normalizeTeamDvcrLabel(
          v,
          fallback: 'Team DVCR',
        );
      }
      normalizedLabels[e.key] = v;
    }
    await configDoc('role_badges').set({
      ...RoleBadgeSettings(badges: badges, labels: normalizedLabels).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Corrige l’ancien libellé « Membre DVCR » stocké dans Firestore (admin).
  static Future<void> migrateLegacyTeamDvcrBadgeLabel() async {
    try {
      final doc = configDoc('role_badges');
      final snap = await doc.get();
      final data = snap.data();
      if (data == null) return;
      final raw = data['labels'];
      if (raw is! Map) return;
      final current = raw['team_dvcr']?.toString().trim() ?? '';
      final normalized = RoleBadgeSettings.normalizeTeamDvcrLabel(
        current,
        fallback: 'Team DVCR',
      );
      if (normalized == current) return;
      await doc.set({
        'labels': {
          ...Map<String, dynamic>.from(raw),
          'team_dvcr': normalized,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
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

  /// Mode maintenance admin — coupe les push FCM côté Cloud Functions.
  static Stream<Map<String, dynamic>> adminMaintenanceStream() {
    return appConfigStream('admin_maintenance');
  }

  static Stream<bool> notificationsPausedStream() {
    return adminMaintenanceStream().map(
      (data) => data['notificationsPaused'] == true,
    );
  }

  static Stream<String?> maintenanceBypassUidStream() {
    return adminMaintenanceStream().map((data) {
      final raw = data['maintenanceBypassUid'];
      if (raw == null) return null;
      final s = raw.toString().trim();
      return s.isEmpty ? null : s;
    });
  }

  static Future<bool> notificationsPausedOnce() async {
    final snap = await appConfigDoc('admin_maintenance').get();
    return snap.data()?['notificationsPaused'] == true;
  }

  static Future<void> setNotificationsPaused(bool paused) async {
    await appConfigDoc('admin_maintenance').set({
      'notificationsPaused': paused,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// UID dont les appareils reçoivent encore les push en mode maintenance.
  static Future<void> setMaintenanceBypassUid(String? uid) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final trimmed = uid?.trim() ?? '';
    if (trimmed.isEmpty) {
      data['maintenanceBypassUid'] = FieldValue.delete();
    } else {
      data['maintenanceBypassUid'] = trimmed;
    }
    await appConfigDoc('admin_maintenance').set(data, SetOptions(merge: true));
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

  /// Dernier réglage bannières connu de la session — sert d'`initialData` aux
  /// dalles photo pour qu'elles n'affichent jamais un repli d'encre le temps
  /// d'une frame avant de basculer sur la photo.
  static PronoBannersSettings _lastPronoBanners = PronoBannersSettings.defaults;

  static PronoBannersSettings get lastKnownPronoBanners => _lastPronoBanners;

  static Stream<PronoBannersSettings> pronoBannersStream() {
    return appConfigStream(PronoBannersSettings.firestoreDocId)
        .map(PronoBannersSettings.fromMap)
        .map((s) {
          _lastPronoBanners = s;
          return s;
        })
        .distinct();
  }

  static Future<void> savePronoBanners(PronoBannersSettings settings) async {
    await appConfigDoc(PronoBannersSettings.firestoreDocId).set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<HubHeroBannersSettings> hubHeroBannersStream() {
    try {
      return appConfigStream(HubHeroBannersSettings.firestoreDocId)
          .map(HubHeroBannersSettings.fromMap)
          .handleError((_, __) {});
    } catch (_) {
      return Stream.value(HubHeroBannersSettings.defaults);
    }
  }

  static Future<void> saveHubHeroBanners(HubHeroBannersSettings settings) async {
    await appConfigDoc(HubHeroBannersSettings.firestoreDocId).set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<SoutenezDvcrBannersSettings> soutenezDvcrBannersStream() {
    return appConfigStream(SoutenezDvcrBannersSettings.firestoreDocId)
        .map(SoutenezDvcrBannersSettings.fromMap);
  }

  static Future<void> saveSoutenezDvcrBanners(
    SoutenezDvcrBannersSettings settings,
  ) async {
    await appConfigDoc(SoutenezDvcrBannersSettings.firestoreDocId).set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
