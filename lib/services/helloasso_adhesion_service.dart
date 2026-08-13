import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Config HelloAsso / adhésion — `app_config/helloasso_adhesion`.
///
/// Champs document Firestore :
/// - `adherentExpiresAt` (Timestamp) — fin de statut adhérent
/// - `bannerEnabled` (bool) — afficher le bandeau accueil
/// - `splashEnabled` (bool) — écran plein écran à l’ouverture (indépendant)
/// - `helloAssoUrl` (string) — formulaire HelloAsso
/// - `title`, `subtitle`, `ctaLabel` (strings) — textes bandeau
/// - `splashTitle`, `splashSubtitle`, `splashCtaLabel` — textes écran ouverture
/// - `splashImageUrl` (string) — photo plein écran
/// - `memberCount` (int) — compteur manuel
/// - `memberCountLabel` (string) — libellé sous le compteur
/// - `useCustomBackground` (bool), `backgroundUrl` (string, Storage)
/// - `trackingEnabled` (bool), `utmSource`, `utmMedium`, `utmCampaign`
/// - `updatedAt` (server timestamp)
class HelloAssoAdhesionConfig {
  final DateTime adherentExpiresAt;
  final bool bannerEnabled;
  final bool splashEnabled;
  final String helloAssoUrl;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String splashTitle;
  final String splashSubtitle;
  final String splashCtaLabel;
  final String splashImageUrl;
  final int memberCount;
  final String memberCountLabel;
  final bool useCustomBackground;
  final String backgroundUrl;
  final bool trackingEnabled;
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;

  const HelloAssoAdhesionConfig({
    required this.adherentExpiresAt,
    this.bannerEnabled = false,
    this.splashEnabled = false,
    this.helloAssoUrl = '',
    this.title = 'Rejoins la famille DVCR',
    this.subtitle = 'Adhère au club et soutiens le projet',
    this.ctaLabel = 'Adhérer',
    this.splashTitle = 'Rejoins dès maintenant l’association',
    this.splashSubtitle = 'Soutiens DVCR et le projet CSSA',
    this.splashCtaLabel = 'Adhérer',
    this.splashImageUrl = '',
    this.memberCount = 0,
    this.memberCountLabel = 'personnes ont rejoint',
    this.useCustomBackground = false,
    this.backgroundUrl = '',
    this.trackingEnabled = true,
    this.utmSource = 'dvcr_app',
    this.utmMedium = 'banner',
    this.utmCampaign = 'adhesion_home',
  });

  static const String defaultBackgroundAsset =
      'assets/images/adhesion_banner_bg.png';

  static final DateTime defaultExpiresAt =
      DateTime.utc(2027, 6, 1, 21, 59, 59);

  static final HelloAssoAdhesionConfig defaults = HelloAssoAdhesionConfig(
    adherentExpiresAt: defaultExpiresAt,
  );

  bool get canOpenHelloAsso => helloAssoUrl.trim().isNotEmpty;

  /// Splash affichable côté app (switch + lien).
  bool get shouldShowSplash => splashEnabled && canOpenHelloAsso;

  factory HelloAssoAdhesionConfig.fromMap(Map<String, dynamic>? data) {
    final raw = data?['adherentExpiresAt'] ?? data?['expiresAt'];
    DateTime expires = defaultExpiresAt;
    if (raw is Timestamp) {
      expires = raw.toDate();
    } else if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) expires = parsed;
    }

    final countRaw = data?['memberCount'];
    var memberCount = 0;
    if (countRaw is int) {
      memberCount = countRaw;
    } else if (countRaw is num) {
      memberCount = countRaw.round();
    } else if (countRaw is String) {
      memberCount = int.tryParse(countRaw.trim()) ?? 0;
    }
    if (memberCount < 0) memberCount = 0;

    return HelloAssoAdhesionConfig(
      adherentExpiresAt: expires,
      bannerEnabled: data?['bannerEnabled'] == true,
      splashEnabled: data?['splashEnabled'] == true,
      helloAssoUrl: (data?['helloAssoUrl'] ?? '').toString(),
      title: (data?['title'] ?? defaults.title).toString(),
      subtitle: (data?['subtitle'] ?? defaults.subtitle).toString(),
      ctaLabel: (data?['ctaLabel'] ?? defaults.ctaLabel).toString(),
      splashTitle: (data?['splashTitle'] ?? defaults.splashTitle).toString(),
      splashSubtitle:
          (data?['splashSubtitle'] ?? defaults.splashSubtitle).toString(),
      splashCtaLabel:
          (data?['splashCtaLabel'] ?? defaults.splashCtaLabel).toString(),
      splashImageUrl: (data?['splashImageUrl'] ?? '').toString(),
      memberCount: memberCount,
      memberCountLabel:
          (data?['memberCountLabel'] ?? defaults.memberCountLabel).toString(),
      useCustomBackground: data?['useCustomBackground'] == true,
      backgroundUrl: (data?['backgroundUrl'] ?? '').toString(),
      trackingEnabled: data?['trackingEnabled'] != false,
      utmSource: (data?['utmSource'] ?? defaults.utmSource).toString(),
      utmMedium: (data?['utmMedium'] ?? defaults.utmMedium).toString(),
      utmCampaign: (data?['utmCampaign'] ?? defaults.utmCampaign).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adherentExpiresAt': Timestamp.fromDate(adherentExpiresAt),
      'bannerEnabled': bannerEnabled,
      'splashEnabled': splashEnabled,
      'helloAssoUrl': helloAssoUrl.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'ctaLabel': ctaLabel.trim(),
      'splashTitle': splashTitle.trim(),
      'splashSubtitle': splashSubtitle.trim(),
      'splashCtaLabel': splashCtaLabel.trim(),
      'splashImageUrl': splashImageUrl.trim(),
      'memberCount': memberCount < 0 ? 0 : memberCount,
      'memberCountLabel': memberCountLabel.trim(),
      'useCustomBackground': useCustomBackground,
      'backgroundUrl': backgroundUrl.trim(),
      'trackingEnabled': trackingEnabled,
      'utmSource': utmSource.trim(),
      'utmMedium': utmMedium.trim(),
      'utmCampaign': utmCampaign.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  HelloAssoAdhesionConfig copyWith({
    DateTime? adherentExpiresAt,
    bool? bannerEnabled,
    bool? splashEnabled,
    String? helloAssoUrl,
    String? title,
    String? subtitle,
    String? ctaLabel,
    String? splashTitle,
    String? splashSubtitle,
    String? splashCtaLabel,
    String? splashImageUrl,
    int? memberCount,
    String? memberCountLabel,
    bool? useCustomBackground,
    String? backgroundUrl,
    bool? trackingEnabled,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
  }) {
    return HelloAssoAdhesionConfig(
      adherentExpiresAt: adherentExpiresAt ?? this.adherentExpiresAt,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      splashEnabled: splashEnabled ?? this.splashEnabled,
      helloAssoUrl: helloAssoUrl ?? this.helloAssoUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      splashTitle: splashTitle ?? this.splashTitle,
      splashSubtitle: splashSubtitle ?? this.splashSubtitle,
      splashCtaLabel: splashCtaLabel ?? this.splashCtaLabel,
      splashImageUrl: splashImageUrl ?? this.splashImageUrl,
      memberCount: memberCount ?? this.memberCount,
      memberCountLabel: memberCountLabel ?? this.memberCountLabel,
      useCustomBackground: useCustomBackground ?? this.useCustomBackground,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      utmSource: utmSource ?? this.utmSource,
      utmMedium: utmMedium ?? this.utmMedium,
      utmCampaign: utmCampaign ?? this.utmCampaign,
    );
  }

  /// URL HelloAsso avec paramètres UTM (phase 1 — pas de metadata checkout côté app).
  String buildTrackedUrl({String? mediumOverride}) {
    var url = helloAssoUrl.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    if (!trackingEnabled) return uri.toString();

    final params = Map<String, String>.from(uri.queryParameters);
    if (utmSource.trim().isNotEmpty) {
      params['utm_source'] = utmSource.trim();
    }
    final medium = (mediumOverride ?? utmMedium).trim();
    if (medium.isNotEmpty) {
      params['utm_medium'] = medium;
    }
    if (utmCampaign.trim().isNotEmpty) {
      params['utm_campaign'] = utmCampaign.trim();
    }
    return uri.replace(queryParameters: params).toString();
  }
}

/// Flag mémoire process : « Plus tard » jusqu’au prochain cold start.
class AdhesionSplashSession {
  AdhesionSplashSession._();
  static final instance = AdhesionSplashSession._();

  bool dismissedThisSession = false;

  void dismiss() => dismissedThisSession = true;

  bool get shouldOffer => !dismissedThisSession;
}

class HelloAssoAdhesionService {
  HelloAssoAdhesionService._();
  static final HelloAssoAdhesionService instance = HelloAssoAdhesionService._();

  static const _configPath = 'app_config/helloasso_adhesion';

  /// URL publique du webhook (sans secret) — europe-west1.
  static String webhookUrlForProject(String projectId) =>
      'https://europe-west1-$projectId.cloudfunctions.net/helloAssoWebhook';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      FirebaseFirestore.instance.doc(_configPath);

  Stream<HelloAssoAdhesionConfig> configStream() {
    return _configRef.snapshots().map(
          (s) => HelloAssoAdhesionConfig.fromMap(s.data()),
        );
  }

  Future<HelloAssoAdhesionConfig> loadConfig() async {
    final snap = await _configRef.get();
    return HelloAssoAdhesionConfig.fromMap(snap.data());
  }

  Future<void> saveConfig(HelloAssoAdhesionConfig config) async {
    await _configRef.set(config.toMap(), SetOptions(merge: true));
  }

  /// Enregistre la date de fin et la propage aux adhérents actuellement actifs.
  Future<void> saveConfigAndRefreshActiveAdherents(
    HelloAssoAdhesionConfig config,
  ) async {
    await saveConfig(config);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('helloAsso.isAdherentActive', isEqualTo: true)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;

    final ts = Timestamp.fromDate(config.adherentExpiresAt);
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = snap.docs.skip(i).take(400);
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'helloAsso.adherentExpiresAt': ts,
          'helloAsso.lastSyncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Log un clic bandeau / splash avant ouverture externe HelloAsso.
  Future<void> logBannerClick({String slot = 'home'}) async {
    try {
      await FirebaseFirestore.instance.collection('adhesion_clicks').add({
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'platform': defaultTargetPlatform.name,
        'slot': slot,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> clicksStream({int limit = 500}) {
    return FirebaseFirestore.instance
        .collection('adhesion_clicks')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> donationsStream({int limit = 300}) {
    return FirebaseFirestore.instance
        .collection('donations')
        .where('source', isEqualTo: 'helloasso')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingMatchesStream() {
    return FirebaseFirestore.instance
        .collection('helloasso_pending_matches')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static bool isAdherentActive(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is! Map) return false;
    final now = DateTime.now();
    if (ha['isAdherentActive'] == true) {
      final exp = ha['adherentExpiresAt'];
      if (exp is Timestamp && exp.toDate().isBefore(now)) return false;
      return true;
    }
    return false;
  }

  static double adherentTotalPaid(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is Map) {
      final v = ha['adherentTotalPaid'] ?? ha['totalPaid'];
      if (v is num) return v.toDouble();
    }
    final legacy = userData?['totalDonations'];
    if (legacy is num) return legacy.toDouble();
    return 0;
  }

  /// Paiements attribués à l'app (metadata.source == dvcr_app ou champ sourceApp).
  static bool isAppAttributedPayment(Map<String, dynamic> data) {
    final meta = data['metadata'];
    if (meta is Map) {
      final src = (meta['source'] ?? '').toString().trim().toLowerCase();
      if (src == 'dvcr_app') return true;
    }
    return (data['sourceApp'] ?? '').toString().trim().toLowerCase() == 'dvcr_app';
  }
}
